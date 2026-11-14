---
title: "Reduzindo o mirror ZFS da raiz de um Proxmox Backup Server"
description: "Um procedimento de campo para reduzir partições raiz ZFS espelhadas e superdimensionadas no Proxmox Backup Server, reconstruindo um lado do mirror de cada vez e mantendo um fallback inicializável até o fim. Testado com BIOS legado, UEFI com systemd-boot e UEFI com Secure Boot."
lang: pt
date: 2026-11-14 13:00:00 -0300
permalink: /pt/2026/11/14/shrinking-pbs-zfs-root-mirror.html
categories:
  - storage-backup
tags:
  - pbs
  - zfs
---

Depois de instalar o Proxmox Backup Server em um par de SSDs de 200GB com a raiz em um mirror ZFS (`rpool`), percebi que o sistema de arquivos raiz usava menos de 3GB. Eu queria o espaço restante de volta para outro uso, mas o ZFS não permite reduzir vdevs de nível superior nem pools no lugar. Truncar diretamente as partições GPT por baixo é o jeito clássico de corromper um pool.

A abordagem que usei é uma migração gradual do mirror: separar um lado do mirror, criar um pool menor de 50GB nesse disco, replicar o sistema de arquivos raiz para ele, inicializar a partir do novo pool e, por fim, reparticionar e reanexar o segundo disco para restaurar o espelhamento. O disco antigo fica intocado, e inicializável, até que o novo tenha provado que consegue dar boot sozinho.

Tudo roda no sistema em produção; nunca precisei dar boot em uma mídia de resgate. Mesmo assim, tenha uma à mão.

<!--more-->

## Isto se aplica a você? {#does-this-apply-to-you}

Isto foi escrito para, e executado em, uma configuração bem específica. Confira se a sua bate antes de seguir:

- Uma das três configurações de boot que o `proxmox-boot-tool` gerencia. Meu servidor inicializa em BIOS legado com GRUB; o procedimento também funciona em UEFI, com algumas diferenças explicadas abaixo.
- Sem criptografia nativa do ZFS no pool raiz.
- O layout padrão do instalador: raiz em `rpool/ROOT/pbs-1`. Se `findmnt -n -o SOURCE /` mostrar outro dataset, substitua-o em todos os lugares abaixo.
- SSH como root mais acesso ao console fora de banda (iLO, IPMI, serial, crash cart), porque talvez você precise do menu de boot do firmware.

Para ver qual configuração de boot você tem, olhe a primeira linha de `proxmox-boot-tool status` e com o que cada partição de boot está "configured with", e no UEFI verifique o Secure Boot:

{% highlight shell %}
proxmox-boot-tool status
mokutil --sb-state
{% endhighlight %}

| Configuração de boot | `proxmox-boot-tool status` | Boot loader | `INIT_MODE` abaixo |
|---|---|---|---|
| BIOS legado | inicializado com `legacy`, partições `grub` | GRUB | `grub` |
| UEFI | inicializado com `uefi`, partições `uefi` | systemd-boot | vazio |
| UEFI com Secure Boot | inicializado com `uefi`, partições `grub` | GRUB, carregado pelo shim assinado | `grub` |

A parte ZFS do procedimento é a mesma para as três. O que muda no UEFI é como você escolhe qual disco inicializa, e o fato de o firmware manter sua própria lista de entradas de boot, cada uma apontando para uma partição específica, que precisa de uma arrumação depois que os discos são reparticionados. Esses passos estão marcados com **UEFI**.

Depois da primeira execução em hardware real, repeti o procedimento inteiro, exatamente como está escrito aqui, em VMs novas do Proxmox Backup Server 4.2 com raiz em ZFS RAID1: uma com SeaBIOS, uma com UEFI e systemd-boot e uma com UEFI e Secure Boot habilitado. Cada execução cobriu a sincronização base e a incremental, o primeiro boot pelo disco novo, um boot de rollback pelo antigo, a reconstrução do segundo disco e um boot por cada disco com o outro removido; o Secure Boot ficou habilitado o tempo todo. Dois dos passos abaixo, esvaziar cedo a lista de partições de boot e as chamadas a `udevadm settle`, estão lá porque a primeira repetição falhou sem eles.

## Ponto de partida {#starting-point}

O host era um Proxmox Backup Server com um pool raiz ZFS espelhado:

{% highlight text %}
rpool
  mirror-0
    /dev/sda3
    /dev/sdb3
{% endhighlight %}

Os dois discos de boot estavam mais ou menos assim:

{% highlight text %}
/dev/sda1   BIOS boot partition
/dev/sda2   EFI System Partition, used by proxmox-boot-tool with GRUB
/dev/sda3   ZFS member, around 185G

/dev/sdb1   BIOS boot partition
/dev/sdb2   EFI System Partition, used by proxmox-boot-tool with GRUB
/dev/sdb3   ZFS member, around 185G
{% endhighlight %}

