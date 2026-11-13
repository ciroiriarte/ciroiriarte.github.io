---
title: "Discos USB como fitas para o Proxmox Backup Server (2/3): pela linha de comando"
description: "Passo a passo, pelo shell. Instale o mhVTL, defina uma biblioteca com um dock USB como mail slot, formate discos como cartuchos de fita e execute jobs de fita criptografados do PBS e restaurações neles."
date: 2026-11-13 10:01:00 -0300
permalink: /pt/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html
lang: pt
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 2
series_title: Pela linha de comando
---

Na [parte 1](/pt/datacenter/2026/11/13/pbs-usb-tapes-1-why.html) expliquei por que você pode querer jobs de fita do PBS em simples discos USB. Esta parte monta tudo pelo shell: uma biblioteca virtual, uma unidade LTO-8, um dock USB servindo de mail slot da biblioteca e um media pool criptografado que faz rodízio de discos.

Todos os comandos e saídas abaixo vêm de uma execução em um ambiente de testes novo. Se você prefere clicar, a [parte 3](/pt/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html) faz o mesmo pelas interfaces web.

<!--more-->

{% include series-nav.html %}

## Ponto de partida {#starting-point}

- Proxmox Backup Server 4.2 com um datastore que tenha alguns backups. O meu se chama `store1`.
- Um dock USB ou adaptador USB-SATA, mais os discos que você quiser rotacionar. Um disco é um cartucho.
- mhVTL `1.8.0+git20261101.7e3a101` do meu [projeto no openSUSE Build Service](https://build.opensuse.org/project/show/home:ciriarte:mhvtl). Tudo o que uso aqui está no master do mhVTL, mas ainda não em uma versão com tag, daí o snapshot.

Meu ambiente de testes foi uma VM Debian 13 com o PBS instalado por cima, e o "dock USB" uma porta USB de um controlador xHCI virtual onde conectei a quente discos de 16 GB. O kernel vê eventos reais de hot-plug USB, então o mhVTL não percebe a diferença. Os números de throughput são dessa VM, não são um benchmark.

Os passos assumem um host PBS que ainda não tem mhVTL: eles substituem a configuração de exemplo que o pacote instala. Se você já roda bibliotecas mhVTL nesse host, adicione a biblioteca e a unidade abaixo ao seu próprio `device.conf`.

Execute tudo como root.

## Instalar o mhVTL {#install-mhvtl}

Adicione o repositório e instale o mhVTL. O módulo do kernel é compilado com DKMS, então indique o pacote de headers explicitamente:

{% highlight shell %}
REPO=https://download.opensuse.org/repositories/home:/ciriarte:/mhvtl/Debian_13
install -d /etc/apt/keyrings
curl -fsSL -o /etc/apt/keyrings/mhvtl.asc $REPO/Release.key
echo "deb [signed-by=/etc/apt/keyrings/mhvtl.asc] $REPO/ /" \
    > /etc/apt/sources.list.d/mhvtl.list
apt-get update
# PBS on top of Debian:
apt-get install linux-headers-amd64 mhvtl
# PBS from the ISO (Proxmox kernel), instead:
#apt-get install proxmox-default-headers mhvtl
{% endhighlight %}

**Nota:** Os headers precisam corresponder ao kernel em execução. Se você acabou de atualizar o kernel, reinicie antes, ou o DKMS compila o módulo só para o kernel que você ainda não está usando. Indique também o metapacote de headers: sem ele, o apt puxou os headers do kernel do Proxmox para a minha máquina com kernel Debian para satisfazer o `mhvtl-dkms`.

A instalação ainda não inicia o mhVTL, o que deixa tempo para mais um passo. O driver `ch` do Linux vaza uma referência para cada unidade toda vez que um changer aparece, então uma unidade que o mhVTL remove não pode voltar até um reboot ([corrigido no 7.3-rc7](https://git.kernel.org/torvalds/c/27c0f718d3b3), não está nos kernels atuais do PBS). O PBS conversa com os changers por `/dev/sg*` e não precisa do `ch`, então mantenha-o de fora:

{% highlight shell %}
echo "blacklist ch" > /etc/modprobe.d/mhvtl-no-ch.conf
# if this fails, ch is in use: reboot before going on
modprobe -r ch
{% endhighlight %}

## Definir a biblioteca {#define-the-library}

O pacote traz duas bibliotecas STK de exemplo, e o PBS não enxerga nenhuma das duas. O PBS só lista um changer quando o udev fornece um `ID_SCSI_SERIAL`, que vem da página VPD 0x83 do INQUIRY. O STK L700 e o L80 que o mhVTL emula fielmente não têm isso, então uso uma personalidade IBM TS3500 (`03584L22`), que tem.

Guarde uma cópia dos exemplos e então substitua `/etc/mhvtl/device.conf` por um com uma biblioteca e uma unidade:

{% highlight shell %}
cp -a /etc/mhvtl /root/mhvtl.orig
{% endhighlight %}

**`/etc/mhvtl/device.conf`**

{% highlight text %}
VERSION: 5

Library: 10 CHANNEL: 00 TARGET: 00 LUN: 00
 Vendor identification: IBM
 Product identification: 03584L22
 Unit serial number: USBLIB01
 NAA: 10:22:33:44:ab:00:00:00
 Home directory: /var/lib/mhvtl
 PERSIST: False
 Backoff: 400

Drive: 11 CHANNEL: 00 TARGET: 01 LUN: 00
 Library ID: 10 Slot: 01
 Vendor identification: IBM
 Product identification: ULT3580-TD8
 Product revision level: HB81
 Unit serial number: USBDRV01
 NAA: 10:22:33:44:ab:00:01:00
 Compression: factor 1 enabled 1
 Compression type: lz4
 Backoff: 400
{% endhighlight %}

Não há uma linha `Encryption:` porque AES-256-GCM é o padrão para unidades que o suportam (veja `man device.conf`). Os chunks do PBS já são comprimidos, então o LZ4 é só o codec mais barato para deixar habilitado.

Depois, o conteúdo da biblioteca: quatro slots de armazenamento e dois mail slots, todos vazios. Os discos trazem seus próprios cartuchos.

**`/etc/mhvtl/library_contents.10`**

{% highlight text %}
VERSION: 2

Drive 1:

Picker 1:

MAP 1:
MAP 2:

Slot 1:
Slot 2:
Slot 3:
Slot 4:
{% endhighlight %}

Remova a segunda biblioteca de exemplo e inicie o mhVTL. Um generator do systemd constrói as units `vtllibrary@`/`vtltape@` a partir do `device.conf`, daí o reload:

{% highlight shell %}
rm -f /etc/mhvtl/library_contents.30
systemctl daemon-reload
systemctl restart mhvtl.target
sleep 5; lsscsi -g
{% endhighlight %}

{% highlight text %}
[7:0:0:0]    mediumx IBM      03584L22         0108  /dev/sch0  /dev/sg2
[7:0:1:0]    tape    IBM      ULT3580-TD8      HB81  /dev/st0   /dev/sg3
{% endhighlight %}

Os dispositivos levam alguns segundos para aparecer depois do restart. (Minha execução mostra `/dev/sch0` porque o `ch` ainda não estava na blacklist. Com a blacklist aplicada, essa coluna mostra `-`.)

## Associar o dock a um mail slot {#bind-the-dock-to-a-mail-slot}

O `mhvtl-bay-monitor` associa a localização física de um disco aos mail slots de uma biblioteca. A localização é o nome estável em `/dev/disk/by-path` da porta USB, nunca `/dev/sdX`. Conecte qualquer disco ao dock e procure-o:

{% highlight shell %}
ls -l /dev/disk/by-path/ | grep usb
{% endhighlight %}

{% highlight text %}
pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0 -> ../../sdb
pci-0000:00:01.0-usbv3-0:1:1.0-scsi-0:0:0:0 -> ../../sdb
{% endhighlight %}

Use o nome `usb-` simples. O `usbv3-` carrega a versão do USB que o disco negociou, então um disco que caia para USB 2 apareceria com outro nome. Todo disco conectado a esta porta cai no mesmo bay, que é exatamente o que um rodízio precisa.

Associe-o à biblioteca 10 e inicie o monitor. A segunda coluna é o mail slot pretendido; por enquanto o cartucho cai no primeiro livre, que com um único dock é sempre o mesmo:

{% highlight shell %}
BAY=/dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0
echo "10  1  $BAY" > /etc/mhvtl/mhvtl_raw_bays.conf
systemctl enable --now mhvtl-bay-monitor
journalctl -u mhvtl-bay-monitor -o cat | grep -E 'handle_add|monitoring'
{% endhighlight %}

As linhas de log daqui em diante abreviam o nome by-path para `…usb-0:1:1.0-scsi-0:0:0:0`:

{% highlight text %}
mhvtl-bay-monitor: handle_add(): bay …usb-0:1:1.0-scsi-0:0:0:0 not placed: no readable MVTL cartridge in bay
mhvtl-bay-monitor: main(): monitoring 1 bay(s) for raw-disk hot-plug events
{% endhighlight %}

O disco no dock está em branco, então nada é colocado ainda. Isso é esperado.

## Configurar o PBS {#configure-pbs}

Agora o PBS encontra o changer e a unidade:

{% highlight shell %}
proxmox-tape changer scan
{% endhighlight %}

{% highlight text %}
┌───────────────────────────────┬────────┬──────────┬──────────┐
│ path                          │ vendor │ model    │ serial   │
╞═══════════════════════════════╪════════╪══════════╪══════════╡
│ /dev/tape/by-id/scsi-USBLIB01 │ IBM    │ 03584L22 │ USBLIB01 │
└───────────────────────────────┴────────┴──────────┴──────────┘
{% endhighlight %}

{% highlight shell %}
proxmox-tape drive scan
{% endhighlight %}

{% highlight text %}
┌────────────────────────────────────┬────────┬─────────────┬────────────┐
│ path                               │ vendor │ model       │ serial     │
╞════════════════════════════════════╪════════╪═════════════╪════════════╡
│ /dev/tape/by-id/scsi-00USBDRV01-sg │ IBM    │ ULT3580-TD8 │ 00USBDRV01 │
└────────────────────────────────────┴────────┴─────────────┴────────────┘
{% endhighlight %}

Crie-os:

{% highlight shell %}
proxmox-tape changer create usblib --path /dev/tape/by-id/scsi-USBLIB01
proxmox-tape drive create usbdrive --path /dev/tape/by-id/scsi-00USBDRV01-sg \
    --changer usblib --changer-drivenum 0
{% endhighlight %}

Em seguida, uma chave de criptografia e um media pool que a use. O `key create` pede uma senha. Imprima a chave em papel e guarde-a longe deste servidor: sem a chave, ninguém consegue ler os discos, você inclusive.

{% highlight shell %}
proxmox-tape key create --hint offsite-2026
(umask 077; proxmox-tape key paperkey <fingerprint> --output-format text \
    > /root/offsite-paperkey.txt)
proxmox-tape pool create offsite --allocation always --retention "20 days" \
    --encrypt <fingerprint>
{% endhighlight %}

`--allocation always` inicia um novo media set a cada execução. Enquanto uma execução couber em um disco, cada disco é uma cópia independente que pode sair do prédio. Se não couber, o media set se espalha por vários discos, que viajam (e são restaurados) juntos.

A retenção precisa ser menor que o ciclo de rodízio, ou o disco que volta ainda está protegido e o PBS pede um novo. Com três discos rotacionados semanalmente, um disco volta depois de 21 dias, então 20 dias funciona.

No changer, os mail slots são numerados depois dos slots de armazenamento. Com quatro slots, o dock é o elemento 5:

{% highlight shell %}
proxmox-tape changer status usblib
{% endhighlight %}

{% highlight text %}
│ drive         │        0 │            │             │
│ import-export │        5 │            │             │
│ import-export │        6 │            │             │
│ slot          │        1 │            │             │
...
{% endhighlight %}

## Inicializar um disco {#initialize-a-disk}

Isso é feito uma vez por disco e **apaga tudo o que houver nele**. Formate o disco no dock como cartucho. O sufixo `L8` no código de barras o torna uma mídia LTO-8, igual à unidade, e a capacidade é a que o disco tiver:

{% highlight shell %}
mhvtl-raw-format $BAY --barcode USB001L8
{% endhighlight %}

{% highlight text %}
Formatted …usb-0:1:1.0-scsi-0:0:0:0 as raw cartridge 'USB001L8' (partitions: 100, min record 65536 bytes)
{% endhighlight %}

O monitor percebe sozinho e coloca o cartucho no mail slot:

{% highlight shell %}
journalctl -u mhvtl-bay-monitor -o cat | tail -1
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_add(): placed USB001L8 (library 10 MAP, bay …usb-0:1:1.0-scsi-0:0:0:0)
{% endhighlight %}

O PBS mantém em cache o estado do changer, então peça uma leitura nova:

{% highlight shell %}
proxmox-tape changer status usblib --cache false
{% endhighlight %}

{% highlight text %}
Unit Attention, Additional sense: Import or export element accessed
│ import-export │        5 │ USB001L8   │             │
{% endhighlight %}

O "Unit Attention" é a biblioteca avisando o PBS de que alguém mexeu no mail slot. Uma biblioteca de verdade se comporta assim também.

O PBS não rotula mídias que estão em um mail slot (`changer device does not list any media labels`), então mova-a primeiro para um slot de armazenamento. Depois o `barcode-label` rotula com o código de barras cada cartucho sem rótulo da biblioteca:

{% highlight shell %}
proxmox-tape changer transfer usblib --from 5 --to 1
proxmox-tape barcode-label --drive usbdrive --pool offsite
{% endhighlight %}

{% highlight text %}
checking/loading media 'USB001L8'
Label media 'USB001L8' for pool 'offsite'
TASK OK
{% endhighlight %}

## Executar um backup {#run-a-backup}

`--export-media-set` devolve o cartucho ao mail slot quando o job termina, então o disco está pronto para ser retirado assim que a tarefa acaba:

{% highlight shell %}
proxmox-tape backup store1 offsite --drive usbdrive --export-media-set true
{% endhighlight %}

{% highlight text %}
starting new media set - reason: policy is AlwaysCreate
...
allocated new writable media 'USB001L8'
trying to load media 'USB001L8' into drive 'usbdrive'
found media label USB001L8 (7288ea87-d337-408b-97cf-e3d3f1f2ba9c)
writing new media set label
wrote 547 chunks (2148.01 MB at 84.90 MB/s)
...
exported media 'USB001L8' to import/export slot 5
TASK OK
{% endhighlight %}

Para a rotina semanal, transforme isso em um job:

{% highlight shell %}
proxmox-tape backup-job create weekly-usb --store store1 --pool offsite \
    --drive usbdrive --schedule "sat 02:00" --export-media-set true
{% endhighlight %}

`proxmox-tape backup-job run weekly-usb` o executa sob demanda.

O disco está mesmo criptografado? Procurei nos 16 GB do dispositivo bruto quatro amostras de 32 bytes de um arquivo aleatório daquele backup. Cada amostra apareceu uma vez no datastore do PBS e em lugar nenhum do disco.

## Retirar o disco {#pull-the-disk}

Confirme que o cartucho está no mail slot e então desconecte o disco:

{% highlight shell %}
proxmox-tape changer status usblib --cache false | grep import-export
{% endhighlight %}

{% highlight text %}
│ import-export │        5 │ USB001L8   │             │
{% endhighlight %}

O monitor tira o cartucho da biblioteca:

{% highlight shell %}
journalctl -u mhvtl-bay-monitor -o cat | tail -1
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_remove(): removed USB001L8 (library 10 MAP, bay …usb-0:1:1.0-scsi-0:0:0:0)
{% endhighlight %}

O PBS mantém o disco no inventário como mídia offline, com o seu catálogo:

{% highlight shell %}
proxmox-tape media list
{% endhighlight %}

{% highlight text %}
│ label-text │ pool    │ media-set-name           │ seq-nr │ status │ location │ catalog │
│ USB001L8   │ offsite │ Fri Nov 13 13:09:32 2026 │      0 │ full   │ offline  │      ok │
{% endhighlight %}

Se um backup rodou sem `--export-media-set`, faça você mesmo a exportação antes de retirar o disco:

{% highlight shell %}
proxmox-tape unload --drive usbdrive
proxmox-tape export-media --drive usbdrive USB001L8
{% endhighlight %}

## A rotina semanal {#the-weekly-routine}

Depois que os discos estão inicializados, um rodízio é:

1. Conecte o disco da vez. Ele aparece no mail slot 5.
2. `proxmox-tape changer transfer usblib --from 5 --to 1`
3. Deixe o job rodar. Ele exporta o disco de volta para o slot 5.
4. Desconecte-o e leve-o para fora do local.

Um disco expirado é reutilizado automaticamente pelo pool. `mhvtl-raw-format` e `barcode-label` só são necessários para discos novos. No ambiente de testes, um segundo disco (`USB002L8`) passou pelos mesmos passos, e o job gravou nele sozinho.

## Restauração {#restore}

Conecte o disco de volta, mova-o para um slot de armazenamento e restaure o media set dele em um datastore. O `proxmox-tape media list` mostra o UUID do media set:

{% highlight shell %}
proxmox-tape changer transfer usblib --from 5 --to 1
proxmox-tape media list
MEDIA_SET=68f8efda-3abe-41be-8bb4-8387fa27ebee   # yours, from the list
proxmox-backup-manager datastore create restore1 /srv/restore1
proxmox-tape restore $MEDIA_SET restore1 --drive usbdrive
{% endhighlight %}

{% highlight text %}
Encryption key fingerprint: 05:7c:64:f4:19:93:0d:c8:...
...
restored 2.148 GB (134.69 MB/s)
restore snapshot host/lab-host/2026-11-13T13:01:34Z
TASK OK
{% endhighlight %}

A chave está no key store do PBS, então a restauração não pediu nada. O arquivo aleatório de 2 GiB naquele snapshot voltou com o mesmo SHA-256 do original.

A restauração deixa o disco na unidade. Mande-o de volta ao mail slot antes de desconectar:

{% highlight shell %}
proxmox-tape unload --drive usbdrive
proxmox-tape export-media --drive usbdrive USB001L8
{% endhighlight %}

Em um PBS reconstruído, o key store e o catálogo de mídias não existem mais. Configure o mhVTL e o changer e a unidade do PBS de novo como acima, mas **não formate nem rotule os discos**. Conecte o disco, mova-o para um slot, depois traga a chave de volta a partir da cópia em papel e deixe o PBS ler o disco:

{% highlight shell %}
# asks for the key password:
proxmox-tape key restore --key-file /root/offsite-paperkey.txt
proxmox-tape inventory --drive usbdrive --read-all-labels true
proxmox-tape load-media USB001L8 --drive usbdrive
proxmox-tape catalog --drive usbdrive
{% endhighlight %}

{% highlight text %}
searching for catalog at EOT (moving to EOT)
found catalog at pos 4
successfully restored catalog
TASK OK
{% endhighlight %}

Depois restaure o media set como acima. Testei isso apagando a chave, o pool, o inventário e os catálogos do PBS de testes: a restauração para um novo datastore funcionou e o checksum bateu.

## Ressalvas {#caveats}

- **Não retire um disco carregado.** Eu tentei: enquanto o disco estava fora, a unidade reportou "Medium format corrupted". Depois de reconectá-lo, `proxmox-tape unload` seguido de `proxmox-tape load-media USB001L8 --drive usbdrive` o trouxe de volta, e uma nova varredura completa do catálogo leu os dados normalmente. Mesmo assim, espere pelo mail slot.
- **Bridges USB e flushes.** O mhVTL pede um flush a cada filemark e a cada unload, mas algumas bridges USB-SATA baratas ignoram flushes de cache. Compre um dock UAS decente.
- **Mais docks.** Um segundo dock é mais uma linha em `mhvtl_raw_bays.conf` (reinicie o `mhvtl-bay-monitor` depois). Cada disco cai no primeiro mail slot livre, não necessariamente o da sua linha, então confira o código de barras com `changer status --cache false` antes de mover ou retirar qualquer coisa. Retirar um disco só tira o cartucho dele.
- **A criptografia precisa deste snapshot ou de um mais novo.** Em builds do mhVTL anteriores ao [#328](https://github.com/markh794/mhvtl/pull/328), a criptografia da unidade é simulada e a chave é gravada junto com os dados. Confira o `man device.conf` para a opção `Encryption:`. Se não estiver lá, use a [criptografia do lado do cliente do PBS](https://pbs.proxmox.com/docs/backup-client.html#encryption).
- **Código novo.** Cartuchos de disco bruto são jovens. Teste uma restauração antes de depender deles, como com qualquer backup.

---

{% include series-nav.html %}
