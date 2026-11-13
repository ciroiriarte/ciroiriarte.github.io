---
title: "Discos USB como fitas para o Proxmox Backup Server (1/3): por quê, e o que há de novo"
description: "Por que você pode querer tape jobs do PBS em discos USB comuns, o que o mhVTL ganhou para tornar isso possível (cartuchos em disco raw, baias hot-plug, criptografia real na unidade) e para onde ele está indo."
date: 2026-11-13 10:00:00 -0300
permalink: /pt/datacenter/2026/11/13/pbs-usb-tapes-1-why.html
lang: pt
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 1
series_title: "Por quê, e o que há de novo"
---

Um datastore do Proxmox Backup Server é armazenamento online. É rápido, deduplicado e está sempre online. Esse é o problema: quem conseguir root no host PBS, ou um token com privilégios suficientes, também consegue chegar a ele. A cópia que precisa sobreviver a um ransomware, a um `rm` digitado com os dedos gordos ou a um incêndio deveria ficar numa prateleira, desconectada, de preferência em outro prédio.

A resposta clássica é a fita, e o PBS tem um suporte muito bom a fitas. Mas uma unidade LTO custa mais do que muitos sites pequenos gastam com o servidor de backup inteiro. Um punhado de discos USB não custa quase nada, e alguém pode levá-los para casa na sexta-feira.

Então a ideia desta série é simples: **fazer discos USB se comportarem como fitas**, e deixar o PBS fazer com as fitas o que ele já faz bem.

<!--more-->

Esta é a parte 1 de uma série de três:

1. **Por quê, e o que há de novo** (este post): o raciocínio, e o que há de novo no mhVTL para tornar isso possível.
2. [O procedimento via CLI](/pt/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html): mhVTL e PBS pelo shell, para copiar e colar.
3. [O procedimento point & click](/pt/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html): a mesma coisa, pelo dashboard do mhVTL Control e pela interface web do PBS.

## O que o PBS já oferece {#what-pbs-already-offers}

Antes de construir qualquer coisa, vale a pena conferir o que o PBS já oferece.

