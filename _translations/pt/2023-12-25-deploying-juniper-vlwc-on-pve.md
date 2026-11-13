---
title: Implantando o Juniper vLWC no PVE
description: "Passo a passo da análise e da implantação de um Juniper Virtual Lightweight Collector para a funcionalidade de \"call home\""
date: 2023-12-25 00:00:00 -0300
permalink: /pt/datacenter/networking/2023/12/25/deploying-juniper-vlwc-on-pve.html
lang: pt
categories:
  - networking
  - virtualization
tags:
  - juniper
  - junos
  - proxmox
---

## Intro {#intro}

Como acontece com qualquer infraestrutura crítica, os fornecedores de tecnologia oferecem um recurso de "call-home" para seus produtos. Há mais de uma década (pelo menos até onde eu sei), fornecedores de storage como Hitachi ou EMC oferecem uma solução que permite ao fornecedor se conectar aos sistemas que são seus para que os departamentos de suporte/assistência trabalhem neles diretamente, em vez de ficar te dizendo pelo telefone o que fazer. Outras funcionalidades esperadas incluem abrir um chamado proativo em caso de falha de hardware, extrair/enviar logs ou inventariar a base instalada.

Essa funcionalidade de call-home normalmente é entregue como um software que roda em um appliance dedicado/físico, como um software a ser instalado em uma instância de Sistema Operacional de uso geral (Windows Server, SLES/RHEL/OEL/Debian) ou, hoje em dia, um appliance virtual pré-empacotado.

Implementar uma funcionalidade assim é sempre uma boa ideia, porque permite que a equipe de suporte do fornecedor responda mais rápido quando há falhas.

<!--more-->

## A necessidade {#the-need}

A equipe de suporte da Juniper nos procurou oferecendo um appliance WLC que daria capacidades de call-home e supervisionaria nossa base instalada. Esse appliance faz parte da iniciativa Juniper Support Insights (JSI) deles.

Um desses appliances físicos está a caminho de um dos nossos sites. Enquanto isso, estou cuidando de uma implantação de laboratório que poderia se beneficiar do suporte rápido e das capacidades de inventário. Estudando melhor o assunto, a equipe da Juniper mencionou que existe uma versão virtual do appliance lançada recentemente.

