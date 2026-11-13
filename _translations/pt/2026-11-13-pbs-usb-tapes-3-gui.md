---
title: "Discos USB como fitas para o Proxmox Backup Server (3/3): apontar e clicar"
description: "A mesma configuração da parte 2, a partir do painel do mhVTL Control e da interface web do PBS. Sobram algumas linhas de shell; todo o resto são cliques."
date: 2026-11-13 10:02:00 -0300
permalink: /pt/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html
lang: pt
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 3
series_title: "Apontar e clicar"
---

A [parte 2](/pt/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html) montou a configuração pelo shell. Esta parte faz isso com o mouse: o [mhVTL Control](https://github.com/ciroiriarte/mhvtl-control) para a biblioteca virtual, e a interface web do PBS para o lado das fitas. Se você não leu a [parte 1](/pt/datacenter/2026/11/13/pbs-usb-tapes-1-why.html), ela explica por que você iria querer jobs de fita do PBS em discos USB, para começo de conversa.

Nem tudo tem um botão ainda: instalar pacotes, ligar as escritas do painel e associar o dock ainda exigem algumas linhas de shell.

<!--more-->

{% include series-nav.html %}

A configuração é a mesma de antes: PBS 4.2 com um datastore chamado `store1`, um dock USB e discos para rotacionar. O ambiente de teste foi uma VM Debian 13 recém-instalada com mhVTL `1.8.0+git20261101.7e3a101` e mhVTL Control 0.6.0, ambos do meu [projeto no OBS](https://build.opensuse.org/project/show/home:ciriarte:mhvtl).

## A parte do shell {#the-shell-part}

Adicione o repositório, instale os dois pacotes e mantenha o driver `ch` do kernel de fora. Ele vaza referências de drive toda vez que um changer aparece, e o PBS não precisa dele (a [parte 2](/pt/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#install-mhvtl) tem os detalhes):

{% highlight shell %}
REPO=https://download.opensuse.org/repositories/home:/ciriarte:/mhvtl/Debian_13
install -d /etc/apt/keyrings
curl -fsSL -o /etc/apt/keyrings/mhvtl.asc $REPO/Release.key
echo "deb [signed-by=/etc/apt/keyrings/mhvtl.asc] $REPO/ /" \
    > /etc/apt/sources.list.d/mhvtl.list
apt-get update
# on a Proxmox kernel, use proxmox-default-headers instead:
apt-get install linux-headers-amd64 mhvtl mhvtl-control
echo "blacklist ch" > /etc/modprobe.d/mhvtl-no-ch.conf
# if this fails, ch is in use: reboot before going on
modprobe -r ch
{% endhighlight %}

O módulo do kernel é compilado com DKMS para o kernel em execução. Se você acabou de atualizar o kernel, reinicie antes.

O painel é somente leitura de fábrica. Para editar são necessários um token de API e um pequeno helper privilegiado que aplica as mudanças:

{% highlight shell %}
TOKEN=$(openssl rand -hex 24); echo "$TOKEN"
echo "MHVTL_CONTROL_API_TOKEN=$TOKEN" >> /etc/mhvtl-control/mhvtl-control.env
chmod 600 /etc/mhvtl-control/mhvtl-control.env
systemctl enable --now mhvtl-control-apply.socket
systemctl enable mhvtl-control-apply-recover.service
systemctl enable --now mhvtl-control mhvtl.target
{% endhighlight %}

O mhVTL Control escuta em `127.0.0.1:8080`, então acesse por um túnel SSH a partir da sua estação de trabalho:

{% highlight shell %}
ssh -L 8080:127.0.0.1:8080 root@pbs.example.com
{% endhighlight %}

Abra <http://localhost:8080>, clique em **Target…** e cole o token.

## Criar a biblioteca {#create-the-library}

O pacote traz duas bibliotecas STK de exemplo. O PBS não consegue vê-las: ele precisa de um changer que informe a página VPD 0x83 do INQUIRY, e os modelos STK que o mhVTL emula não informam. Então adicionamos uma biblioteca com personalidade IBM.

Em **Configuration**, clique em **New library…**:

- **Model:** IBM 03584. O assistente observa que "reports VPD page 83h", que é exatamente o ponto.
- **ID** 20, **serial** `MHV0020`, **4** slots de armazenamento, **2** slots MAP (de correio).
- **Um drive:** IBM ULT3580-TD8, ID 21, serial `MHV002001`.
- **For:** Proxmox Backup Server. Isso liga uma verificação do que o PBS precisa.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m01-new-library.jpg" description="mhVTL Control: assistente New library, IBM 03584 com PBS selecionado" width=1512 height=806 %}

Clique em **Stage library** e depois em **Check**. O Check é uma simulação: valida a nova configuração e lista o que o apply reiniciaria. Aqui são só os dois novos daemons, e a verificação do PBS passa:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m02-check-pbs.jpg" description="Check: a biblioteca 20 atende aos requisitos do PBS, só vtllibrary@20 e vtltape@21 são reiniciados" width=1512 height=806 %}

Clique em **Apply**. A biblioteca fica ativa em poucos segundos.

O assistente deixa a compressão do drive desligada, o que é ótimo: os chunks do PBS já são comprimidos. As bibliotecas de exemplo ficam onde estão (veja [Arestas a aparar](#rough-edges)), então os drives delas vão aparecer mais adiante na lista de drives do PBS.

## Associar o dock {#bind-the-dock}

Este ainda é um passo de shell. Conecte um disco ao dock, encontre o nome estável da porta em `/dev/disk/by-path` (o de `usb-`, não o de `usbv3-`) e associe-o à biblioteca 20. A segunda coluna é o slot de correio pretendido; por enquanto o cartucho cai no primeiro livre:

{% highlight shell %}
ls -l /dev/disk/by-path/ | grep -- -usb-
BAY=/dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0
echo "20  1  $BAY" > /etc/mhvtl/mhvtl_raw_bays.conf
systemctl enable --now mhvtl-bay-monitor
{% endhighlight %}

O disco está em branco, então o monitor registra "not placed" e espera.

## Formatar o disco {#format-the-disk}

Em **Raw Disk Dock**, o disco aparece como "NO MVTL (UNFORMATTED)". Clique em **Format…**, digite o nome do dispositivo para confirmar (isso **apaga o disco**) e dê a ele um código de barras. O sufixo `L8` o torna uma mídia LTO-8, combinando com o drive:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m03-format.jpg" description="Raw Disk Dock: formatar o disco como cartucho USB001L8" width=1512 height=806 %}

O bay monitor detecta o novo cartucho na hora, e o **Library Rack** o mostra em MAP 1. O painel do drive também mostra `encryption aes-gcm`: quando o PBS define uma chave, o mhVTL cifra cada bloco com AES-256-GCM.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-m04-rack-map.jpg" description="Library Rack: USB001L8 no slot de correio" width=1512 height=806 %}

Passe para a interface web do PBS, em `https://<pbs>:8007`.

## Adicionar o changer e o drive {#add-the-changer-and-the-drive}

**Tape Backup → Changers → Add**. O menu de caminhos lista apenas o changer IBM (`scsi-MHV0020`). As amostras STK são invisíveis para o PBS, como esperado. Eu o chamei de `usblib` e deixei Import-Export Slots em branco, já que o PBS os lê do changer.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p01-add-changer.jpg" description="PBS: adicionar o changer" width=1512 height=806 %}

**Drives → Add**: nome `usbdrive`, changer `usblib`, número do drive 0. A lista de caminhos mostra todos os drives do mhVTL, inclusive os de exemplo, então escolha o que tem serial `0MHV002001`:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p02-add-drive.jpg" description="PBS: adicionar o drive, escolhido pelo serial" width=1512 height=806 %}

## Chave de criptografia e media pool {#encryption-key-and-media-pool}

**Encryption Keys → Add**: uma dica e uma senha. O PBS então oferece uma chave em papel. Imprima e guarde longe deste servidor: sem a chave, os discos são só ruído.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p03-add-key.jpg" description="PBS: adicionar uma chave de criptografia de fitas" width=1512 height=806 %}

**Media Pools → Add**:

- **Name:** offsite
- **Allocation:** always. Cada execução inicia um novo media set. Contanto que uma execução caiba em um disco, cada disco é uma cópia autônoma que pode sair do prédio.
- **Retention:** 20 dias. Tem que ser menor que o ciclo de rotação: três discos rotacionados semanalmente voltam depois de 21 dias.
- **Encryption key:** a que você acabou de criar.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p04-add-pool.jpg" description="PBS: media pool offsite" width=1512 height=806 %}

## Etiquetar o disco {#label-the-disk}

Abra o changer (**usblib** na árvore à esquerda). O disco está no slot I/E 5, "Not Labeled". Os slots de correio são numerados depois dos quatro slots de armazenamento. O PBS não etiqueta mídias em um slot de correio, então clique em **Import** e mova-o para o slot 1, depois **Barcode Label** com o pool `offsite`.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p05-changer-ie.jpg" description="Visão do changer no PBS: o novo disco no slot I/E 5" width=1512 height=806 %}

## Fazer o backup {#back-up}

**Content → New Backup**: datastore `store1`, pool `offsite`, drive `usbdrive`, e marque **Export Media-Set**. Isso devolve o cartucho ao slot de correio quando o job termina, pronto para desconectar.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p06-new-backup.jpg" description="PBS: novo backup em fita com Export Media-Set" width=1512 height=806 %}

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p07-backup-log.jpg" description="Log da tarefa: 2148 MB gravados, mídia exportada para o slot I/E 5" width=1512 height=806 %}

Para a rotina semanal, adicione um job em **Backup Jobs → Add**: mesmo datastore, pool e drive, agendamento `sat 02:00`, com Export Media-Set marcado.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p11-backup-job.jpg" description="PBS: job semanal de backup em fita" width=1512 height=806 %}

## Tirar o disco {#pull-the-disk}

Quando o log da tarefa disser que a mídia foi exportada, desconecte o disco. O bay monitor tira o cartucho da biblioteca. O PBS guarda em cache o que sabe, então clique em **Reload** em **Inventory**: o disco aparece como offline, com seu catálogo.

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p08-inventory-offline.jpg" description="Inventário do PBS: USB001L8 offline, catálogo mantido" width=1512 height=806 %}

A visão do changer também continua mostrando o cartucho até você clicar em **Reload** lá.

Na semana que vem: conecte o disco da vez, faça **Import** para um slot de armazenamento e deixe o job rodar. Um disco expirado é reutilizado automaticamente. Formatar e etiquetar é só para discos novos.

## Restaurar {#restore}

Conecte o disco de volta. Quando ele estiver no slot de correio, faça **Reload** do changer e **Import** para um slot. Depois, em **Content**, clique no ícone de restauração ao lado do media set, escolha os snapshots e selecione um drive e um datastore de destino:

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p09-restore-target.jpg" description="Assistente de restauração do PBS: drive e datastore de destino" width=1512 height=806 %}

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p10-restore-log.jpg" description="Log da restauração: o media set foi cifrado com a chave do pool" width=1512 height=806 %}

O log mostra a impressão digital da chave com a qual o media set foi cifrado, e a restauração trouxe 2,148 GB de volta para o datastore. O arquivo aleatório de 2 GiB daquele snapshot voltou com o mesmo SHA-256 do original.

A restauração deixa o disco no drive. Antes de desconectá-lo, mande-o de volta ao slot de correio pela visão do changer. Clique em **Unload** nas ações do drive, o que coloca o cartucho de volta no slot 1. Depois clique em **Transfer** no slot 1 e escolha o slot I/E 5. (O ícone ao lado de Transfer é **Format**. Não confunda os dois.)

{% include image.html url="/assets/img/2026-11-13-pbs-usb-p12-transfer-to-ie.jpg" description="Visão do changer: USB001L8 de volta no slot I/E 5, pronto para desconectar" width=1456 height=818 %}

Restaurar em um PBS reconstruído leva mais alguns passos, começando por recuperar a chave a partir da cópia em papel. A [parte 2](/pt/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#restore) tem os comandos, todos executados em um ambiente de teste.

## Arestas a aparar {#rough-edges}

O mhVTL Control 0.6.0 é jovem, e esta rodada revelou algumas coisas que vou corrigir:

- Bibliotecas de exemplo que guardam cartuchos não podem ser excluídas pelo painel: a exclusão falha na própria verificação. Elas não atrapalham, a não ser por uma lista de drives mais longa no PBS.
- O painel de mídia mostra um erro "Maximum call stack size exceeded".
- O Raw Disk Dock oferece **Format…** para a unidade de CD-ROM, e nomeia os discos por `sdX` em vez de pelo bay.

Nenhuma delas atrapalhou o procedimento. As ressalvas da [parte 2](/pt/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html#caveats) valem aqui também: espere o slot de correio antes de tirar um disco, use um dock que respeite os flushes de cache e teste uma restauração antes de confiar nela.

---

{% include series-nav.html %}
