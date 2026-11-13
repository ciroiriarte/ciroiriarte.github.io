---
title: "vSAN ESA em ESXi sobre PVE"
description: "Cluster vSAN ESA aninhado para fins de teste"
date: 2023-09-07 00:00:00 -0400
permalink: /pt/homelab/2023/09/07/vsan-esa-on-esxi-over-pve.html
lang: pt
categories:
  - virtualization
  - storage-backup
tags:
  - proxmox
  - esxi
  - vsan
  - nested-virtualization
---

## Um pouco de contexto {#a-little-bit-of-context}

### vSAN OSA {#vsan-osa}
Uma das minhas maiores dores como cliente em relação à oferta SDDC da VMware é o vSAN OSA. Quando o vi em ação pela primeira vez, pareceu uma resposta "eu também" à [Nutanix](https://www.nutanix.com/mx/info/software-defined-storage), que introduzimos com sucesso, acredito que como primeiro cliente no Paraguai, por volta de 2016 (se a memória não me falha). 

Além disso, vindo de um histórico de soluções baseadas em FibreChannel como o [vMAX da EMC](https://www.youtube.com/watch?v=Zp3yMGlzZhM) e o [VSP da Hitachi](https://knowledge.hitachivantara.com/Documents/Storage/VSP_G1X00_and_VSP_F1500/80-06-6x/Hardware_Guide/03_Hardware_architecture), era uma venda realmente difícil em termos de funcionalidades (sem snapshots, sem tiering, sem replicação, etc.) e partir para clusters de 20 nós só porque precisávamos de capacidade para bancos Oracle enormes não fazia sentido (não é custo-efetivo)

Outra forma de ver: se você comparar o vSAN OSA no vSphere com outras soluções que servem Xen ou KVM, falta flexibilidade:
- um único pool por cluster
- um único tipo de disco
- o disco de cache como ponto de falha importante

Quando não havia ESXi à vista, simplesmente íamos com qualquer outra alternativa, como [CEPH](https://docs.ceph.com/en/latest/architecture/) ou [MooseFS](https://moosefs.com/blog/architecture/) (nada de [GlusterFS](https://docs.gluster.org/en/main/Quick-Start-Guide/Architecture/), ninguém gosta de você....)

Pelo lado positivo, é uma porta de entrada interessante para alternativas melhores para quem está tecnologicamente atrasado: pense em iSCSI com 1GbE ou CIFS/SMB3 servido pelo seu servidor de arquivos Windows Server :s

Resumindo, faz sentido se:
- você é uma empresa VMware com equipe(s) de infraestrutura bem limitada(s)
- você quer uma forma rápida de introduzir uma plataforma de virtualização
- não existe um Storage + SAN centralizado para começar
- suas necessidades de armazenamento não são desproporcionais em relação ao compute
- você não precisa de serviços avançados de armazenamento, como tirar snapshots dos discos do seu banco Oracle de produção de 40TB em operação (10*4TB + ASM) para apresentá-los a uma instância secundária de relatórios.

### vSAN ESA {#vsan-esa}
A primeira vez que ouvi falar do [vSAN ESA](https://core.vmware.com/blog/introduction-vsan-express-storage-architecture) foi no evento VMware Explore 2022. Não é perfeito, mas é um passo na direção certa.

Só para deixar claro, estou bem satisfeito com a evolução. :)

Não deixe de assistir à gravação sob demanda da sessão do VMware Explore 2022 [Get to Know the Next-Generation of vSAN Architecture](https://www.vmware.com/explore/video-library/video-landing.html?sessionid=1663909090011001QAvr&videoId=6315818080112) para entender todas as novidades.

## Voltando ao nosso ambiente aninhado no Proxmox. {#going-back-to-our-proxmox-nested-environment}

Com esse contexto, recomendo muito que você explore as mudanças da nova arquitetura.

Se você quiser colocar a mão na massa, o vSAN ESA pode ser implantado no nosso ambiente aninhado ESX-on-KVM/Proxmox. 

Claro:
- não será suportado, mas vai permitir que você brinque com ele
- testes de desempenho de verdade vão exigir um ambiente físico devidamente suportado

Haverá avisos, porque não atendemos nenhuma [configuração suportada](https://kb.vmware.com/s/article/90343), notadamente:
- interfaces de 25GbE
- controladoras NVMe
- 512GB de RAM por nó

### Controladora de disco {#disk-controller}

Num mundo ideal, deveríamos usar uma controladora NVMe, que o QEMU suporta, mas [o Proxmox ainda não suporta](https://bugzilla.proxmox.com/show_bug.cgi?id=2255). Dado esse cenário, vamos com a controladora SATA padrão.

### Provisionamento dos discos {#provisioning-of-the-disks}

Para este teste, vamos pegar 3 instâncias de ESXi aninhadas e adicionar a cada uma 3 discos de 100GB emulando SSD. Você pode usar mais discos e/ou maiores, o céu (a sua carteira?) é o limite.

{% highlight shell %}
STORAGE=dstore01
for VM in esxi01 esxi02 esxi03
do
    # We get the ID to operate on the VM
    VMID=$(qm list|grep ${VM}|awk '{ print $1 }')
    # Adding disks, emulating SSD
    qm set ${VMID} --sata3 ${STORAGE}:100,format=qcow2,ssd=1,discard=on \
        --sata4 ${STORAGE}:100,format=qcow2,ssd=1,discard=on \
        --sata5 ${STORAGE}:100,format=qcow2,ssd=1,discard=on
done
{% endhighlight %}

## Configuração do vSAN {#vsan-setup}

Você pode configurar o cluster vSAN como normalmente faria, durante a implantação do vCenter ou depois de ele estar no ar.

O primeiro aviso que você verá é que as NICs não são suportadas (exigem-se 25GbE). Você pode seguir em frente mesmo assim.

{% include image.html url="/assets/img/2023-09-07-nic-speed-warning.png" description="Imagem 1 - Aviso de NIC" alt="Aviso de NIC" width=1365 height=907 %}

Se você seguir em frente, os discos serão marcados como incompatíveis. Basta reivindicá-los (claim) manualmente.

{% include image.html url="/assets/img/2023-09-07-incompatible-disk-warning.png" description="Imagem 2 - Disco marcado como não compatível" alt="Disco marcado como não compatível" width=1817 height=683 %}

{% include image.html url="/assets/img/2023-09-07-disk-claiming.png" description="Imagem 3 - Claim manual" alt="Claim manual" width=1800 height=812 %}

## Resultado {#outcome}

Depois de alguns minutos, você deve ter o seu cluster vSAN de ESXi aninhado sobre PVE, funcionando mas sem suporte.

Divirta-se!