O sistema inicializava em modo BIOS legado, mas ainda usava o fluxo do Proxmox boot-tool para gerenciar as partições de boot:

{% highlight shell %}
proxmox-boot-tool status
{% endhighlight %}

O objetivo era deixar as duas partições raiz ZFS com 50GB:

{% highlight text %}
/dev/sda3   50G
/dev/sdb3   50G
{% endhighlight %}

Este procedimento deixa de propósito o pool substituto com o nome `newrpool`. Renomear um pool raiz de volta para `rpool` significa exportá-lo e reimportá-lo a partir de um ambiente offline e atualizar a configuração de boot; isso é outro trabalho, e não vale a pena misturar com a redução. Deixei o nome como está.

## Avisos importantes {#important-warnings}

Isto é destrutivo.

Antes de fazer qualquer coisa assim, garanta que você tem:

- Acesso fora de banda ao console e ao menu de boot do firmware.
- Um destino de backup fora do pool raiz.
- O mapeamento dos discos verificado, pelo número de série, para os dois discos.
- Um backup verificado, não apenas um comando de backup que pareceu ter rodado.
- Familiaridade suficiente com mídia de resgate para recuperar um sistema Proxmox com raiz em ZFS se o boot falhar.

Não instale atualizações enquanto o procedimento estiver em andamento: uma atualização de kernel roda `proxmox-boot-tool refresh` e mexe em todas as partições de boot registradas.

Não cole os comandos às cegas. Ajuste nomes de pool, nomes de dataset e caminhos by-id para o seu sistema, e leia a saída de cada passo antes de rodar o próximo.

## Inspecionar o sistema {#inspect-the-system}

Comece coletando o layout real.

{% highlight shell %}
hostname
cat /etc/os-release
cat /proc/cmdline
findmnt -n -o SOURCE /

lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS

zpool status -v
zpool list -v
zfs list -r -o name,used,avail,refer,mountpoint,canmount rpool

proxmox-boot-tool status
swapon --show

sgdisk -p /dev/sda
sgdisk -p /dev/sdb
{% endhighlight %}

Confirme que a raiz está mesmo em ZFS e que `sda3` e `sdb3` são os membros do vdev raiz espelhado. Verifique também se há datasets extras no pool raiz, swap em um zvol ou propriedades incomuns como `canmount`, `mountpoint`, `quota` ou `refreservation`; a replicação vai preservá-los, mas é melhor encontrar surpresas aqui do que depois do reboot.

Identifique os caminhos estáveis dos discos antes de mexer em qualquer coisa:

{% highlight shell %}
ls -l /dev/disk/by-id/ | grep -E 'sda|sdb'
{% endhighlight %}

Nomes do kernel como `/dev/sda` podem trocar entre um boot e outro, e este procedimento reinicia no meio. Todo comando destrutivo abaixo usa caminhos `/dev/disk/by-id/`, tanto para o ZFS quanto para o `sgdisk`.

## Criar um backup {#create-a-backup}

Usei outro datastore ZFS montado em `/mnt/datastore/backup01` como destino do backup.

{% highlight shell %}
TS=$(date +%Y%m%d-%H%M%S)
BK=/mnt/datastore/backup01/rpool-shrink-$TS
mkdir -p "$BK"
echo "$BK" > /root/.last-rpool-shrink-backup
{% endhighlight %}

Capture o estado atual:

{% highlight shell %}
zpool status -v > "$BK/zpool-status.before.txt"
zpool list -v > "$BK/zpool-list.before.txt"
zfs list -r -o name,used,avail,refer,mountpoint,canmount rpool > "$BK/zfs-list.before.txt"
zfs get -r all rpool > "$BK/zfs-get-all.before.txt"
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,UUID,PARTUUID,PARTTYPE,MOUNTPOINTS > "$BK/lsblk.before.txt"

sgdisk --backup="$BK/sda.gpt" /dev/sda
sgdisk --backup="$BK/sdb.gpt" /dev/sdb

proxmox-boot-tool status > "$BK/proxmox-boot-tool-status.before.txt" 2>&1 || true
proxmox-backup-manager versions > "$BK/proxmox-backup-manager-versions.before.txt" 2>&1 || true
{% endhighlight %}

Crie um backup conservador, em nível de sistema de arquivos, dos caminhos importantes do sistema:

{% highlight shell %}
umask 077

tar --xattrs --acls --one-file-system \
  -czf "$BK/etc-root-boot-varlibpbs.tar.gz" \
  /etc /root /boot /var/lib/proxmox-backup \
  2> "$BK/tar-warnings.txt" || true
{% endhighlight %}

Agora crie o backup por replicação ZFS. O dry run primeiro diz o tamanho do stream recursivo, snapshots incluídos; ele precisa caber com folga no novo pool de 50GB, não só os 3GB da raiz em uso:

{% highlight shell %}
SN="pre-shrink-$TS"
zfs snapshot -r "rpool@$SN"
zfs send -nvR "rpool@$SN" | tail -1

