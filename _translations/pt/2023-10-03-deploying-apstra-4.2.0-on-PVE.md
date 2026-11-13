---
title: Implantando o Apstra 4.2.0 no Proxmox VE
description: "Implantação passo a passo dos appliances Apstra 4.2.0 AOS e ZTP"
date: 2023-10-03 00:00:00 -0300
permalink: /pt/homelab/sdn/2023/10/03/deploying-apstra-4.2.0-on-PVE.html
lang: pt
categories:
  - virtualization
  - networking
tags:
  - proxmox
  - apstra
---

## Appliances do Apstra {#apstra-appliances}

A Juniper não distribui appliances propriamente ditos para implantações em KVM, e sim imagens de disco do sistema operacional em formato QCOW2:

**aos_server_4.2.0-236.qcow2**

Appliance principal do servidor Apstra, também usado para os workers opcionais da configuração scale-out: você usa a mesma imagem para os nós worker (não encontrei isso mencionado na documentação, mas foi dito por um cara da Juniper).

**apstra-ztp-4.2.0-34.qcow2**

Appliance opcional de Zero Touch Provisioning (ZTP) rodando PXE+TFTP. Pode ser usado como TFTP puro com um servidor DHCP já existente.

## Instalação {#installation}

### Visão geral {#overview}

