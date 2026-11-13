---
title: "ESXi no Proxmox como hipervisor aninhado"
description: "Implementação passo a passo de uma máquina ESXi aninhada rodando em um host KVM Proxmox/PVE."
date: 2023-09-05 00:00:00 -0400
permalink: /pt/homelab/2023/09/05/esxi-on-proxmox-as-nested-hypervisor.html
lang: pt
categories:
  - virtualization
tags:
  - proxmox
  - esxi
  - nested-virtualization
---

Graças ao trabalho de [William Lam](https://williamlam.com/nested-virtualization), rodar ESXi sobre ESXi para testes/laboratório é muito simples.

Agora, se por algum motivo você não pode instalar o ESXi na sua máquina de home lab e, como eu, usa Proxmox, este post é para você.

O [Proxmox Virtual Environment](https://www.proxmox.com/) ou PVE é uma boa solução de virtualização baseada em KVM da [Proxmox Server Solutions GmbH](https://www.proxmox.com/en/about/company). É gratuito e tem uma base de usuários ampla.

O ponto de partida seria um [host Proxmox corretamente configurado para virtualização aninhada](https://pve.proxmox.com/wiki/Nested_Virtualization). Depois que ele estiver de pé e funcionando, estamos prontos para seguir em frente.

## O appliance do ESXi {#the-esxi-appliance}
Este [appliance do ESXi](https://williamlam.com/nested-virtualization/nested-esxi-virtual-appliance) vem pré-configurado para simplificar a implantação como hipervisor aninhado. A cada nova versão do vSphere, um appliance correspondente é criado e publicado.

## Baixando o appliance {#downloading-the-appliance}
Os appliances mencionados são publicados por meio de uma Content Library pública do vSphere. Para obter a lista de versões disponíveis, podemos executar o seguinte comando a partir do seu host PVE:

{% highlight shell %}
BASEURL=https://download3.vmware.com/software/vmw-tools
curl -s ${BASEURL}/items.json |grep -A 1 "hrefs"|grep -vE "\-\-|hrefs"|sort |cut -f 2 -d '"'|cut -f 1 -d "/"|sort -u
{% endhighlight %}

A saída deve ser parecida com:

{% highlight shell %}
Nested_ESXi6.0u3_Appliance_Template_v1.0
Nested_ESXi6.5d_Appliance_Template_v1.0
Nested_ESXi6.5u1_Appliance_Template_v1.0
Nested_ESXi6.5u2_Appliance_Template_v1.0
Nested_ESXi6.5u3_Appliance_Template_v1.0
Nested_ESXi6.7_Appliance_Template_v1.0
Nested_ESXi6.7u1_Appliance_Template_v1.0
Nested_ESXi6.7u2_Appliance_Template_v1.0
Nested_ESXi6.7u3_Appliance_Template_v1.0
Nested_ESXi7.0_Appliance_Template_v1.0
Nested_ESXi7.0u1_Appliance_Template_v1.0
Nested_ESXi7.0u1d_Appliance_Template_v1.0
Nested_ESXi7.0u2a_Appliance_Template_v2.0
Nested_ESXi7.0u2_Appliance_Template_v1.0
Nested_ESXi7.0u3_Appliance_Template_v1.0
Nested_ESXi7.0u3c_Appliance_Template_v1.0
Nested_ESXi7.0u3d_Appliance_Template_v1.0
Nested_ESXi7.0u3e_Appliance_Template_v1.0
Nested_ESXi7.0u3f_Appliance_Template_v1.0
Nested_ESXi7.0u3g_Appliance_Template_v1.0
Nested_ESXi7.0u3i_Appliance_Template_v1.0
Nested_ESXi7.0u3j_Appliance_Template_v1.0
Nested_ESXi7.0u3k_Appliance_Template_v1.0
Nested_ESXi7.0u3l_Appliance_Template_v1.0
Nested_ESXi7.0u3m_Appliance_Template_v1.0
Nested_ESXi8.0a_Appliance_Template_v1.0
Nested_ESXi8.0b_Appliance_Template_v1.0
Nested_ESXi8.0c_Appliance_Template_v1.0
Nested_ESXi8.0_IA_Appliance_Template_v2.0
Nested_ESXi8.0u1a_Appliance_Template_v1
Nested_ESXi8.0u1_Appliance_Template_v1.0
{% endhighlight %}

Escolha a que você quiser usar e baixe todos os arquivos relacionados:

{% highlight shell %}
# We create the destination directory
mkdir esxi;cd esxi
# Variable holding the chosen appliance name
APPLIANCE=Nested_ESXi8.0u1a_Appliance_Template_v1
# Get the list of the files we'll fetch
FILES=$(curl -s ${BASEURL}/items.json |grep -A 1 "hrefs"|grep -vE "\-\-|hrefs"|sort |cut -f 2 -d '"'|grep $APPLIANCE)
# For loop to download file by file
for F in $FILES
do
    wget ${BASEURL}/${F}
done
{% endhighlight %}

Você deve terminar com um conjunto de arquivos parecido com:

{% highlight shell %}
root@bigiron:~/esxi# ls -l
total 1696791
-rw-r--r-- 1 root root   865786368 Jun  2 11:38 Nested_ESXi8.0u1a_Appliance_Template_v1-disk1.vmdk
-rw-r--r-- 1 root root       68096 Jun  2 11:35 Nested_ESXi8.0u1a_Appliance_Template_v1-disk2.vmdk
-rw-r--r-- 1 root root       68608 Jun  2 11:35 Nested_ESXi8.0u1a_Appliance_Template_v1-disk3.vmdk
-rw-r--r-- 1 root root         389 Jun  2 11:35 Nested_ESXi8.0u1a_Appliance_Template_v1.mf
-rw-r--r-- 1 root root       54052 Jun  2 11:35 Nested_ESXi8.0u1a_Appliance_Template_v1.ovf
{% endhighlight %}

## Importando o appliance {#importing-the-appliance}

Depois de baixar os arquivos, vamos criar uma máquina virtual usando o OVF como origem. Ele é usado principalmente para importar as imagens de disco, já que boa parte do arquivo na verdade é ignorada (os parâmetros de configuração avançada, por exemplo, não são levados em conta). Para essa tarefa e a configuração inicial da VM, criei um script rápido (create-esxi.sh) para ser executado no seu host PVE.

{% highlight shell %}
#!/bin/bash

# We need at least 1 VLAN for management & another for vSAN traffic
VLANLAB=302
VLANVSAN=303
# Bridge interface to use (VLAN aware)
BRIDGE=vmbr0
# Storage destination for the appliance to live in
STORAGE=dstore01
# Source OVF file, descriptor of the appliance
OVF=esxi/Nested_ESXi8.0u1a_Appliance_Template_v1.ovf
# Template/appliance name as defined in the OVF file, for us to later rename the VM.
TMPL_NAME=$(grep "<Name>" $OVF| cut -f 2 -d ">" |cut -f 1 -d "<" |sed 's/_//g')

# We need at least the name of the VM to create as script parameter
if [ $# -ne 1 ]
then
        echo "usage $0 <vm name>"
        exit 1
else
        VMNAME=$1
fi

# Basic VM creation and disk files import
qm importovf $(pvesh get /cluster/nextid) ${OVF} ${STORAGE} -format qcow2

# We get the ID of the created VM
NEWVM=$(qm list|grep ${TMPL_NAME}|awk '{ print $1 }')

# We define initial configuration. In this case, 12 cores in total, 2 sockets & 64GB of RAM. EFI boot.
qm set $NEWVM --name $VMNAME --bios ovmf --machine q35 \
--numa 1 --sockets 2 --cores 6 --cpu cputype=host \
--scsihw pvscsi \
--memory 65536 --hugepages 1024 \
--efidisk0 ${STORAGE}:0,efitype=4m,format=qcow2

# We add two network interfaces with the correct VLAN mapping
qm set $NEWVM \
--net0 model=vmxnet3,bridge=${BRIDGE},firewall=0,tag=${VLANLAB} \
--net1 model=vmxnet3,bridge=${BRIDGE},firewall=0,tag=${VLANVSAN}

# The import command attaches the disks to a SCSI controller, the VM doesn't recognize the VMWare PVSCSI controller unluckily. We detach disks from that controller.
for DISK in $(qm config $NEWVM |grep ^scsi|grep $NEWVM|cut -f 1 -d ":")
do
        qm set $NEWVM --delete $DISK
done

# Reattach of disks to SATA controller. The appliance is happier with that one.
n=0
for DISK in $(qm config $NEWVM|grep ^unused|awk '{ print $2 }')
do
        qm set $NEWVM -sata${n} $DISK
        n=$(( $n + 1 ))
done

# Define boot disk
qm set $NEWVM --boot order=sata0

# Start VM
qm start $NEWVM
{% endhighlight %}

Para criar 3 máquinas virtuais para o nosso cluster inicial, basta executar:

{% highlight shell %}
./create-esxi.sh esxi01
./create-esxi.sh esxi02
./create-esxi.sh esxi03
{% endhighlight %}

Depois disso, é necessária a configuração inicial manual do ESXi (hostname, IP estático ou envio do hostname na requisição DHCP, etc.)

## Resultado {#outcome}

No fim, devemos ter as 3 VMs de pé e prontas para testes.

{% include image.html url="/assets/img/2023-09-05-nested-esxi-vm-list.png" description="Imagem 1 - Máquinas virtuais criadas" alt="Console web do PVE" width=425 height=460 %}

{% include image.html url="/assets/img/2023-09-05-nested-esxi-console.png" description="Imagem 2 - Console da VM" alt="Console da VM" width=1290 height=1026 %}

{% include image.html url="/assets/img/2023-09-05-nested-esxi-webUI.png" description="Imagem 3 - Interface web do ESXi" alt="Interface web do ESXi" width=1900 height=785 %}

## Lista de pendências {#todo-list}

#### 1. Parâmetros de configuração avançada {#1-advanced-configuration-parameters}
Parte da experiência "pronto para virtualização aninhada" envolve uma série de configurações avançadas que vêm definidas no arquivo OVF. Algumas são relevantes apenas para os hosts ESXi onde o appliance roda, mas outras talvez precisem ser "traduzidas" para ajustes de configuração do QEMU/KVM.

{% highlight shell %}
root@bigiron:~/esxi# grep -E "vmw:ExtraConfig|vmw:Config" Nested_ESXi8.0u1a_Appliance_Template_v1.ovf
        <vmw:Config ovf:required="false" vmw:key="slotInfo.pciSlotNumber" vmw:value="16"/>
        <vmw:Config ovf:required="false" vmw:key="useAutoDetect" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="videoRamSizeInKB" vmw:value="4096"/>
        <vmw:Config ovf:required="false" vmw:key="enable3DSupport" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="use3dRenderer" vmw:value="automatic"/>
        <vmw:Config ovf:required="false" vmw:key="graphicsMemorySizeInKB" vmw:value="262144"/>
        <vmw:Config ovf:required="false" vmw:key="slotInfo.pciSlotNumber" vmw:value="35"/>
        <vmw:Config ovf:required="false" vmw:key="allowUnrestrictedCommunication" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="backing.exclusive" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="connectable.allowGuestControl" vmw:value="true"/>
        <vmw:Config ovf:required="false" vmw:key="backing.writeThrough" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="backing.writeThrough" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="backing.writeThrough" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="slotInfo.pciSlotNumber" vmw:value="33"/>
        <vmw:Config ovf:required="false" vmw:key="wakeOnLanEnabled" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="connectable.allowGuestControl" vmw:value="true"/>
        <vmw:Config ovf:required="false" vmw:key="uptCompatibilityEnabled" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="uptv2Enabled" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="wakeOnLanEnabled" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="connectable.allowGuestControl" vmw:value="true"/>
        <vmw:Config ovf:required="false" vmw:key="uptCompatibilityEnabled" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="uptv2Enabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="cpuHotAddEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="cpuHotRemoveEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="memoryHotAddEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="firmware" vmw:value="efi"/>
      <vmw:Config ovf:required="false" vmw:key="cpuAllocation.shares.shares" vmw:value="2000"/>
      <vmw:Config ovf:required="false" vmw:key="cpuAllocation.shares.level" vmw:value="normal"/>
      <vmw:Config ovf:required="false" vmw:key="simultaneousThreads" vmw:value="1"/>
      <vmw:Config ovf:required="false" vmw:key="tools.syncTimeWithHost" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.syncTimeWithHostAllowed" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.afterPowerOn" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.afterResume" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.beforeGuestShutdown" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.beforeGuestStandby" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.toolsUpgradePolicy" vmw:value="upgradeAtPowerCycle"/>
      <vmw:Config ovf:required="false" vmw:key="fixedPassthruHotPlugEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="powerOpInfo.powerOffType" vmw:value="soft"/>
      <vmw:Config ovf:required="false" vmw:key="powerOpInfo.resetType" vmw:value="soft"/>
      <vmw:Config ovf:required="false" vmw:key="powerOpInfo.suspendType" vmw:value="soft"/>
      <vmw:Config ovf:required="false" vmw:key="nestedHVEnabled" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="vPMCEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="virtualICH7MPresent" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="virtualSMCPresent" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="flags.vvtdEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="flags.vbsEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="bootOptions.efiSecureBootEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="powerOpInfo.standbyAction" vmw:value="checkpoint"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="disk.enableuuid" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ehci.pcislotnumber" vmw:value="34"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet0.bsdname" vmw:value="en0"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet0.connectiontype" vmw:value="nat"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet0.displayname" vmw:value="Ethernet"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet0.filter4.name" vmw:value="dvfilter-maclearn"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet0.filter4.onfailure" vmw:value="failOpen"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet0.linkstatepropagation.enable" vmw:value="FALSE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet0.pcislotnumber" vmw:value="33"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet1.filter4.name" vmw:value="dvfilter-maclearn"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="ethernet1.filter4.onfailure" vmw:value="failOpen"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="gui.fullscreenatpoweron" vmw:value="FALSE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="gui.viewmodeatpoweron" vmw:value="windowed"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="hgfs.linkrootshare" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="hgfs.maprootshare" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="hpet0.present" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="isolation.tools.hgfs.disable" vmw:value="FALSE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="msg.autoanswer" vmw:value="true"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="parallel0.autodetect" vmw:value="FALSE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge0.pcislotnumber" vmw:value="17"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge0.present" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge4.functions" vmw:value="8"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge4.pcislotnumber" vmw:value="21"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge4.present" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge4.virtualdev" vmw:value="pcieRootPort"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge5.functions" vmw:value="8"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge5.pcislotnumber" vmw:value="22"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge5.present" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge5.virtualdev" vmw:value="pcieRootPort"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge6.functions" vmw:value="8"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge6.pcislotnumber" vmw:value="23"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge6.present" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge6.virtualdev" vmw:value="pcieRootPort"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge7.functions" vmw:value="8"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge7.pcislotnumber" vmw:value="24"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge7.present" vmw:value="TRUE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="pcibridge7.virtualdev" vmw:value="pcieRootPort"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="proxyapps.publishtohost" vmw:value="FALSE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="remotedisplay.vnc.enabled" vmw:value="FALSE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="replay.supported" vmw:value="FALSE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="scsi0.pcislotnumber" vmw:value="16"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="scsi0:1.virtualSSD" vmw:value="true"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="scsi0:2.virtualSSD" vmw:value="true"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="serial0.autodetect" vmw:value="FALSE"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="usb.pcislotnumber" vmw:value="32"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="uuid.action" vmw:value="create"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="virtualhw.productcompatibility" vmw:value="hosted"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="vmci0.pcislotnumber" vmw:value="35"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="vmotion.checkpointfbsize" vmw:value="65536000"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="migrate.hostLog" vmw:value="./Nested_ESXi8.0u1a_Appliance_Template-222fd488.hlog"/>
{% endhighlight %}

Com mais tempo, vou dar uma olhada na lista e publicar uma atualização se for preciso.

#### 2. cloud-init {#2-cloud-init}

O PVE oferece suporte a cloud-init como forma de automatizar o provisionamento e a configuração inicial de VMs. O ESXi não traz um agente de cloud-init de fábrica.

Encontrei uma implementação básica de um agente cloud-init para ESXi feita por [Gonéri Le Bouder](https://github.com/goneri), que algumas pessoas relataram funcionar para implantar ESXi sobre Openstack. Falta ver como injetar esse script no nosso appliance recém-baixado (o local.tgz criptografado se mostrou trabalhoso para esse caso de uso).

- [https://github.com/goneri/esxi-cloud-init](https://github.com/goneri/esxi-cloud-init)
- [https://github.com/virt-lightning/esxi-cloud-images](https://github.com/virt-lightning/esxi-cloud-images)