zfs send -R "rpool@$SN" > "$BK/rpool-$SN.zfs"
echo "$SN" > "$BK/base-snapshot-name.txt"
sha256sum "$BK"/* > "$BK/SHA256SUMS"
sync
{% endhighlight %}

Verifique os checksums antes de continuar:

{% highlight shell %}
cd "$BK"
sha256sum -c SHA256SUMS
zfs list -t snapshot -r rpool | grep "$SN"
{% endhighlight %}

Se a verificação dos checksums falhar, pare.

Mais adiante, o novo pool é alimentado a partir deste arquivo, e não direto de `zfs send`. Isso é proposital: o receive também serve como teste de restauração do stream de backup, antes de qualquer coisa que não dê para desfazer.

## Separar um lado do mirror {#detach-one-side-of-the-mirror}

A estratégia é manter a máquina rodando a partir de um lado do mirror antigo enquanto reconstruímos o outro lado como um pool novo e menor.

No meu caso, separei primeiro o lado `sdb`.

Defina as variáveis de acordo com o seu hardware, usando os caminhos by-id de disco inteiro que você identificou antes, e salve-as junto ao backup. O shell as esquece no reboot, e a segunda metade do procedimento precisa delas:

{% highlight shell %}
OLDPOOL=rpool
NEWPOOL=newrpool
BK=$(cat /root/.last-rpool-shrink-backup)

SDA=/dev/disk/by-id/ata-Micron_P400m-MTFDDAK200MAN_MSA173201JY
SDB=/dev/disk/by-id/ata-Micron_P400m-MTFDDAK200MAN_MSA173201MA
SDA3=$SDA-part3
SDB3=$SDB-part3

# grub for legacy BIOS and for UEFI with Secure Boot; empty for UEFI with systemd-boot
INIT_MODE=grub

SN_BASE=$(cat "$BK/base-snapshot-name.txt")
zfs list "$OLDPOOL@$SN_BASE"
ls -l "$BK/rpool-$SN_BASE.zfs"

cat > "$BK/vars.sh" <<EOF
OLDPOOL=$OLDPOOL
NEWPOOL=$NEWPOOL
BK=$BK
SDA=$SDA
SDB=$SDB
SDA3=$SDA3
SDB3=$SDB3
INIT_MODE=$INIT_MODE
SN_BASE=$SN_BASE
EOF
cat "$BK/vars.sh"
{% endhighlight %}

Se o `zfs list` ou o `ls` falhar, pare: o snapshot e o arquivo do stream precisam corresponder. Defina `INIT_MODE` a partir da tabela acima; é a única configuração que depende de como a máquina inicializa.

Separe `sdb3` do pool raiz antigo e confirme que `rpool` agora é um disco único:

{% highlight shell %}
zpool detach "$OLDPOOL" "${SDB3:?}"
zpool status -P "$OLDPOOL"
{% endhighlight %}

O `zpool status` deve listar apenas o caminho de `sda3`. Neste ponto o `rpool` antigo não está mais espelhado. Não deixe faltar energia a menos que tenha certeza de que seu backup e o acesso ao console estão em ordem.

## Reparticionar sdb {#repartition-sdb}

Apague e recrie o layout de partições no disco `sdb`, com a partição 3 de 50GB:

{% highlight shell %}
sgdisk --zap-all "${SDB:?}"
sgdisk -a1 -n1:34:2047 -t1:EF02 "$SDB"
sgdisk -n2:2048:+1G -t2:EF00 "$SDB"
sgdisk -n3:0:+50G -t3:BF01 "$SDB"
partx -u "$SDB"
udevadm settle

sgdisk -v "$SDB"
sgdisk -p "$SDB"
lsblk -o NAME,SIZE,PARTTYPENAME "$SDB"
{% endhighlight %}

A primeira partição é a minúscula partição de boot do BIOS. A segunda é a EFI System Partition usada pelo `proxmox-boot-tool`. A terceira é a nova partição ZFS de 50GB. O `sgdisk -v` não deve reportar problemas e o `lsblk` deve mostrar as três partições com os tamanhos esperados; se não, pare aqui, enquanto o pool antigo ainda está intacto em `sda`.

## Criar o novo pool menor {#create-the-new-smaller-pool}

Crie o novo pool na partição menor `sdb3`:

{% highlight shell %}
zpool create -f \
  -o ashift=12 \
  -O acltype=posixacl \
  -O canmount=off \
  -O compression=on \
  -O normalization=formD \
  -O relatime=on \
  -O xattr=sa \
  -R /mnt/newrpool \
  "$NEWPOOL" "$SDB3"
{% endhighlight %}

O `-R` define uma raiz alternativa, para que nada do novo pool seja montado por cima do sistema em execução. Ele também mantém o novo pool fora do `/etc/zfs/zpool.cache` do sistema em uso; a nova raiz ganha seu próprio arquivo de cache mais adiante.

Receba o snapshot base no novo pool. O `-u` mantém os datasets recebidos desmontados por enquanto:

{% highlight shell %}
zfs receive -u -F -d "$NEWPOOL" < "$BK/rpool-$SN_BASE.zfs"
zfs list -r "$NEWPOOL"
zfs list "$NEWPOOL/ROOT/pbs-1"
{% endhighlight %}

## Sincronização incremental final {#final-incremental-sync}

Antes da sincronização final, garanta que o PBS não está no meio de alguma tarefa e então pare os serviços que escrevem no pool raiz:

{% highlight shell %}
proxmox-backup-manager task list

systemctl stop proxmox-backup-proxy proxmox-backup
systemctl is-active proxmox-backup-proxy proxmox-backup
sync
{% endhighlight %}

Espere primeiro que terminem as tarefas de backup, sync, verify ou garbage collection em andamento. Os dois serviços devem reportar `inactive`; se algum ainda estiver rodando, não tire o snapshot final.

Crie e envie o snapshot incremental final:

{% highlight shell %}
FINAL_SN="shrink-final-$(date +%Y%m%d-%H%M%S)"

zfs snapshot -r "$OLDPOOL@$FINAL_SN"
zfs send -R -I "$OLDPOOL@$SN_BASE" "$OLDPOOL@$FINAL_SN" | zfs receive -u -F -d "$NEWPOOL"

echo "$FINAL_SN" > "$BK/final-snapshot-name.txt"
zfs list -r "$NEWPOOL" > "$BK/newrpool-after-final-recv.txt"
{% endhighlight %}

Defina o dataset de boot e os pontos de montagem, e então monte explicitamente a nova raiz sob a altroot:

{% highlight shell %}
zpool set bootfs="$NEWPOOL/ROOT/pbs-1" "$NEWPOOL"
zfs set mountpoint=/ "$NEWPOOL/ROOT/pbs-1"
zfs set mountpoint="/$NEWPOOL" "$NEWPOOL"
zfs set mountpoint="/$NEWPOOL/ROOT" "$NEWPOOL/ROOT"

findmnt /mnt/newrpool >/dev/null || zfs mount "$NEWPOOL/ROOT/pbs-1"
findmnt -n -o SOURCE /mnt/newrpool
{% endhighlight %}

O último comando precisa imprimir `newrpool/ROOT/pbs-1`. Um simples `test -d /mnt/newrpool/etc` não basta: se o dataset não estiver montado, os próximos passos escreveriam em um diretório vazio na raiz antiga.

## Preparar a nova raiz para o boot {#prepare-the-new-root-to-boot}

Aponte a linha de comando do kernel da nova raiz para `newrpool`. Só muda o valor de `root=ZFS=`; todo o resto da linha de comando do kernel, como um console serial, permanece. O GRUB lê `/etc/default/grub.d/zfs.cfg`; o systemd-boot lê `/etc/kernel/cmdline`. Uma instalação nova tem os dois, qualquer que seja o modo de boot, então os dois recebem a mesma edição e não podem divergir:

{% highlight shell %}
grep -n 'root=ZFS=' /mnt/newrpool/etc/default/grub.d/zfs.cfg /mnt/newrpool/etc/default/grub

sed -i "s|root=ZFS=$OLDPOOL/|root=ZFS=$NEWPOOL/|" /mnt/newrpool/etc/default/grub.d/zfs.cfg
[ -f /mnt/newrpool/etc/kernel/cmdline ] && \
  sed -i "s|root=ZFS=$OLDPOOL/|root=ZFS=$NEWPOOL/|" /mnt/newrpool/etc/kernel/cmdline

grep -rn 'root=ZFS=' /mnt/newrpool/etc/default/grub.d/zfs.cfg /mnt/newrpool/etc/kernel/cmdline 2>/dev/null

# Keep the same ZFS host identity after booting the received root.
cp /etc/hostid /mnt/newrpool/etc/hostid
{% endhighlight %}

O primeiro `grep` mostra onde fica o argumento da raiz no seu sistema; no meu estava em `/etc/default/grub.d/zfs.cfg`, mais `/etc/kernel/cmdline` nas máquinas de teste UEFI. Depois da edição, toda correspondência deve dizer `root=ZFS=newrpool/ROOT/pbs-1`.

Dê à nova raiz um arquivo de cache do ZFS que liste apenas `newrpool`. A cópia que veio no snapshot é a do sistema antigo, e ainda lista `rpool`; inicializar com ela importaria o pool antigo ao lado do novo:

{% highlight shell %}
rm -f /mnt/newrpool/etc/zfs/zpool.cache
zpool set cachefile=/mnt/newrpool/etc/zfs/zpool.cache "$NEWPOOL"
zdb -C -U /mnt/newrpool/etc/zfs/zpool.cache | grep -E "^[^ ]|name:"
{% endhighlight %}

A saída do `zdb` deve mencionar `newrpool` e mais nada.

Faça bind mount dos sistemas de arquivos de runtime para o chroot:

{% highlight shell %}
for d in dev proc sys run; do
  mountpoint -q "/mnt/newrpool/$d" || mount --rbind "/$d" "/mnt/newrpool/$d"
  mount --make-rslave "/mnt/newrpool/$d"
done
{% endhighlight %}

**UEFI:** o bind recursivo de `/sys` também leva `/sys/firmware/efi/efivars` para dentro do chroot. O `proxmox-boot-tool init` precisa dele lá para criar a entrada de boot do firmware para o disco novo; `ls /mnt/newrpool/sys/firmware/efi/efivars | head -1` deve listar algo.

Agora reconstrua o initramfs e configure a partição de boot em `sdb2`. A lista de partições de boot da nova raiz (`/etc/kernel/proxmox-boot-uuids`) também veio no snapshot, então ainda aponta para `sda2`. Esvazie-a primeiro, antes de rodar qualquer coisa no chroot: o `update-initramfs` dispara um `proxmox-boot-tool refresh` pelos seus hooks, e com a lista antiga esse refresh reescreve `sda2` para inicializar `newrpool`. Foi exatamente o que aconteceu na minha primeira execução de teste, e isso elimina silenciosamente o seu caminho de volta.

{% highlight shell %}
ESP_SDB=$(readlink -f "$SDB-part2")
echo "$ESP_SDB"

: > /mnt/newrpool/etc/kernel/proxmox-boot-uuids
chroot /mnt/newrpool update-initramfs -u -k all

chroot /mnt/newrpool proxmox-boot-tool format "$ESP_SDB" --force
udevadm settle
chroot /mnt/newrpool proxmox-boot-tool init "$ESP_SDB" $INIT_MODE

cat /mnt/newrpool/etc/kernel/proxmox-boot-uuids
blkid -s UUID -o value "$ESP_SDB"
{% endhighlight %}

Os dois UUIDs no final precisam ser iguais, e o arquivo deve conter apenas esse. O `udevadm settle` importa: sem ele, o `init` pode ler do udev o UUID antigo da partição antes de o recém-formatado aparecer, registrar esse e depois pular a partição ao copiar os kernels. O `init` já roda um refresh, então não é preciso um `update-grub` ou `refresh` separado. O `$INIT_MODE` fica propositalmente sem aspas, para que, quando estiver vazio, o `init` não receba nenhum argumento de modo.

**UEFI:** no UEFI, o `init` também escreve uma entrada de boot no firmware, e os dois loaders fazem isso de jeitos diferentes. Olhe o resultado, associando entradas a discos pelo UUID da partição:

{% highlight shell %}
blkid -s PARTUUID -o value "$SDA-part2" "$SDB-part2"
efibootmgr -v | grep -E '^Boot(Order|[0-9A-F]{4}\* (Linux Boot Manager|proxmox))'
{% endhighlight %}

- O **systemd-boot** adiciona uma nova entrada "Linux Boot Manager" para `sdb2` e a coloca em primeiro na ordem de boot. A entrada de `sda2` permanece, ao lado de uma obsoleta para o antigo `sdb2`, que não existe mais; essa é removida no final.
- O **GRUB com Secure Boot** mantém uma única entrada chamada "proxmox", e o `init` a move para `sdb2`. O `sda` não perde o caminho de volta: toda partição de boot também recebe uma cópia do loader no caminho de mídia removível, `\EFI\BOOT\BOOTX64.EFI`, que é o que o firmware executa quando você escolhe o próprio disco no menu de boot. Foi assim que meu teste de rollback inicializou o disco antigo.

Verifique se o initramfs incluiu o novo arquivo de cache:

{% highlight shell %}
lsinitramfs /mnt/newrpool/boot/initrd.img-$(uname -r) | grep zpool.cache
{% endhighlight %}

Nada no sistema em execução muda nesta seção. A configuração do GRUB, o arquivo de cache e a lista de partições de boot dele ainda descrevem `rpool`, então `sda` continua sendo um caminho de volta funcional.

Verifique as duas partições de boot: `sdb2` precisa ter um kernel e uma configuração do GRUB apontando para `newrpool`, e `sda2` ainda precisa apontar para `rpool`:

{% highlight shell %}
mkdir -p /mnt/esp
mount "$ESP_SDB" /mnt/esp
find /mnt/esp -name 'vmlinuz-*' -o -name 'initrd.img-*' | sort
grep -rhoa 'root=ZFS=[^ "]*' /mnt/esp | sort | uniq -c
umount /mnt/esp

mount "$(readlink -f "$SDA-part2")" /mnt/esp
grep -rhoa 'root=ZFS=[^ "]*' /mnt/esp | sort | uniq -c
umount /mnt/esp
{% endhighlight %}

O `grep` procura na partição inteira, então encontra a linha de comando do kernel onde quer que o boot loader a guarde: `grub/grub.cfg` no GRUB, `loader/entries/` no systemd-boot. Em `sdb2` você deve ver os arquivos de kernel e initrd e `root=ZFS=newrpool/ROOT/pbs-1`; em `sda2`, `root=ZFS=rpool/ROOT/pbs-1` e nenhuma menção a `newrpool`. O GRUB também adiciona um `root=ZFS=/ROOT/pbs-1` genérico nas duas; isso é normal, e o valor posterior e específico prevalece. Se `sda2` mencionar `newrpool`, ela foi redirecionada: rode `proxmox-boot-tool refresh` no sistema em execução para restaurá-la antes de seguir adiante.

Por fim, desmonte o chroot:

{% highlight shell %}
umount -R /mnt/newrpool
{% endhighlight %}

Não exporto o `newrpool` aqui. Daemons rodando em seus próprios mount namespaces, como `systemd-udevd`, `systemd-logind` e `chronyd`, mantêm cópias das montagens do chroot, e o `zpool export` se recusa com "pool is busy". Não faz diferença: o reboot fecha o pool, e com o mesmo host ID o initramfs o importa sem reclamar.

## Inicializar pelo disco novo {#boot-from-the-new-disk}

O `sda` ainda inicializa o pool antigo. Essa é a ideia: o primeiro boot tem que vir do `sdb` de propósito, senão não prova nada sobre o `sdb`.

Em BIOS legado, o firmware ainda inicializa pelo `sda` por padrão. Reinicie e, pelo console, escolha o disco `sdb` no menu de boot único do BIOS:

{% highlight shell %}
sync
systemctl reboot
{% endhighlight %}

**UEFI:** você não precisa do console para isso. Diga ao firmware qual entrada usar só no próximo boot, a que aponta para `sdb2`:

{% highlight shell %}
P=$(blkid -s PARTUUID -o value "$SDB-part2")
efibootmgr -v | grep -i -- "$P"
N=$(efibootmgr -v | grep -i -- "$P" | sed -nE 's/^Boot([0-9A-F]{4}).*/\1/p' | head -1)
efibootmgr --bootnext "${N:?no boot entry for sdb2}"
sync
systemctl reboot
{% endhighlight %}