**Os clientes nunca escrevem diretamente em fita.** O PVE e o `proxmox-backup-client` sempre fazem backup para um datastore. Depois, um job de backup em fita copia snapshots do datastore para um *media pool* ([documentação do PBS, Tape Backup](https://pbs.proxmox.com/docs/tape-backup.html)). Isso combina com o plano: o datastore continua sendo a primeira cópia, rápida, e os discos viram a segunda cópia, offline.

Para tirar uma cópia do datastore, o PBS tem três opções:

- Os **sync jobs** copiam snapshots entre datastores, localmente ou para um PBS remoto (pull, e push desde o PBS 3.3).
- Os **removable datastores** (desde o [PBS 3.3](https://www.proxmox.com/en/about/company-details/press-releases/proxmox-backup-server-3-3)) colocam um datastore inteiro num disco USB formatado com ext4 ou XFS. Você conecta, sincroniza para ele e desmonta ([documentação do PBS, Removable Datastores](https://pbs.proxmox.com/docs/storage.html)).
- Os **tape backup jobs** escrevem snapshots em *media sets*, com políticas de alocação e retenção, um catálogo do que há em cada fita e criptografia na unidade.

Para um ou dois discos, um removable datastore é mais simples, e provavelmente a melhor resposta. A semântica de fita começa a compensar quando você rotaciona vários discos e quer que o PBS controle isso:

| | Removable datastore | Tape job num disco raw do mhVTL |
|---|---|---|
| Software extra | Nenhum | mhVTL (módulo do kernel e daemons) |
| Formato no disco | ext4/XFS com um chunk store | Sem filesystem, uma imagem sequencial de fita |
| Cópia | Incremental: um sync copia só os chunks novos | Cópia completa por media set (com `--allocation always`) |
| Maior que um disco | Não | Um media set pode abranger vários discos |
| Retirada do disco | Desmontagem limpa, ou o datastore fica em modo de manutenção | Cartucho exportado para o mail slot, dados já gravados no disco |
| Rotação de N discos | Na mão | Media pool com políticas de alocação e retenção |
| O que há no disco da gaveta? | Conecte e olhe | O PBS mantém um catálogo das mídias offline |
| Criptografia | No lado do cliente | No lado do cliente, ou a chave do pool ([AES-256-GCM na unidade](#real-encryption)) |
| Restauração | Navegar e restaurar diretamente | Primeiro restaurar o media set para um datastore |
| Outros softwares de backup | Só o PBS | Qualquer um que fale com uma biblioteca de fitas |
| Migrar para LTO de verdade depois | Começar do zero | Mesmos pools e jobs, troca-se o hardware |

Dois pequenos bônus do disco raw: nenhum componente de desktop tenta montá-lo automaticamente, e um disco retirado na hora errada não tem filesystem para rodar `fsck`.

## O que mudou no mhVTL {#what-changed-in-mhvtl}

O [mhVTL](https://github.com/markh794/mhvtl) é uma biblioteca de fitas virtual para Linux. Ele emula unidades de fita SCSI e changers robóticos bem o bastante para que as aplicações de backup não percebam a diferença. Tradicionalmente, cada cartucho virtual é um diretório de arquivos em `/opt/mhvtl`. Isso serve para testes, mas um cartucho preso dentro de um filesystem no servidor de backup não ajuda ninguém quando o prédio pega fogo.

Nas últimas semanas, um conjunto de mudanças chegou ao upstream permitindo que os cartuchos vivam em discos removíveis. Fui eu que as escrevi; Mark Harvey, o mantenedor do mhVTL, as revisou e integrou.

### Cartuchos em disco raw {#raw-disk-cartridges}

Agora um dispositivo de bloco inteiro pode ser um cartucho ([#214](https://github.com/markh794/mhvtl/pull/214)). Um disco é uma fita. Sem tabela de partições e sem filesystem.

O primeiro megabyte é deixado vazio, para que nada no host ache que o disco vale a pena ser montado. Depois vêm um superbloco (mais uma cópia espelhada) com o código de barras e o layout, a memória do cartucho (MAM) e o fluxo de dados.

O `mhvtl-raw-format` inicializa um disco e, desde o [#293](https://github.com/markh794/mhvtl/pull/293), também grava uma MAM correta, para que a unidade saiba a capacidade desde a primeira escrita.

Quando uma aplicação de backup escreve um filemark ou descarrega a fita, o mhVTL faz flush do disco (`fdatasync`) antes de responder. Num ambiente de teste, discos retirados do mail slot e reconectados foram lidos intactos todas as vezes.

### Baias hot-plug {#hot-plug-bays}

O `mhvtl-bay-monitor` observa o udev e associa uma porta USB física (o nome estável dela em `/dev/disk/by-path`, nunca `/dev/sdX`) aos mail slots de uma biblioteca. Mail slots são a estação de importação/exportação de uma biblioteca: o mhVTL os chama de MAP, o PBS os chama de slots I/E.

Você conecta um disco formatado ao dock e o cartucho dele aparece num mail slot. Retira o disco e o cartucho some da biblioteca. Mudanças posteriores tratam os casos de borda:

- um disco formatado no lugar ([#294](https://github.com/markh794/mhvtl/pull/294))
- um monitor reiniciado com um disco no dock ([#296](https://github.com/markh794/mhvtl/pull/296))
- vários docks numa mesma biblioteca ([#298](https://github.com/markh794/mhvtl/pull/298))

Para o PBS, isso parece exatamente um operador chegando a uma biblioteca de verdade e colocando uma fita no mail slot.

### Criptografia de verdade {#real-encryption}

Até pouco tempo atrás, a criptografia de unidade do mhVTL era *simulada*. A unidade aceitava a chave e gravava os dados em texto puro, com a chave no cabeçalho de cada bloco. Serve para testar uma aplicação, mas é inútil para discos que saem do prédio.

Desde o [#328](https://github.com/markh794/mhvtl/pull/328), a unidade criptografa cada bloco com AES-256-GCM. A chave é derivada do que a aplicação envia mais um salt aleatório guardado na memória do cartucho, e nunca é gravada no disco.

Esse é o padrão para as unidades que suportam criptografia, então um media pool do PBS com uma chave de criptografia agora te dá um disco criptografado. Num ambiente de teste, procurei no disco raw amostras de um arquivo aleatório que eu tinha copiado: estavam todas no datastore do PBS, e nenhuma no disco criptografado.

### Compressão mais rápida {#faster-compression}

LZ4 e Zstandard se juntaram aos antigos zlib e LZO. Não faz muita diferença para o PBS, cujos chunks já vêm comprimidos, e o mhVTL guarda um bloco como está quando a compressão não o reduz.

### Um dashboard {#a-dashboard}

O [mhVTL Control](https://github.com/ciroiriarte/mhvtl-control) é um projeto meu à parte: uma API REST e um dashboard web para o mhVTL. Mostra as bibliotecas ao vivo, edita a configuração com uma etapa de verificação antes de aplicar e formata discos raw. A parte 3 o usa para a versão point & click.

## Para onde isso vai {#where-this-is-going}

Nesta série, o dock USB fica pendurado no próprio host PBS. O próximo passo é mover os discos para uma máquina separada.

O mhVTL agora consegue exportar suas bibliotecas por **iSCSI**: o `mhvtl-fabrics` ([#337](https://github.com/markh794/mhvtl/pull/337)) provisiona os targets em cima do backend TCMU, que ainda é experimental. O suporte a target **Fibre Channel** também está a caminho. Com qualquer um dos dois, uma máquina separada com baias hot-swap vira "a biblioteca de fitas", e o host PBS enxerga uma biblioteca de fitas comum na fabric. Sem mhVTL no servidor de backup, sem cabo USB até ele, e com os discos rotacionados na máquina que os abriga.

Isso merece um post só dele depois de passar por um ambiente de teste. Por ora, a [parte 2](/pt/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html) monta a versão local pelo shell.

---

{% include series-nav.html %}
