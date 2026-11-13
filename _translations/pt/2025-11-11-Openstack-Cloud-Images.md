---
title: "Imagens Cloud para Openstack"
description: "Passo a passo do processo de importação de Cloud Images para o Openstack."
date: 2025-11-11 00:00:00 -0300
permalink: /pt/datacenter/2025/11/11/Openstack-Cloud-Images.html
lang: pt
categories:
  - virtualization
tags:
  - openstack
  - cloud-images
---

Assim que o seu reluzente ambiente Openstack estiver no ar, você vai querer começar imediatamente a provisionar máquinas virtuais. O ponto de partida são as imagens de sistema operacional, que fornecem a cópia base do sistema operacional a ser usada nas suas novas máquinas virtuais.

As imagens incluem tanto os dados do disco do SO quanto o que normalmente seriam propriedades da máquina virtual em outras plataformas de virtualização.

Aqui vou apresentar um procedimento para preparar imagens de nível produtivo vindas dos fornecedores usuais de distribuições Linux.

<!--more-->

## Cloud Images {#cloud-images}

Entram em cena as ["Cloud Images"](https://docs.openstack.org/image-guide/obtain-images.html). Essas imagens de SO são basicamente instâncias preparadas/curadas pelos diferentes projetos (ou empresas) de distribuições Linux, prontas para dar boot em um ambiente cloud (AWS, Azure, GCP, Openstack, etc). Você pode considerá-las tão seguras quanto o instalador ISO que você baixa para a sua distribuição favorita, elas têm um footprint mínimo e normalmente incluem cloud-init para automatizar o processo de implantação.

No Openstack, o cloud-init é crítico para a implantação, pois você não quer redimensionar o disco de boot, adicionar usuários ou configurar TCP/IP na mão. Além disso, o QEMU Guest Agent é altamente recomendado ao virtualizar em KVM, para permitir backups consistentes e possibilitar alguma automação do inventário operacional.

As distribuições Linux pagas (como SLES ou RHEL) também fornecem cloud images. Não consigo encontrar uma imagem Cloud do Windows Server 2025 para baixar (vergonha, Microsoft!).

## Configuração {#configuration}

A definição real da máquina virtual precisa ser configurada como propriedades durante o processo de importação da imagem de disco. Nós vamos defini-las, já que isso não faz parte dos arquivos de Cloud Images que você baixa.

Alguns atributos que proponho aqui fornecem documentação adequada (nome, versão, licenciamento, etc.), outros fornecem boas práticas de desempenho (tipo de máquina, tipos de NIC/HBA) ou boas práticas operacionais (parâmetros relacionados a backup).

## Formato do disco {#disk-format}

No meu caso, estou usando Ceph RBD como backend do Cinder. Se você pedir ao Cinder/Nova para criar um volume a partir de uma imagem qcow2, ele vai primeiro baixar a imagem, convertê-la para raw e depois reenviá-la ao Ceph. Isso consome muito mais espaço no Ceph, mais banda de rede e é propenso a timeouts se a conversão e o envio demorarem demais.

Se você usa um backend de sistema de arquivos, vá de QCOW2, mas se usa Ceph RBD como eu, vá de RAW para se beneficiar da clonagem Copy-on-Write das imagens tanto no Cinder quanto no Nova e de tempos de instanciação mais rápidos.
 

## Ferramentas {#tooling}

Dependendo da máquina em que você estiver trabalhando, instale o guestfs-tools. Isso nos permitirá personalizar a imagem.

openSUSE:

{% highlight shell %}
sudo zypper install -y guestfs-tools
{% endhighlight %}

Ubuntu:

{% highlight shell %}
sudo apt install -y libguestfs-tools whois
{% endhighlight %}

## Imagens gratuitas {#free-images}

Encontre um lugar para baixar arquivos

{% highlight shell %}
mkdir cloud-images
cd cloud-images
{% endhighlight %}
	
### openSUSE {#opensuse}

Minha favorita pessoal; vamos baixar o Leap, que é muito parecido com o SLES (a versão comercial da distribuição). Outras alternativas são o Tumbleweed (bleeding edge) ou o Slowroll ("quero algo mais novo, mas sem enlouquecer").

Ele já suporta cloud-init, só habilitamos o suporte ao dispositivo PTP para ser usado pelo chrony como referência de tempo. O host KVM basicamente o fornece para os guests [sincronizarem a hora](https://www.libertysys.com.au/2024/04/vm-timekeeping-using-the-ptp-hardware-clock-on-kvm/) e, ao contrário do que acontece com o VMware Guest Tools, o QEMU Guest Agent não oferece capacidades de sincronização de hora.

{% highlight shell %}
# Some helper variables
IMG=Leap-16.0-Minimal-VM.x86_64-Cloud.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-opensuse-leap-16.0-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://download.opensuse.org/repositories/openSUSE:/Leap:/16.0:/Images/images/${IMG}

# Fix PTP synchronization
echo ptp_kvm > /tmp/ptp_kvm.conf
sudo virt-customize -a ${IMG} --copy-in /tmp/ptp_kvm.conf:/etc/modules-load.d/

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='opensuse' \
--property os_version='16.0' \
--property os_license=opensource \
--property os_admin_user='opensuse' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="openSUSE Leap 16.0 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}


### Rocky Linux {#rocky-linux}

A ferramenta de sempre para os refugiados do CentOS. O cloud-init está disponível de fábrica. 

#### Imagem baseada em LVM {#lvm-based-image}

Caso você queira ter todos os seus sistemas de arquivos sob gerenciamento do LVM, o projeto fornece uma imagem específica. A única desvantagem é que o redimensionamento de sistema de arquivos do cloud-init não vai funcionar e serão necessárias manobras manuais (não espere que usuários Linux hardcore tenham problema com isso).

{% highlight shell %}
# Some helper variables
IMG=Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2 
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-rocky-9-lvm-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='rocky' \
--property os_version='9.6' \
--property os_license=opensource \
--property os_admin_user='rocky' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=false \
--property description="Rocky Linux 9.6 with LVM - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}


#### Imagem com partições simples {#bare-partitions-image}

Esta imagem tem partições simples para os sistemas de arquivos do sistema operacional. Como com qualquer outra imagem Linux, você ainda pode usar LVM para os discos de dados (e provavelmente deveria, já que a migração a quente entre pools do Ceph não é suportada pelo Openstack e o LVM dentro do guest pode salvar o dia quando for necessário realocar dados)

{% highlight shell %}
# Some helper variables
IMG=Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-rocky-9-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='rocky' \
--property os_version='9.6' \
--property os_license=opensource \
--property os_admin_user='rocky' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=false \
--property description="Rocky Linux 9.6 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

### Oracle Enterprise Linux 9 {#oracle-enterprise-linux-9}

Este é esquisito e nunca fui fã. Outro clone do RHEL com vantagens injustas em relação às regras de licenciamento inventadas da Oracle. Assim como o Ubuntu, você pode pagar por suporte ou não. Os repositórios são públicos.

{% highlight shell %}
# Some helper variables
IMG=OL9U5_x86_64-kvm-b259.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-oel-9.5-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://yum.oracle.com/templates/OracleLinux/OL9/u5/x86_64/${IMG}

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='oel' \
--property os_version='9.5' \
--property os_license=opensource \
--property os_admin_user='oracle' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=false \
--property description="Oracle Enterprise Linux 9.5 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

### Ubuntu 24.04 {#ubuntu-2404}

Distribuição onipresente; se você gosta de Debian, vai se sentir em casa.

{% highlight shell %}
# Some helper variables
IMG=noble-server-cloudimg-amd64.img
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-ubuntu-24.04.3-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://cloud-images.ubuntu.com/noble/current/${IMG}

# Install QEMU Guest Agent
sudo virt-customize -a ${IMG} --install qemu-guest-agent

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='ubuntu' \
--property os_version='24.04.3' \
--property os_license=opensource \
--property os_admin_user='ubuntu' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Ubuntu 24.04.3 (Noble) - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

### Ubuntu 22.04 {#ubuntu-2204}

Versão mais antiga do Ubuntu, ainda em uso.

{% highlight shell %}
# Some helper variables
IMG=jammy-server-cloudimg-amd64.img
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-ubuntu-22.04.5-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://cloud-images.ubuntu.com/jammy/current/${IMG}
sudo virt-customize -a ${IMG} --install qemu-guest-agent

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='ubuntu' \
--property os_version='22.04.5' \
--property os_license=opensource \
--property os_admin_user='ubuntu' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Ubuntu 22.04.5 (Jammy) - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

### Debian 12 {#debian-12}

Onipresente e ainda relevante.

{% highlight shell %}
# Some helper variables
IMG=debian-12-generic-amd64.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-debian-12-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://cdimage.debian.org/images/cloud/bookworm/latest/${IMG}
sudo virt-customize -a ${IMG} --install qemu-guest-agent

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='debian' \
--property os_version='12.12' \
--property os_license=opensource \
--property os_admin_user='debian' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Debian 12.12 (Bookworm) - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

## Imagens pagas {#paid-images}

### RedHat Enterprise Linux 10 {#redhat-enterprise-linux-10}

Existem empresas que ainda exigem esse cara. Você terá que baixar o arquivo pelo portal pago e colocá-lo no diretório de trabalho.

{% highlight shell %}
# Some helper variables
IMG=rhel-10.0-x86_64-kvm.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-rhel-10.0-x86_64-$(date '+%Y%m%d.%H%M')

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='rhel' \
--property os_version='10.0' \
--property os_license=rhel \
--property os_admin_user='cloud-user' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="RedHat Enterprise Linux 10.0 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}


### RedHat Enterprise Linux 9 {#redhat-enterprise-linux-9}

O mesmo, só que mais antigo. O arquivo precisa ser baixado e copiado para o diretório de trabalho.

{% highlight shell %}
# Some helper variables
IMG=rhel-9.6-x86_64-kvm.qcow2
IMGRAW="${IMG%.qcow2}.raw"
NAME=ci-rhel-9.6-x86_64-$(date '+%Y%m%d.%H%M')

# Convert to RAW
qemu-img convert -f qcow2 -O raw ${IMG} ${IMGRAW}

# Import
openstack image create \
--disk-format raw --container-format bare \
--progress \
--property os_type='linux' \
--property os_distro='rhel' \
--property os_version='9.6' \
--property os_license=rhel \
--property os_admin_user='cloud-user' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="RedHat Enterprise Linux 9.6 - Cloud Image" \
--public --file ${IMGRAW} \
${NAME}
{% endhighlight %}

## Como usar as imagens? {#how-to-use-the-images}

Então, depois de toda essa preparação, devemos conseguir instanciar uma máquina virtual e configurá-la automaticamente com o cloud-init com o procedimento abaixo.

Ele vai pegar a imagem, criar um disco virtual com o tamanho adequado para o sistema operacional dar boot e instanciar a nossa reluzente VM com os parâmetros definidos na imagem. Como um exemplo rápido do que pode ser feito com o cloud-init, também instalamos e iniciamos um servidor web com uma página inicial básica para ser publicada.

{% highlight shell %}
##
# Credentials
##

source novarc

## 
# Helper variables
##
# Network that will host the VM
TESTNETWORK="tnt01-dflt-internal-net"
# Alternative reference by ID
TESTNETWORKID=$(openstack network show ${TESTNETWORK} -f json| jq .id|tr -d '"')
# VM name
TESTVMNAME="prd-mysuper-vm-001"
# VM flavor to use
FLAVOR=c4a.4c-8G
# Base image to use
IMAGE=ci-opensuse-leap-16.0-x86_64-20251111.2246
# OS Disk size in GB
OSDISKSIZE=60
# Were we put the temporary files
TMPDIR=tmpdir-${RANDOM}
# User account to use
MYUSER=cloudadmin
# Our SSH public key for authentication
SSHKEY="ssh-ed25519 AAAA...Ica5ij ciro@laptop001"

##
# Creation procedure
##

# We create our cloud-init config file
mkdir -p ${TMPDIR}

cat > ${TMPDIR}/userdata.yaml <<EOF
#cloud-config
hostname: ${TESTVMNAME}
users:
  - name: ${MYUSER}
    ssh-authorized-keys:
      - ${SSHKEY}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
#packages:
#  - vim
#  - curl
#  - apache2
runcmd:
  # Add repository
  - zypper ar -f -c https://download.opensuse.org/distribution/leap/16.0/repo/oss/x86_64/ leap-16-oss
  - zypper in -y vim curl apache2
  # Enable and start Apache
  - systemctl enable apache2
  - systemctl start apache2
  # Create Simple index.html
  - ['sh', '-c', 'echo "<h1>Hello world!</h1>" > /srv/www/htdocs/index.html']
- # Firewall is not present
  #- firewall-cmd --permanent --add-service=http
  #- firewall-cmd --reload
EOF

# Create the VM instance
openstack server create \
--image ${IMAGE} \
--flavor ${FLAVOR} \
--network ${TESTNETWORK} \
--use-config-drive \
--user-data ${TMPDIR}/userdata.yaml \
--boot-from-volume ${OSDISKSIZE} \
${TESTVMNAME}

# List all the VMs
openstack server list
{% endhighlight %}

## Oportunidades de melhoria {#improvement-opportunities}

Bem, o procedimento compartilhado constrói um bom ponto de partida. Coisas que vejo que precisam ser tratadas:

### 1- ptp_kvm para todos os guests {#1--ptp_kvm-for-all-the-guests}

O módulo do kernel parece ser suportado pelo RHEL e clones como Rocky ou OEL:
- [KVM Guest Timing Management](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/chap-kvm_guest_timing_management)

Parece não ser suportado pelo Ubuntu. Sobram o NTP contra servidores conectados pela rede ou nenhuma sincronização (péssima escolha):
- [LP #1896311](https://bugs.launchpad.net/ubuntu/+source/linux-kvm/+bug/1896311)
- [LP #1950878](https://bugs.launchpad.net/ubuntu/+source/linux-meta-kvm/+bug/1950878)

Preciso arranjar tempo para testar e documentar o procedimento de configuração

### 2- Licenciamento do SO {#2--os-licensing}

É necessária configuração adicional para associar corretamente as instâncias guest pagas a um subconjunto de nós de um determinado deployment Openstack. Identifiquei duas opções (propriedades da imagem + Host Aggregates ou traits), mas é necessário testar de verdade.

### 3- Guests Windows Server {#3--windows-server-guests}

Parece continuar sendo um mal necessário em 2025 para grandes organizações. Preciso arranjar tempo para criar um procedimento de criação de imagens; ele deve incluir o Cloudbase-init como alternativa ao cloud-init.