Com o systemd-boot a nova entrada já está em primeiro na ordem de boot, então o `--bootnext` só deixa isso explícito. Depois do reboot, `efibootmgr | grep BootCurrent` diz qual entrada o firmware realmente usou. Nem todo firmware trata as entradas de boot do mesmo jeito: o firmware das minhas VMs de teste reordenava a ordem de boot para seguir a ordem dos discos da VM, então um reboot simples voltava para o `sda`. Confie no `BootCurrent` e no `findmnt`, não na ordem que você esperava.

Quando o host voltar, verifique se a raiz agora está montada a partir do `newrpool`:

{% highlight shell %}
cat /proc/cmdline
findmnt -n -o SOURCE /
zpool status -v newrpool
zpool list -v newrpool
{% endhighlight %}

Resultado esperado:

{% highlight text %}
root=ZFS=newrpool/ROOT/pbs-1
newrpool/ROOT/pbs-1
newrpool  49.5G  ONLINE
{% endhighlight %}

Se você caiu no `rpool`, o firmware inicializou pelo `sda`. Reinicie e escolha o `sdb` de novo. Se o `sdb` não inicializar de jeito nenhum, inicialize pelo `sda`: você está de volta ao sistema original, e nada foi perdido. No UEFI isso significa a entrada "Linux Boot Manager" de `sda2` (systemd-boot) ou o próprio disco `sda` no menu de boot do firmware (Secure Boot).