Para o dimensionamento das VMs, o fabricante tem uma [tabela de dimensionamento recomendado](https://www.juniper.net/documentation/us/en/software/apstra4.2/apstra-install-upgrade/topics/ref/apstra-server-resources.html):

|Resource | Value|
|vCPU|8|
|RAM|64GB + 500MB per installed offbox agent|
|Disk|160GB|

Na minha experiência, não são necessários tantos recursos, principalmente de RAM. Para o meu ambiente de testes, vou cortar a RAM para 32GB e muito provavelmente isso não é suportado, eu vivo com isso, o seu caso pode variar.

Vamos criar as máquinas virtuais vazias no Proxmox VE 7.4-15, importando depois os discos QCOW2 conforme necessário. O procedimento pressupõe que você baixou todos os arquivos para um diretório de trabalho (curl/wget são seus amigos) em um nó PVE.


### Apstra OS {#apstra-os}

#### Criação da VM {#vm-creation}

Vamos criar uma máquina virtual pela CLI, com 4 vCPUs e 32GB de RAM. 

A rede é atendida pelo bridge padrão e o armazenamento pelo repositório ZFS local. As opções são autoexplicativas, ajuste conforme necessário.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(pvesh get /cluster/nextid)
STORAGE=local-zfs
VCPU=4
VRAM=32768
VLANLAB=<my vlan>
BRIDGE=vmbr0

# OS doesn't support UEFI
qm create ${VMID} --name ${VMNAME} \
--bios seabios --machine q35 \
--ostype l26 --agent 1 \
--sockets 1 --cores ${VCPU} --cpu cputype=kvm64 \
--scsihw virtio-scsi-single \
--memory ${VRAM} \
--net0 model=virtio,bridge=${BRIDGE},firewall=0,tag=${VLANLAB}
{% endhighlight %}

#### Importando o disco {#importing-disk}

Agora vamos importar o arquivo QCOW2 fornecido pela Juniper.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm disk import ${VMID} aos_server_4.2.0-236.qcow2  ${STORAGE}
qm set ${VMID} -scsi0 ${STORAGE}:vm-${VMID}-disk-1
qm set ${VMID} --boot order=scsi0
{% endhighlight %}

#### Disco adicional {#additional-disk}

Segundo a documentação, o disco do sistema operacional tem apenas 80GB e opcionalmente você pode adicionar um segundo disco de 80GB. Como não é caro e não vou usar nós worker adicionais, vou adicionar o segundo disco.

{% highlight shell %}
VMNAME=apstra-os-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm set ${VMID} --scsi1 ${STORAGE}:80
# we start the VM
qm start ${VMID}
{% endhighlight %}

### Appliance ZTP {#ztp-appliance}

DHCP e TFTP não são tão exigentes, você pode usar 2 vCPUs e 4GB de RAM. 

A rede é atendida pelo bridge padrão e o armazenamento pelo repositório ZFS local. As opções são autoexplicativas, ajuste conforme necessário.

{% highlight shell %}
VMNAME=apstra-ztp-03.ipa.<my TLD>
VMID=$(pvesh get /cluster/nextid)
STORAGE=local-zfs
VCPU=2
VRAM=4096
VLANLAB=<my vlan>
BRIDGE=vmbr0

# OS doesn't support UEFI
qm create ${VMID} --name ${VMNAME} \
--bios seabios --machine q35 \
--ostype l26 --agent 1 \
--sockets 1 --cores ${VCPU} --cpu cputype=kvm64 \
--scsihw virtio-scsi-single \
--memory ${VRAM} \
--net0 model=virtio,bridge=${BRIDGE},firewall=0,tag=${VLANLAB}
{% endhighlight %}

#### Importando o disco {#importing-disk-1}

Agora vamos importar o arquivo QCOW2 fornecido pela Juniper.

{% highlight shell %}
VMNAME=apstra-ztp-03.ipa.<my TLD>
VMID=$(qm list|grep ${VMNAME}|awk '{ print $1 }')
STORAGE=local-zfs

qm disk import ${VMID} apstra-ztp-4.2.0-34.qcow2  ${STORAGE}
qm set ${VMID} -scsi0 ${STORAGE}:vm-${VMID}-disk-1
qm set ${VMID} --boot order=scsi0
qm start ${VMID}
{% endhighlight %}

## Configuração inicial {#initial-configuration}
### Configuração do AOS {#aos-setup}

1. Procure o IP do appliance nos leases do seu DHCP e conecte-se via SSH com admin/admin.
2. No primeiro login, defina uma nova senha, conforme solicitado.
3. No assistente forçado, defina também a senha da UI do Apstra como proposto. Cancele no menu principal depois de definir a senha.
4. Altere o hostname para algo que faça sentido no seu ambiente. Com o usuário admin execute:
{% highlight shell %}
sudo aos_hostname apstra-os-03.ipa.<my TLD>
{% endhighlight %}
{:start="5"}
3. Ajuste o fuso horário para corresponder ao seu ambiente.
{% highlight shell %}
sudo timedatectl set-timezone <my TZ>
{% endhighlight %}
{:start="6"}
1. Como admin, atualize o sistema operacional. Muito provavelmente a Juniper vai dizer que isso não é suportado. O único problema que tive no passado foi a 4.1.0 quebrando porque havia uma biblioteca da Juniper em todo o sistema que quebrou uma aplicação em contêiner (vai entender) e foi preciso uma atualização manual de dependências para consertar. Tem sido perfeito na 4.1.2 e agora na 4.2.0; arquivos do pam.d serão mencionados, mantenha os arquivos modificados localmente.
{% highlight shell %}
sudo apt update
sudo apt upgrade -y
{% endhighlight %}
{:start="7"}
1. Instale o agente convidado do QEMU
{% highlight shell %}
sudo apt install -y qemu-guest-agent
{% endhighlight %}
{:start="8"}
1. Reinicie após a atualização completa do sistema
sudo shutdown -r now

### Configuração do appliance ZTP {#ztp-appliance-setup}

1. Procure o IP do appliance nos leases do seu DHCP e conecte-se via SSH com admin/admin.
2. Defina o hostname

 {% highlight shell %}
sudo hostnamectl set-hostname apstra-ztp-03.ipa.<my TLD>
sudo sh -c 'echo "127.0.0.1 apstra-ztp-03.ipa.<my TLD>" >> /etc/hosts'
{% endhighlight %}
{:start="3"}
3. Ajuste o fuso horário para corresponder ao seu ambiente.
{% highlight shell %}
sudo timedatectl set-timezone <my TZ>
{% endhighlight %}
{:start="4"}
1. Limpe a estrutura de configuração bagunçada: por algum motivo, o pessoal da Juniper achou boa ideia criar um diretório onde deveria haver um arquivo, e isso quebra o processo de atualização do Ubuntu. Limpamos isso (qual é, Juniper?!)
 {% highlight shell %}
sudo rmdir /etc/udev/rules.d/70-persistent-net.rules
{% endhighlight %}
{:start="5"}
1. Atualize o sistema operacional. De novo, provavelmente a Juniper vai dizer que não é suportado.
{% highlight shell %}
sudo apt update
sudo apt upgrade -y
{% endhighlight %}
{:start="6"}
7. Na Web UI do Apstra, crie um usuário com o papel device_ztp. Vamos usá-lo no próximo passo.
8. De volta ao appliance ZTP, configure a aplicação para reportar ao servidor AOS. Por algum motivo, não funciona com FQDN, só com IP.
{% highlight shell %}
cat > /containers_data/status/app/aos.conf <<EOF
{
   "ip": "<your-aos-ip>",
   "user": "<your ztp user>",
   "password": "<the super secure password>"
}
EOF
{% endhighlight %}
{:start="8"}
1. Instale o agente convidado do QEMU
{% highlight shell %}
sudo apt install -y qemu-guest-agent
{% endhighlight %}
{:start="9"}
7. Reinicie a máquina virtual
{% highlight shell %}
sudo shutdown -r now
{% endhighlight %}

## Migração a partir da 4.1.2 {#migration-from-412}

Se você já tem um ambiente funcionando, provavelmente vai querer migrar toda a configuração para a sua nova instalação; existe um script que você deve executar no novo servidor Apstra.

Leve em conta que o script falhará se houver alterações não commitadas ou se os dispositivos não estiverem acessíveis. Garanta que o estado em execução do ambiente de origem esteja limpo (sem erros).

{% highlight shell %}
aos_import_state --ip-address apstra-os-02.ipa.<my TLD> --username admin
{% endhighlight %}

Nota: 
- A migração da configuração também substituiria a senha da web UI pela configuração do servidor original.