A [documentação](https://www.juniper.net/documentation/us/en/software/jsi/vlwc-deploy/topics/topic-map/install-verify-vlwc.html) formal para ambientes vSphere é bem direta e você pode simplesmente segui-la se estiver trabalhando em um ambiente suportado. No meu caso, o ambiente "sidecart" de suporte do laboratório não tem VMware vSphere, e sim Proxmox VE.

Vou implantar o vLWC no Proxmox VE para supervisionar os switches QFX gerenciados pelo Apstra e os switches EX que também compõem a rede OOBM dos próprios QFX.

## Here be dragons. {#here-be-dragons}

{% include image.html url="/assets/img/2023-12-25_1570-theatrum-orbis-terrarum-map-monsters.jpg" link="https://education.nationalgeographic.org/resource/here-be-dragons/" description="Imagem 1 - Mapa de monstros do Theatrum Orbis Terrarum, 1570" width=860 height=580 %}

Como aviso, devo destacar que a configuração que estou prestes a executar e compartilhar com você não é suportada pela Juniper, e o seu Service Manager vai torcer o nariz, gritar com você ou simplesmente te ignorar (dependendo do tipo de relacionamento que você tem) se você algum dia pedir ajuda para implantar o vLWC em KVM. No nosso caso, dou as boas-vindas ao Alejandro para o suporte administrativo!.

Lembre também que "não suportado" não significa que não seja tecnicamente possível. Só significa que você está por conta própria. Espero que em algum momento o suporte a Proxmox e/ou KVM seja adicionado.

Sim, vou conseguir suporte por meio de um appliance "não suportado". Isso conta como oxímoro?

## Arquitetura de rede {#network-architecture}
### Ambiente de laboratório sidecart {#lab-sidecart-environment}
No laboratório, temos um ambiente com o conjunto habitual de fornecedores e tecnologias com os quais trabalhamos. Essa configuração inclui uma rede IP Fabric EVPN/VXLAN atendendo vários clientes. Espera-se que essa rede e as plataformas dos clientes sejam reinstaladas ou reorganizadas a qualquer momento.

Para oferecer alguns serviços essenciais estáveis, montamos um pequeno ambiente paralelo com alguns switches e servidores PVE para rodar os elementos que precisam estar disponíveis o tempo todo:

- Plataforma de acesso remoto
- Serviços de autenticação
- Ferramentas relacionadas a segurança
- Ferramentas de monitoramento
- Soluções de firmware e hardware

Com esse ambiente "sidecart", não importa o que precise ser reorganizado no ambiente principal, nunca perderemos a capacidade de administração.

Para o escopo da nossa discussão, o ambiente lógico é mais ou menos assim:

{% include image.html url="/assets/img/2023-12-25_lab-environment.svg" description="Imagem 2 - Ambiente de rede de gerenciamento relacionado" alt="Visão geral das redes do laboratório" %}

Fisicamente, o sidecart é só um par de switches Cisco Nexus em stack para fornecer serviços L2 redundantes de 1GbE/10GbE, e a rede OOBM é um par de switches Juniper EX fornecendo conectividade de 1GbE para os switches e para as placas de servidor com IPMI.

Logicamente, a configuração é bem elaborada e oferece coisas como controle de acesso e segmentação de rede por meio do OPNSense, que entrega recursos de L3 e filtragem. Precisamos que os usuários se autentiquem com usuário/senha + OTP, e então chegamos aos Jump hosts usando o Guacamole:

{% include image.html url="/assets/img/2023-12-25_lab-environment-flows.svg" description="Imagem 3 - Fluxo de acesso remoto" alt="Acesso remoto" %}

Minha expectativa natural era implantar o appliance de call-home ao lado de outros appliances de suporte, como o Apstra ou o LibreNMS.

{% include image.html url="/assets/img/2023-12-25_lab-environment-plus-vlwc.svg" description="Imagem 4 - Adicionando o vLWC ao quadro" alt="vLWC no quadro" %}

Isso é relevante para a próxima seção.

### Topologia de rede exigida {#required-network-topology}

Revisando o [guia de implantação](https://www.juniper.net/documentation/us/en/software/jsi/vlwc-deploy/topics/concept/system-requirements.html), você vê que ele exige 3 interfaces de rede:

Interface|Endereço IP suportado|Função
---|---|---
Internal|Endereço IPv4 ou IPv6|Usada para a conexão com os switches a serem monitorados. A rota padrão também fica aqui.
External|Somente endereço IPv4|Usada para se conectar à Estrela da Morte (o call-home propriamente dito)
Management|Somente endereço IPv4|Usada para acesso ao captive portal (portal web apresentado pelo appliance mostrando seu status)

Poderíamos tentar cumprir e enfiar à força os requisitos do appliance no nosso ambiente:

{% include image.html url="/assets/img/2023-12-25_lab-environment-plus-vlwc-forced-compliance.svg" description="Imagem 5 - Conformidade forçada" alt="vLWC no quadro" %}


Isso não me deixa confortável: VMs conectadas a segmentos diferentes que só deveriam interagir através do firewall não era uma opção no nosso caso.

### Análise do appliance: tentativa e erro {#appliance-analysis-trial--error}

Fiz várias execuções da implantação em KVM, no vácuo, para validar o que acontece com a configuração de rede e analisar o que é necessário para implantá-lo com uma única interface.

Vou poupar você dos detalhes, mas o resumo das descobertas é:

#### **Primeira execução:** 3 redes com DHCP (internal + external + management) {#first-run-3-networks-with-dhcp-internal--external--management}
*"int"* mantém a rota padrão  
*"ext"* tem rotas estáticas para chegar à Estrela da Morte (JNI)  
*"cap"* é usada para o captive portal (página de status do appliance)

As rotas estáticas mencionadas (caso você tenha curiosidade, esses segmentos pertencem à AWS e à DigitalOcean):

```
35.71.174.221 via <ext segment gateway> dev ext 
35.83.44.146 via <ext segment gateway> dev ext 
52.223.32.79 via <ext segment gateway> dev ext 
54.149.98.110 via <ext segment gateway> dev ext 
54.149.222.60 via <ext segment gateway> dev ext 
68.183.248.21 via <ext segment gateway> dev ext 
138.197.235.241 via <ext segment gateway> dev ext 
```
**Primeira conclusão:** talvez precisemos mexer no appliance para evitar que ele instale as rotas estáticas, a menos que a instalação das rotas estáticas falhe silenciosamente pela falta da interface EXT.

O binding dos serviços SSHD e Captive Portal não é limitado a nenhuma interface em particular. 

{% highlight shell %}
root@ggc-lnx:~# lsof -n -sTCP:LISTEN -i :443
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
docker-pr 20982 root    4u  IPv4 106963      0t0  TCP *:https (LISTEN)
docker-pr 20994 root    4u  IPv6 107636      0t0  TCP *:https (LISTEN)
root@ggc-lnx:~# lsof -n -sTCP:LISTEN -i :22 
COMMAND PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
sshd    543 root    3u  IPv4  17619      0t0  TCP *:ssh (LISTEN)
sshd    543 root    4u  IPv6  17621      0t0  TCP *:ssh (LISTEN)
{% endhighlight %}

**Segunda conclusão:** não precisamos mexer na configuração de binding dos serviços, todos escutam em todas as interfaces.

Então o comportamento de "não responder em EXT" muito provavelmente deveria vir de regras de firewall, só que não vem (não existe nenhuma regra de firewall limitando as requisições SSH de entrada a uma determinada interface), esse comportamento foi uma construção da minha imaginação e não há menção a ele na documentação. 

Meu teste de ssh foi feito a partir de um cliente na mesma sub-rede que hospeda a interface EXT. Meu palpite é que qualquer outra tentativa de conexão de clientes remotos vindos da Internet deve falhar porque o gateway padrão está instalado em INT. 

De qualquer forma, crianças, não coloquem o appliance diretamente conectado à Internet sem filtros de entrada se puderem evitar.

**Terceira conclusão:** não precisamos mexer na configuração do firewall.

**Quarta conclusão:** a captura de tela a seguir mostra como é um appliance saudável.

{% include image.html url="/assets/img/2023-12-25_status-deployment-test-3if.png" description="Imagem 6 - Status do appliance com o layout de rede suportado" alt="Status do appliance" width=782 height=754 %}

#### **Segunda execução:** configuração com 1 rede com DHCP (internal) {#second-run-1-network-setup-with-dhcp-internal}
*"int"* mantém a rota padrão, dá acesso ao captive portal (página de status do appliance)  
*"ext"* é reportada com status de falha  

**Quinta conclusão:** Mesmo que a página de status mostre um "Connection Status" com erro para "External Network", dá para ver que ainda temos "Juniper Cloud Connected" e "Cloud Provisioned". Minha interpretação é que temos um erro porque não há uma interface EXT que possa ser configurada, mas é cosmético, já que temos acesso à Internet usando INT com a rota padrão.

{% include image.html url="/assets/img/2023-12-25_status-deployment-test-1if.png" description="Imagem 6 - Status do appliance com apenas uma interface" alt="Status do appliance" width=775 height=767 %}

Também posso confirmar que, depois de verificar o appliance no nível do SO, não há rotas estáticas. Não são necessários ajustes para que uma implantação com uma única interface se conecte ao JSI.

## O appliance {#the-appliance}
### Primeiros passos administrativos. {#first-administrative-steps}

Você precisa pedir duas coisas à sua equipe de suporte da Juniper:
- Acesso ao Juniper Support Insights para solicitar o appliance
- Que as permissões corretas sejam configuradas para gerenciar/usar o appliance. Temos uma infinidade de contas de suporte e algo não foi configurado direito para a minha conta no JSI.

### Como solicitar o appliance. {#how-to-request-the-appliance}

1. Quando você tiver as permissões corretas no seu usuário, acesse o [Juniper Support Portal](https://supportportal.juniper.net/)
2. Solicite o appliance pelo portal web.
{% include image.html url="/assets/img/2023-12-25_request_appliance_00.png" description="Imagem 7 - Acessando a seção de collectors" alt="Seção de collectors" width=887 height=368 %}
  
{% include image.html url="/assets/img/2023-12-25_request_appliance_01.png" description="Imagem 8 - Clique em &quot;Request Virtual Lightweight Collector&quot;" alt="Solicitação" width=1433 height=217 %}
  
{% include image.html url="/assets/img/2023-12-25_request_appliance_02.png" description="Imagem 9 - Clique em &quot;Fill-in and submit form&quot;" alt="Solicitação" width=1494 height=775 %}

{:start="3"}
3. Em menos de uma hora, você deve receber um e-mail de *do_not_reply@juniper.net* com um link para baixar o appliance. O arquivo é apagado em 7 dias, depois dos quais você precisaria solicitar o appliance de novo.

## Implantação {#deployment}

### O que você recebe da Juniper? {#what-are-you-receiving-from-juniper}

Quando você baixa o appliance do site de suporte da Juniper, recebe um arquivo OVA com um nome parecido com vLWC-${VERSION}-$(SERIAL_NUMBER).ova. No meu caso foi a versão 2.3.26.

Um arquivo OVA é basicamente um arquivo ZIP com uma imagem de disco VMDK e um arquivo OVF com a definição da máquina virtual a ser criada, incluindo metadados e a definição do que o usuário deve informar durante o rollout (vamos pular o arquivo de manifesto para os fins desta discussão).

O VMDK aparentemente é genérico para todos os clientes; o arquivo OVF inclui o número de série específico da sua implantação e precisa ser incorporado durante a instanciação/rollout.

### Configuração inicial {#initial-setup}

Com a personalização de OVF disponível via vSphere + VMware Tools, alguns parâmetros são passados para a VM no momento da instanciação, mas isso não é suportado pelo Proxmox VE. Proxmox VE + cloud-init poderia oferecer capacidades semelhantes, mas isso atualmente não é suportado pelo appliance vLWC.

{% include image.html url="/assets/img/2023-12-25_missmatch.jpg" description="Imagem 10 - Capacidades de autoconfiguração, Proxmox VE à esquerda, Juniper vLWC à direita &quot;" alt="Descompasso" width=1200 height=630 %}

Precisaríamos modificar o disco original antes de importá-lo para a máquina virtual. Vou tentar fazer o menor número possível de modificações.

- Mudanças necessárias
1. A configuração de rede já vem pré-configurada no appliance para DHCP; como temos DHCP no ambiente sidecart, vamos deixá-la como está. Outros ambientes podem precisar de endereçamento estático, fora do escopo por enquanto.
2. Em qualquer cenário, uma mudança obrigatória para o appliance seria inserir o número de série para que ele reporte corretamente ao JSI. Isso exige duas entradas: uma em texto puro, que vamos recuperar do nome do arquivo baixado, e uma criptografada, que devemos recuperar do arquivo OVF.

- Mudanças desejáveis
1. Vamos ajustar o hostname em nome de um inventário correto. Vi os logs do appliance reportando para casa o hostname como nome do produto e versão do produto (pessoal da Juniper, hostname não serve pra isso); por enquanto não parece afetar a funcionalidade, mas vou monitorar e fazer rollback se for preciso.
2. Fuso horário. O appliance vem pré-configurado com o fuso UTC; vou ajustá-lo para o nosso. Será preciso monitorar e fazer rollback se isso afetar algo do lado do JSI.
3. QEMU Agent. Oferece alguma integração com o PVE para ajudar no gerenciamento da VM.
4. Instalar minha chave pública para o login de root, ajuda no troubleshooting (eu sei, eu não deveria usar root neste appliance, assim como não deveria implantá-lo em PVE/KVM 🙂)

***
**Atualização 1**: Fui contatado por alguém que parece fazer parte da equipe de operações do JSI, que pediu gentilmente para eu reverter a mudança de hostname porque isso quebra coisas para eles.

Como aposta de longo alcance, estou adicionando isto como pedido adicional para o PLM.  

***


Copie o arquivo OVA para o seu host PVE (scp é seu amigo) e siga o procedimento abaixo.

1. Primeiro, precisamos anotar o número de série nas duas representações de que vamos precisar.

{% highlight shell %}
# prepare the working directory
mkdir -p import/juniper
cd import/juniper
# at this point, copy the OVA file via SCP.
# verify file existance
ls -l vLWC-2.3.26-<serial>.ova
-rw-r--r-- 1 ciro.iriarte ipausers 2466766848 Dec 19 17:01 vLWC-2.3.26-<serial>.ova
# We extract the content of the ZIP file
mkdir vLWC-2.3.26-<serial>
tar -C vLWC-2.3.26-<serial>/ -xf vLWC-2.3.26-<serial>.ova
cd vLWC-2.3.26-<serial>/

# Recover the un-encrypted serial number from the filename and take note of the output of this command
basename -s .ova $(ls -1 ~/import/juniper/*ova)| awk -F "-" '{ print $NF }'

# Recover the encrypted serial number from the OVF file and take note of the output of this command
grep --color serial_number ~/import/juniper/vLWC-2.3.26-<serial>/vLWC-2.3.26-<serial>.ovf |awk '{ print $6 }'|cut -f 2 -d '"'

{% endhighlight %}

{:start="2"}
2. Montamos o sistema para modificá-lo
{% highlight shell %}
# Make sure you start in the same directory we were working before. We move to the directory containing the disk image.
cd vLWC-2.3.26-<serial>/

# Convert from VMDK to RAW
qemu-img  convert vLWC-2.3.26-<serial>-disk1.vmdk vLWC-2.3.26-<serial>-disk1.raw

# Bind disk to loopback device
losetup -f -P vLWC-2.3.26-<serial>-disk1.raw
# Confirm binding
losetup -l 

# Create a mount point for the vLWC system
mkdir -p /mnt/loop-root
# Mount the first partition
MYLOOP=$(losetup -l|grep vLWC | awk '{ print $1 }')
mount ${MYLOOP}p1 /mnt/loop-root/
mount -o bind /dev /mnt/loop-root/dev/
mount -o bind /proc /mnt/loop-root/proc/
chroot /mnt/loop-root/
{% endhighlight %}

{:start="3"}
3. Como mencionado, precisamos definir o número de série correto. Essa seria a única mudança obrigatória
{% highlight shell %}
# Define variables with serial data for your appliance
MYSERIAL="your plain text serial number"
MYSERIALENCRYPTED="your encrypted serial number"

# Set encrypted serial parameter
echo $(cat /opt/jsas/etc/vlwc-status.json | jq --arg val "$MYSERIALENCRYPTED" '.properties.serial_number = $val') > /opt/jsas/etc/vlwc-status.json
# Set plain text serial
echo -n "$MYSERIAL" > /home/jsas/nfxserialnum

{% endhighlight %}

{:start="4"}
4. Mudanças desejáveis. Você as faz enquanto ainda está **dentro** do ambiente chroot. Se quiser, pode colocar todo o bloco em um script.

{% highlight shell %}

##
# QEMU agent
##

# Temporary adjust name resolution to allow package installation from Internet
MYDNS="x.y.z.w"
mv /etc/resolv.conf{,.orig}
echo "nameserver $MYDNS" > /etc/resolv.conf
# We install QEMU agent
apt install qemu-guest-agent
# Restore original DNS resolution config
mv /etc/resolv.conf{.orig,}

##
# Hostname. We don't do this anymore until Juniper releases an update that moves the appliance version validation from the hostname.
##
#NO# MYHOSTNAME="short.TLD"
# We backup original setup
#NO# cp -p /etc/hostname{,.orig}
# We define new hostname
#NO# echo $MYHOSTNAME > /etc/hostname

# In case you did change the hostname, the rollback would be:
# mv /etc/hostname{,.mine}
# mv /etc/hostname{.orig,}
# hostname $(cat /etc/hostname)

##
# Timezone
##

# Set your preferred timezone. You can get a list from timedatectl list-timezones
timedatectl set-timezone <Region>/<Country>

##
# SSH key for root
##

# Create the missing directory
mkdir ~/.ssh
# Add your public key to the trusted keys
YOURPUBKEY="key-type your-full-public-key-should-go-here key-alias"
echo "$YOURPUBKEY" >> ~/.ssh/authorized_keys

{% endhighlight %}

{:start="5"}
5. Desmontamos a imagem e desvinculamos o dispositivo

{% highlight shell %}
# we exit the chroot
exit
# umount filesystems
umount /mnt/loop-root/dev /mnt/loop-root/proc /mnt/loop-root
# unbind device
losetup -d $MYLOOP
{% endhighlight %}

Neste ponto, a imagem de disco contém a configuração necessária para o seu site/instância.

### Criação da VM {#vm-creation}

Para uma solução suportada em vSphere, o arquivo OVF é importado no vCloud Director ou no vCenter. Ele inclui a definição da VM (quantidade e tipo de CPU, RAM, discos e adaptadores de rede).

Não podemos usar o arquivo OVF no Proxmox VE; deveria funcionar, mas na prática encontrei alguns problemas de formatação.

Acesse sua máquina PVE via SSH e crie um script para implantar a VM:

{% highlight shell %}
root@pve01:~/import/juniper# cat > import-vlwc.sh<<'EOF'
#!/bin/bash
# We set the bridge & the VLAN we need to integrate de VM to.
BRIDGE=vmbr0
VLAN=4089
# Storage destination for the appliance to live in
STORAGE=local-zfs
# Source disk image
DSK=vLWC-2.3.26-<serial>/vLWC-2.3.26-<serial>-disk1.raw

# We need the next VM ID available
NEWVM=$(pvesh get /cluster/nextid)
# Proper VM name
VMNAME=jsi-vlwc01.<my-TLD>

# We create the VM without disks. 6 vCPU + 16GB for up to 10k devices, most probably you can live with less resources.
qm create $NEWVM --name $VMNAME --bios seabios --machine q35 \
--numa 1 --sockets 1 --cores 6 \
--scsihw virtio-scsi-pci \
--memory 16384 \
--agent enabled=1

# We add the disk we have prepared, and attach it to the VM.
qm importdisk $NEWVM $DSK $STORAGE
qm set $NEWVM -scsi0 ${DISK} ${STORAGE}:vm-${NEWVM}-disk-0
# Boot device at BIOS
qm set $NEWVM --boot order=scsi0

# We add NIC with the correct VLAN mapping
qm set $NEWVM \
--net0 model=virtio,bridge=${BRIDGE},firewall=1,tag=${VLAN}

# We start the VM
qm start
EOF

# Allow the script to be executed
root@pve01:~/import/juniper# chmod +x import-vlwc.sh

# Create VM
root@pve01:~/import/juniper# ./import-vlwc.sh
{% endhighlight %}

Depois de alguns minutos, você deve conseguir acessar a visualização web do captive portal pelo FQDN do appliance (supondo que você tenha uma integração DHCP+DNS adequada) ou pelo endereço IP dele.

Use o número de série em texto puro para fazer login e procure por "Juniper Cloud Connected" + "Cloud Provisioned" para ter certeza de que ele está online.


## Lista de desejos para o PLM {#wishlist-for-the-plm}

Caso um Product Owner do appliance Juniper vLWC passe por aqui :), eu recomendaria incluir o seguinte no backlog:

### 1- Suporte a uma configuração de interface única {#1--support-for-a-single-interface-setup}

Eu entendo perfeitamente a configuração de 3 interfaces para um appliance físico que fica colocalizado com um MX960 solitário em um site remoto esquecido por Deus. Você tem:
- Uma porta "trusted" conectada a uma rede OOBM que atende vários NEs ou diretamente à porta OOBM de um roteador solitário.
- Uma porta "outside" que dá acesso à Internet, provavelmente vindo de um NE do lado do ISP e na qual não se deveria confiar (sem serviços como SSH escutando).
- Uma porta "management" que daria acesso ao appliance a um engenheiro no local, provavelmente conectada diretamente ao notebook dele(a).

Meu palpite pouco embasado é que o appliance virtual basicamente seguiu uma abordagem de "enfiar numa VM o que tínhamos na versão [appliance físico](https://www.juniper.net/documentation/us/en/hardware/lwc-hardware-guide/lwc/topics/concept/lwc-description.html)".

Uma máquina virtual muito provavelmente será implantada em um aconchegante datacenter TIER-alguma-coisa, em um cluster de virtualização de verdade, com uma configuração lógica bem elaborada de gerenciamento e monitoramento, com integrações L3 para os destinos que forem necessários e serviços como filtragem/segmentação fora do appliance.

O pedido seria: por favor, suportem/permitam uma configuração de "interface única" como alternativa à de 3 portas. Hoje funciona como está, tirando os erros relacionados a EXT na página de status.

### 2- Uma distribuição Linux mais nova {#2--newer-linux-distribution}

A partir do vLWC-2.3.26, o appliance é baseado no Ubuntu 18.04.6 LTS, que já está [fora do Standard Support desde junho de 2023](https://wiki.ubuntu.com/Releases). Somente assinantes do suporte Ubuntu Pro receberão versões de patch mínimas, e após uma verificação rápida posso dizer que isso não está disponível no appliance implantado (talvez até com uma versão de openssl com bugs?):

{% highlight shell %}
root@ggc-lnx:~# pro status
Failed to access URL: https://contracts.canonical.com/v1/resources?architecture=amd64&kernel=4.15.0-212-generic&series=bionic&virt=kvm
Cannot verify certificate of server
Please check your openssl configuration.
{% endhighlight %}

Instâncias de distribuições Linux antigas e as implicações de segurança para um dado ambiente são um assunto batido. Eu resumiria o pedido assim: está na hora de um refresh do SO e o Ubuntu 22.04.3 LTS está à disposição de vocês. Não, "eventualmente vamos reempacotar uma nova versão do appliance com os patches aplicados e você deve reimplantar" não é aceitável

### 3- Suporte a PVE/KVM {#3--support-for-pvekvm}

Nem todas as empresas Juniper rodam VMware vSphere no lado de compute e, se rodam, pode ser que não seja a escolha para absolutamente todas as implantações. Embora eu valorize o trabalho feito na preparação do arquivo [OVF](https://www.dmtf.org/standards/ovf) para automatizar a configuração inicial, recomendo fortemente que a sua equipe invista algum tempo implementando suporte a [cloud-init](https://cloudinit.readthedocs.io/en/latest/) no script de configuração inicial, que é o padrão de fato para implantar appliances virtuais em ambientes cloud (KVM on prem, vSphere, AWS, Azure, etc).

Algumas frutas ao alcance da mão:
- Os drivers de interface de rede VirtIO já estão disponíveis no appliance (recomendados para KVM/QEMU, sem se limitar ao VMXNET3). Usados nesta implantação.
- O QEMU agent pode ser instalado facilmente a partir dos repositórios Ubuntu pré-configurados no appliance (desejável, cobre parte da funcionalidade do VMware Tools para KVM/QEMU). Usado nesta implantação.
- O agente cloud-init pode ser instalado facilmente a partir dos repositórios Ubuntu pré-configurados no appliance. Não usado nesta implantação.

### 4- Permitir a mudança de hostname {#4--allow-for-hostname-change}

Devido a alguns requisitos/convenções discutíveis que temos, precisamos atribuir um hostname adequado à VM. Parece que ele é usado para o versionamento do appliance, como anotado um pouco antes no artigo.
- Fazemos o nome da VM e o hostname do SO coincidirem para fins de inventário (consolidação e checagem cruzada de dados de várias ferramentas).
- Parte dos controles SOX recomenda que uma convenção de nomes de hostname adequada seja aplicada.
- O registro via DHCP atualiza os registros DNS; ter mais de um appliance implantado bagunça essa integração automatizada.

Minha forte recomendação é que vocês movam o reporte de versão do appliance para uma entrada de metadados própria em outro lugar, e deixem o hostname ser um hostname.