Não continue até que o sistema de arquivos raiz em uso esteja no `newrpool`, inicializado pelo `sdb`.

## Aposentar o pool antigo {#retire-the-old-pool}

As variáveis do shell se perderam com o reboot. Carregue-as de volta e confirme que nenhuma voltou vazia:

{% highlight shell %}
BK=$(cat /root/.last-rpool-shrink-backup)
. "$BK/vars.sh"
echo "${OLDPOOL:?} ${NEWPOOL:?} ${SDA:?} ${SDA3:?} ${SDB:?} ${SDB3:?}"
{% endhighlight %}

O `/root` aqui é a cópia que veio com o snapshot final, então ele tem o ponteiro para o diretório de backup.

Agora prove que o disco prestes a ser apagado não é aquele de onde você está rodando. O novo pool precisa conter o caminho do `sdb` e não pode conter o do `sda`:

{% highlight shell %}
zpool status -P "$NEWPOOL"
zpool status -P "$NEWPOOL" | grep -F -- "$SDB3"
zpool status -P "$NEWPOOL" | grep -F -- "$SDA" && echo "STOP: sda is part of $NEWPOOL"
{% endhighlight %}

O segundo comando precisa imprimir a linha de `sdb3`; o terceiro não deve imprimir nada.

Depois confirme que o pool antigo não está importado e que nada está usando o disco antigo:

{% highlight shell %}
zpool list
zpool export "$OLDPOOL"
lsblk -o NAME,PATH,FSTYPE,MOUNTPOINTS "$SDA"
{% endhighlight %}

Se o `rpool` aparecer no `zpool list`, o export precisa dar certo. Se ele não exportar, ou se algo em `sda` estiver montado, pare e descubra por quê. Com o novo arquivo de cache, o `rpool` normalmente nem é importado no boot, e o export só informa que o pool não existe.

## Reparticionar sda e reanexá-lo {#repartition-sda-and-reattach-it}

O sistema está rodando a partir do novo pool de 50GB em `sdb3`, e o pool antigo está fechado. Até este ponto, inicializar o `sda` pelo menu do BIOS ainda traria de volta o sistema original. O próximo comando acaba com isso.

Limpe o label ZFS antigo, sem esconder erros:

{% highlight shell %}
zpool labelclear -f "$SDA3"
{% endhighlight %}

Se isso falhar porque o dispositivo está em uso, volte ao passo anterior; algo ainda está com o pool antigo aberto.

Reparticione o disco `sda`:

{% highlight shell %}
sgdisk --zap-all "$SDA"
sgdisk -a1 -n1:34:2047 -t1:EF02 "$SDA"
sgdisk -n2:2048:+1G -t2:EF00 "$SDA"
sgdisk -n3:0:+50G -t3:BF01 "$SDA"
partx -u "$SDA"
udevadm settle

sgdisk -v "$SDA"
sgdisk -p "$SDA"
lsblk -o NAME,SIZE,PARTTYPENAME "$SDA"
{% endhighlight %}

Anexe o novo `sda3` como o segundo lado do mirror:

{% highlight shell %}
zpool attach -f "$NEWPOOL" "$SDB3" "$SDA3"
{% endhighlight %}

Acompanhe o resilver:

{% highlight shell %}
watch -n 5 zpool status "$NEWPOOL"
{% endhighlight %}

Espere até o resilver terminar.

## Recriar a partição de boot do sda {#recreate-the-sda-boot-partition}

Quando `sda3` já fizer parte do mirror, recrie a partição de boot em `sda2` e registre-a. O `proxmox-boot-tool clean` remove da lista qualquer UUID cuja partição não exista mais:

{% highlight shell %}
ESP_SDA=$(readlink -f "$SDA-part2")
echo "$ESP_SDA"

proxmox-boot-tool format "$ESP_SDA" --force
udevadm settle
proxmox-boot-tool init "$ESP_SDA" $INIT_MODE
proxmox-boot-tool clean
proxmox-boot-tool refresh
proxmox-boot-tool status
{% endhighlight %}

O `proxmox-boot-tool status` deve listar duas partições, uma em cada disco, ambas configuradas do mesmo jeito (`grub` ou `uefi`). Se listar apenas uma, o `init` registrou um UUID obsoleto (a mesma condição de corrida do udev que em `sdb2`) e o `clean` o descartou: rode `udevadm settle` e depois `init` e `refresh` de novo.

**UEFI:** o reparticionamento deu a `sda2` um novo UUID de partição, então a entrada do firmware para o antigo `sda2` agora não aponta para nada, e com o systemd-boot o mesmo vale para a do `sdb2` original. Remova toda entrada de boot desses loaders cujo UUID de partição não seja o de uma das duas partições de boot atuais:

{% highlight shell %}
KEEP="$(blkid -s PARTUUID -o value "$SDA-part2" "$SDB-part2")"
echo "$KEEP"
efibootmgr -v | grep -E '^Boot[0-9A-F]{4}\* (Linux Boot Manager|proxmox)' |
while read -r line; do
  n=${line:4:4}
  u=$(echo "$line" | grep -oiE 'GPT,[0-9a-f-]{36}' | cut -d, -f2)
  echo "$KEEP" | grep -qi -- "$u" || { echo "removing stale Boot$n ($u)"; efibootmgr -q -b "$n" -B; }
done
efibootmgr -v | grep -E '^Boot(Order|[0-9A-F]{4}\* (Linux Boot Manager|proxmox))'
{% endhighlight %}

O `echo "$KEEP"` precisa imprimir dois UUIDs antes de você confiar no loop; se imprimir menos, não o execute. O loop só olha entradas chamadas "Linux Boot Manager" ou "proxmox", e deixa em paz as entradas de outros sistemas operacionais e as do próprio firmware.

O que sobra depende do loader. Com o systemd-boot, você fica com uma entrada "Linux Boot Manager" por disco. Com o GRUB com Secure Boot, o `init` moveu a única entrada "proxmox" para `sda2`, e o `sdb` inicializa pela sua cópia de mídia removível, exatamente como em uma instalação nova. Se preferir ter uma entrada com nome para cada disco, adicione uma para o `sdb`:

{% highlight shell %}
efibootmgr -c -d "$SDB" -p 2 -L "proxmox (sdb)" -l '\EFI\proxmox\shimx64.efi'
{% endhighlight %}

Alguns firmwares, incluindo o das minhas VMs de teste, apagam silenciosamente as entradas de boot de discos ausentes no boot. Se uma entrada sumir depois dos testes com um único disco descritos abaixo, o `proxmox-boot-tool reinit` as recoloca: com o systemd-boot ele recria uma entrada por partição de boot; com Secure Boot ele volta a apontar "proxmox" para a última partição da lista.

> **Nota de campo: `mkfs.vfat` travado em `sda2`**
>
> Em uma execução, o `mkfs.vfat` ficou preso em I/O ininterruptível enquanto formatava `sda2`. O resilver do ZFS ainda terminou com sucesso, mas o formatador não retornou. Essa execução ainda não exportava o pool antigo nem verificava a limpeza do label, então a causa mais provável é que o `rpool` ainda estava importado quando seu disco foi reparticionado. É por isso que o procedimento agora aposenta explicitamente o pool antigo antes. As verificações úteis foram:

{% highlight shell %}
ps -o pid,ppid,stat,wchan:32,cmd -C mkfs.vfat
zpool status newrpool
zpool list
dmesg | tail -100
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$SDA" "$SDB"
{% endhighlight %}

Se isso acontecer, primeiro confirme que o sistema está rodando a partir do `newrpool`, que `sdb2` já é inicializável e que o mirror ZFS está saudável, ou pelo menos que você entende o estado dele. Depois reinicie e repita o passo do `proxmox-boot-tool` para `sda2`.

## Scrub e verificação final {#scrub-and-final-verification}

Zere os contadores transitórios e rode um scrub:

{% highlight shell %}
zpool clear "$NEWPOOL"
zpool scrub "$NEWPOOL"

while zpool status "$NEWPOOL" | grep -q "scrub in progress"; do
  zpool status "$NEWPOOL"
  sleep 5
done
{% endhighlight %}

Verificações finais:

{% highlight shell %}
cat /proc/cmdline
findmnt -n -o SOURCE /

zpool status -v "$NEWPOOL"
zpool list -v "$NEWPOOL"

proxmox-boot-tool status
efibootmgr -v    # UEFI only

systemctl is-active proxmox-backup proxmox-backup-proxy ssh

sgdisk -p "$SDA"
sgdisk -p "$SDB"
{% endhighlight %}

O estado final deve ficar assim:

{% highlight text %}
/ mounted from newrpool/ROOT/pbs-1

newrpool ONLINE
  mirror-0 ONLINE
    sdb3 50G ONLINE
    sda3 50G ONLINE

/dev/sda3 50.0 GiB BF01
/dev/sdb3 50.0 GiB BF01

proxmox-backup active
proxmox-backup-proxy active
ssh active
{% endhighlight %}

Um pool espelhado não é a mesma coisa que um boot espelhado. O último teste é inicializar por cada disco sozinho: reinicie, escolha o `sda` no menu de boot do firmware (ou com `efibootmgr --bootnext`), rode as verificações acima; reinicie de novo, escolha o `sdb` e repita. Desconectar fisicamente o outro disco é um teste mais forte, se você puder; foi o que fiz nas VMs de teste. Se os dois caírem em `newrpool/ROOT/pbs-1`, qualquer um dos discos pode morrer sem derrubar o servidor junto. Até lá, a migração não terminou.

## Notas de rollback {#rollback-notes}

O diretório de backup contém:

- Backups da GPT dos dois discos.
- Listagens de propriedades e datasets do ZFS.
- Um stream recursivo de ZFS send do `rpool` original, mais o nome do seu snapshot.
- Um tarball com a configuração importante do sistema.
- As variáveis salvas para a segunda metade do procedimento.
- Checksums dos artefatos.

Como fazer o rollback depende de até onde você chegou:

- **Antes do `zpool labelclear` em `sda3`:** o sistema original está intacto no `sda`. O pool, a partição de boot, a configuração do GRUB e o arquivo de cache dele nunca foram tocados. Escolha o `sda` no menu de boot do firmware e ele inicializa o `rpool` como antes. Qualquer coisa escrita depois do snapshot final existe só no `newrpool`, mas com os serviços do PBS parados para a sincronização, isso deve ser praticamente nada.
- **Depois de o `sda` ter sido reparticionado:** os dois discos são novos. Se o `newrpool` estiver quebrado nesse ponto, a recuperação significa inicializar uma mídia de resgate, criar um pool adequado, receber o stream ZFS salvo e reinstalar o boot loader.

O importante não são os comandos exatos. O importante é a ordem:

1. Verificar o layout.
2. Criar e verificar o backup.
3. Reconstruir um lado do mirror como um pool menor.
4. Replicar a raiz.
5. Inicializar pelo disco novo, escolhido de propósito.
6. Aposentar o pool antigo, depois destruir e reanexar o outro lado do mirror.
7. Fazer scrub e depois inicializar por cada disco sozinho.
