---
title: "Shrinking a Proxmox Backup Server ZFS root mirror"
description: "A field procedure for shrinking oversized mirrored ZFS root partitions on Proxmox Backup Server, rebuilding one mirror leg at a time and keeping a bootable fallback until the end. Tested with legacy BIOS, UEFI with systemd-boot, and UEFI with Secure Boot."
author: Ciro Iriarte
lang: en
date: 2026-11-14 13:00:00 -0300
categories:
  - storage-backup
tags:
  - pbs
  - zfs
---

After installing Proxmox Backup Server on a pair of 200GB SSDs with a ZFS root mirror (`rpool`), I realized the root filesystem used less than 3GB. I wanted the remaining space back for another use, but ZFS does not support shrinking top-level vdevs or pools in place. Truncating the underlying GPT partitions directly is how pools get corrupted.

The approach I used is a rolling mirror migration: detach one side of the mirror, build a smaller 50GB pool on that disk, replicate the root filesystem over, boot from the new pool, and finally repartition and reattach the second disk to restore mirroring. The old disk stays untouched, and bootable, until the new one has proven it can boot on its own.

The whole thing runs on the live system; I never had to boot rescue media. Have it ready anyway.

<!--more-->

## Does this apply to you?

This was written for, and run on, a fairly specific setup. Check yours matches before going further:

- One of the three boot setups `proxmox-boot-tool` manages. My server boots legacy BIOS with GRUB; the procedure also works on UEFI, with a few differences covered below.
- No ZFS native encryption on the root pool.
- The default installer layout: root on `rpool/ROOT/pbs-1`. If `findmnt -n -o SOURCE /` shows a different dataset, substitute it everywhere below.
- Root SSH plus out-of-band console access (iLO, IPMI, serial, crash cart), because you may need the firmware boot menu.

To see which boot setup you have, look at the first line of `proxmox-boot-tool status` and at what each boot partition is "configured with", and on UEFI check Secure Boot:

{% highlight shell %}
proxmox-boot-tool status
mokutil --sb-state
{% endhighlight %}

| Boot setup | `proxmox-boot-tool status` | Boot loader | `INIT_MODE` below |
|---|---|---|---|
| Legacy BIOS | booted with `legacy`, partitions `grub` | GRUB | `grub` |
| UEFI | booted with `uefi`, partitions `uefi` | systemd-boot | empty |
| UEFI with Secure Boot | booted with `uefi`, partitions `grub` | GRUB, loaded by the signed shim | `grub` |

The ZFS part of the procedure is the same for all three. What changes on UEFI is how you choose which disk boots, and that the firmware keeps its own list of boot entries, each one pointing at a specific partition, which needs some tidying after the disks are repartitioned. Those steps are marked **UEFI**.

After the first run on real hardware, I replayed the whole procedure, as written here, on fresh Proxmox Backup Server 4.2 VMs with a ZFS RAID1 root: one on SeaBIOS, one on UEFI with systemd-boot and one on UEFI with Secure Boot enabled. Each run covered the base and incremental sync, the first boot from the new disk, a rollback boot from the old one, the rebuild of the second disk, and a boot from each disk with the other one removed; Secure Boot stayed enabled throughout. Two of the steps below, emptying the boot partition list early and the `udevadm settle` calls, are there because the first replay failed without them.

## Starting point

The host was a Proxmox Backup Server with a mirrored ZFS root pool:

{% highlight text %}
rpool
  mirror-0
    /dev/sda3
    /dev/sdb3
{% endhighlight %}

The two boot disks looked roughly like this:

{% highlight text %}
/dev/sda1   BIOS boot partition
/dev/sda2   EFI System Partition, used by proxmox-boot-tool with GRUB
/dev/sda3   ZFS member, around 185G

/dev/sdb1   BIOS boot partition
/dev/sdb2   EFI System Partition, used by proxmox-boot-tool with GRUB
/dev/sdb3   ZFS member, around 185G
{% endhighlight %}

The system was booted in legacy BIOS mode, but still used the Proxmox boot-tool workflow to manage the boot partitions:

{% highlight shell %}
proxmox-boot-tool status
{% endhighlight %}

The target was to make both ZFS root partitions 50GB:

{% highlight text %}
/dev/sda3   50G
/dev/sdb3   50G
{% endhighlight %}

This procedure intentionally leaves the replacement pool named `newrpool`. Renaming a root pool back to `rpool` means exporting and re-importing it from an offline environment and refreshing the boot configuration; that's a separate job, and not worth mixing into the shrink. I left the name as-is.

## Important warnings

This is destructive.

Before doing anything like this, make sure you have:

- Out-of-band access to the console and the firmware boot menu.
- A backup destination outside the root pool.
- Verified disk mapping, by serial number, for both disks.
- A verified backup, not just a backup command that appeared to run.
- Enough comfort with rescue media to recover a Proxmox ZFS root system if booting fails.

Don't install updates while the procedure is in progress: a kernel update runs `proxmox-boot-tool refresh` and touches every registered boot partition.

Do not blindly paste the commands. Adjust pool names, dataset names and by-id paths for your system, and read the output of each step before running the next.

## Inspect the system

Start by collecting the actual layout.

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

Confirm that root is really on ZFS and that `sda3` and `sdb3` are the mirrored root vdev members. Also check for extra root-pool datasets, swap on a zvol, or unusual properties such as `canmount`, `mountpoint`, `quota`, or `refreservation`; replication will preserve them, but surprises here are better found before the reboot.

Identify the stable disk paths before touching anything:

{% highlight shell %}
ls -l /dev/disk/by-id/ | grep -E 'sda|sdb'
{% endhighlight %}

Kernel names like `/dev/sda` can swap between boots, and this procedure reboots in the middle. Every destructive command below uses `/dev/disk/by-id/` paths, for ZFS and for `sgdisk`.

## Create a backup

I used another ZFS datastore mounted at `/mnt/datastore/backup01` as the backup target.

{% highlight shell %}
TS=$(date +%Y%m%d-%H%M%S)
BK=/mnt/datastore/backup01/rpool-shrink-$TS
mkdir -p "$BK"
echo "$BK" > /root/.last-rpool-shrink-backup
{% endhighlight %}

Capture the current state:

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

Create a conservative filesystem-level backup of important system paths:

{% highlight shell %}
umask 077

tar --xattrs --acls --one-file-system \
  -czf "$BK/etc-root-boot-varlibpbs.tar.gz" \
  /etc /root /boot /var/lib/proxmox-backup \
  2> "$BK/tar-warnings.txt" || true
{% endhighlight %}

Now create the ZFS replication backup. The dry run first tells you how big the recursive stream is, snapshots included; it has to fit comfortably in the new 50GB pool, not just the live root's 3GB:

{% highlight shell %}
SN="pre-shrink-$TS"
zfs snapshot -r "rpool@$SN"
zfs send -nvR "rpool@$SN" | tail -1

zfs send -R "rpool@$SN" > "$BK/rpool-$SN.zfs"
echo "$SN" > "$BK/base-snapshot-name.txt"
sha256sum "$BK"/* > "$BK/SHA256SUMS"
sync
{% endhighlight %}

Verify the checksums before continuing:

{% highlight shell %}
cd "$BK"
sha256sum -c SHA256SUMS
zfs list -t snapshot -r rpool | grep "$SN"
{% endhighlight %}

If checksum verification fails, stop.

Later on, the new pool is seeded from this file rather than straight from `zfs send`. That's deliberate: the receive doubles as a restore test of the backup stream, before anything you can't undo.

## Detach one side of the mirror

The strategy is to keep the machine running from one side of the old mirror while we rebuild the other side as a new, smaller pool.

In my case I detached the `sdb` side first.

Set variables matching your hardware, using the whole-disk by-id paths you identified earlier, and save them next to the backup. The shell forgets them at the reboot, and the second half of the procedure needs them:

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

If either `zfs list` or `ls` fails, stop: the snapshot and the stream file must match. Set `INIT_MODE` from the table above; it's the only setting that depends on how the machine boots.

Detach `sdb3` from the old root pool and confirm `rpool` is now a single disk:

{% highlight shell %}
zpool detach "$OLDPOOL" "${SDB3:?}"
zpool status -P "$OLDPOOL"
{% endhighlight %}

`zpool status` should list only the `sda3` path. At this point the old `rpool` is no longer mirrored. Do not lose power unless you are sure your backup and console access are good.

## Repartition sdb

Wipe and recreate the partition layout on the `sdb` disk, with partition 3 set to 50GB:

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

The first partition is the tiny BIOS boot partition. The second is the EFI System Partition used by `proxmox-boot-tool`. The third is the new 50GB ZFS partition. `sgdisk -v` should report no problems and `lsblk` should show the three partitions at the expected sizes; if not, stop here, while the old pool is still intact on `sda`.

## Create the new smaller pool

Create the new pool on the smaller `sdb3` partition:

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

`-R` sets an alternate root, so nothing in the new pool mounts over the running system. It also keeps the new pool out of the live system's `/etc/zfs/zpool.cache`; the new root gets its own cache file further down.

Receive the base snapshot into the new pool. `-u` keeps the received datasets unmounted for now:

{% highlight shell %}
zfs receive -u -F -d "$NEWPOOL" < "$BK/rpool-$SN_BASE.zfs"
zfs list -r "$NEWPOOL"
zfs list "$NEWPOOL/ROOT/pbs-1"
{% endhighlight %}

## Final incremental sync

Before the final sync, make sure PBS isn't in the middle of something, then stop the services that write to the root pool:

{% highlight shell %}
proxmox-backup-manager task list

systemctl stop proxmox-backup-proxy proxmox-backup
systemctl is-active proxmox-backup-proxy proxmox-backup
sync
{% endhighlight %}

Wait for running backup, sync, verify or garbage-collection tasks to finish first. Both services must report `inactive`; if either is still running, don't take the final snapshot.

Create and send the final incremental snapshot:

{% highlight shell %}
FINAL_SN="shrink-final-$(date +%Y%m%d-%H%M%S)"

zfs snapshot -r "$OLDPOOL@$FINAL_SN"
zfs send -R -I "$OLDPOOL@$SN_BASE" "$OLDPOOL@$FINAL_SN" | zfs receive -u -F -d "$NEWPOOL"

echo "$FINAL_SN" > "$BK/final-snapshot-name.txt"
zfs list -r "$NEWPOOL" > "$BK/newrpool-after-final-recv.txt"
{% endhighlight %}

Set the boot dataset and mountpoints, then mount the new root explicitly under the altroot:

{% highlight shell %}
zpool set bootfs="$NEWPOOL/ROOT/pbs-1" "$NEWPOOL"
zfs set mountpoint=/ "$NEWPOOL/ROOT/pbs-1"
zfs set mountpoint="/$NEWPOOL" "$NEWPOOL"
zfs set mountpoint="/$NEWPOOL/ROOT" "$NEWPOOL/ROOT"

findmnt /mnt/newrpool >/dev/null || zfs mount "$NEWPOOL/ROOT/pbs-1"
findmnt -n -o SOURCE /mnt/newrpool
{% endhighlight %}

The last command must print `newrpool/ROOT/pbs-1`. A plain `test -d /mnt/newrpool/etc` isn't enough: if the dataset isn't mounted, the next steps would write into an empty directory on the old root.

## Prepare the new root to boot

Point the new root's kernel command line at `newrpool`. Only the `root=ZFS=` value changes; anything else on the kernel command line, such as a serial console, stays. GRUB reads `/etc/default/grub.d/zfs.cfg`; systemd-boot reads `/etc/kernel/cmdline`. A fresh install has both whatever the boot mode, so both get the same edit and can't disagree:

{% highlight shell %}
grep -n 'root=ZFS=' /mnt/newrpool/etc/default/grub.d/zfs.cfg /mnt/newrpool/etc/default/grub

sed -i "s|root=ZFS=$OLDPOOL/|root=ZFS=$NEWPOOL/|" /mnt/newrpool/etc/default/grub.d/zfs.cfg
[ -f /mnt/newrpool/etc/kernel/cmdline ] && \
  sed -i "s|root=ZFS=$OLDPOOL/|root=ZFS=$NEWPOOL/|" /mnt/newrpool/etc/kernel/cmdline

grep -rn 'root=ZFS=' /mnt/newrpool/etc/default/grub.d/zfs.cfg /mnt/newrpool/etc/kernel/cmdline 2>/dev/null

# Keep the same ZFS host identity after booting the received root.
cp /etc/hostid /mnt/newrpool/etc/hostid
{% endhighlight %}

The first `grep` shows where the root argument lives on your system; on mine it was in `/etc/default/grub.d/zfs.cfg`, plus `/etc/kernel/cmdline` on the UEFI test machines. After the edit, every match should read `root=ZFS=newrpool/ROOT/pbs-1`.

Give the new root a ZFS cache file that lists only `newrpool`. The copy that came over in the snapshot is the old system's, and it still lists `rpool`; booting with that would import the old pool next to the new one:

{% highlight shell %}
rm -f /mnt/newrpool/etc/zfs/zpool.cache
zpool set cachefile=/mnt/newrpool/etc/zfs/zpool.cache "$NEWPOOL"
zdb -C -U /mnt/newrpool/etc/zfs/zpool.cache | grep -E "^[^ ]|name:"
{% endhighlight %}

The `zdb` output should mention `newrpool` and nothing else.

Bind mount runtime filesystems for the chroot:

{% highlight shell %}
for d in dev proc sys run; do
  mountpoint -q "/mnt/newrpool/$d" || mount --rbind "/$d" "/mnt/newrpool/$d"
  mount --make-rslave "/mnt/newrpool/$d"
done
{% endhighlight %}

**UEFI:** the recursive bind of `/sys` also brings `/sys/firmware/efi/efivars` into the chroot. `proxmox-boot-tool init` needs it there to create the firmware boot entry for the new disk; `ls /mnt/newrpool/sys/firmware/efi/efivars | head -1` should list something.

Now rebuild the initramfs and set up the boot partition on `sdb2`. The new root's list of boot partitions (`/etc/kernel/proxmox-boot-uuids`) came over in the snapshot too, so it still names `sda2`. Empty it first, before anything runs in the chroot: `update-initramfs` triggers a `proxmox-boot-tool refresh` through its hooks, and with the old list that refresh rewrites `sda2` to boot `newrpool`. That's exactly what happened on my first test run, and it quietly removes your way back.

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

The two UUIDs at the end must be the same, and the file must contain only that one. The `udevadm settle` matters: without it, `init` can read the partition's old UUID from udev before the freshly formatted one shows up, register that, and then skip the partition when it copies the kernels. `init` already runs a refresh, so no separate `update-grub` or `refresh` is needed. `$INIT_MODE` is deliberately unquoted, so that when it's empty `init` gets no mode argument at all.

**UEFI:** on UEFI, `init` also writes a firmware boot entry, and the two loaders do it differently. Look at the result, matching entries to disks by partition UUID:

{% highlight shell %}
blkid -s PARTUUID -o value "$SDA-part2" "$SDB-part2"
efibootmgr -v | grep -E '^Boot(Order|[0-9A-F]{4}\* (Linux Boot Manager|proxmox))'
{% endhighlight %}

- **systemd-boot** adds a new "Linux Boot Manager" entry for `sdb2` and puts it first in the boot order. The entry for `sda2` stays, next to a stale one for the old `sdb2`, which no longer exists; that one is removed at the end.
- **GRUB with Secure Boot** keeps a single entry called "proxmox", and `init` moves it to `sdb2`. `sda` doesn't lose its way back: every boot partition also gets a copy of the loader at the removable-media path, `\EFI\BOOT\BOOTX64.EFI`, which is what the firmware runs when you pick the disk itself from its boot menu. That's how my rollback test booted the old disk.

Check that the initramfs picked up the new cache file:

{% highlight shell %}
lsinitramfs /mnt/newrpool/boot/initrd.img-$(uname -r) | grep zpool.cache
{% endhighlight %}

Nothing on the running system changes in this section. Its own GRUB configuration, cache file and boot partition list still describe `rpool`, so `sda` remains a working way back.

Verify both boot partitions: `sdb2` must have a kernel and a GRUB configuration pointing to `newrpool`, and `sda2` must still point to `rpool`:

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

The `grep` searches the whole partition, so it finds the kernel command line wherever the boot loader keeps it: `grub/grub.cfg` for GRUB, `loader/entries/` for systemd-boot. On `sdb2` you should see the kernel and initrd files and `root=ZFS=newrpool/ROOT/pbs-1`; on `sda2`, `root=ZFS=rpool/ROOT/pbs-1` and no mention of `newrpool`. GRUB also adds a generic `root=ZFS=/ROOT/pbs-1` on both; that's normal, and the later, specific value wins. If `sda2` mentions `newrpool`, it has been retargeted: run `proxmox-boot-tool refresh` on the live system to put it back before going any further.

Finally, tear down the chroot:

{% highlight shell %}
umount -R /mnt/newrpool
{% endhighlight %}

I don't export `newrpool` here. Daemons running in their own mount namespaces, such as `systemd-udevd`, `systemd-logind` and `chronyd`, keep copies of the chroot's mounts, and `zpool export` refuses with "pool is busy". It doesn't matter: the reboot closes the pool, and with the same host ID the initramfs imports it without complaint.

## Boot from the new disk

`sda` still boots the old pool. That's the point: the first boot has to come from `sdb` on purpose, or it proves nothing about `sdb`.

On legacy BIOS, the firmware still boots from `sda` by default. Reboot, and from the console pick the `sdb` disk in the BIOS one-time boot menu:

{% highlight shell %}
sync
systemctl reboot
{% endhighlight %}

**UEFI:** you don't need the console for this. Tell the firmware which entry to use for the next boot only, the one pointing at `sdb2`:

{% highlight shell %}
P=$(blkid -s PARTUUID -o value "$SDB-part2")
efibootmgr -v | grep -i -- "$P"
N=$(efibootmgr -v | grep -i -- "$P" | sed -nE 's/^Boot([0-9A-F]{4}).*/\1/p' | head -1)
efibootmgr --bootnext "${N:?no boot entry for sdb2}"
sync
systemctl reboot
{% endhighlight %}

With systemd-boot the new entry is already first in the boot order, so `--bootnext` only makes it explicit. After the reboot, `efibootmgr | grep BootCurrent` tells you which entry the firmware actually used. Not every firmware treats boot entries the same way: my test VMs' firmware re-sorted the boot order to follow the VM's disk order, so a plain reboot went back to `sda`. Trust `BootCurrent` and `findmnt`, not the order you expected.

After the host returns, verify that root is now mounted from `newrpool`:

{% highlight shell %}
cat /proc/cmdline
findmnt -n -o SOURCE /
zpool status -v newrpool
zpool list -v newrpool
{% endhighlight %}

Expected result:

{% highlight text %}
root=ZFS=newrpool/ROOT/pbs-1
newrpool/ROOT/pbs-1
newrpool  49.5G  ONLINE
{% endhighlight %}

If you landed on `rpool` instead, the firmware booted `sda`. Reboot and choose `sdb` again. If `sdb` doesn't boot at all, boot `sda`: you're back on the original system, and nothing has been lost. On UEFI that means the "Linux Boot Manager" entry for `sda2` (systemd-boot) or the `sda` disk itself in the firmware boot menu (Secure Boot).

Do not continue until the live root filesystem is on `newrpool`, booted from `sdb`.

## Retire the old pool

The shell variables are gone after the reboot. Load them back and make sure none came back empty:

{% highlight shell %}
BK=$(cat /root/.last-rpool-shrink-backup)
. "$BK/vars.sh"
echo "${OLDPOOL:?} ${NEWPOOL:?} ${SDA:?} ${SDA3:?} ${SDB:?} ${SDB3:?}"
{% endhighlight %}

`/root` here is the copy that came over with the final snapshot, so it has the pointer to the backup directory.

Now prove that the disk about to be erased is not the one you're running from. The new pool must contain the `sdb` path and must not contain the `sda` one:

{% highlight shell %}
zpool status -P "$NEWPOOL"
zpool status -P "$NEWPOOL" | grep -F -- "$SDB3"
zpool status -P "$NEWPOOL" | grep -F -- "$SDA" && echo "STOP: sda is part of $NEWPOOL"
{% endhighlight %}

The second command must print the `sdb3` line; the third must print nothing.

Then make sure the old pool isn't imported and nothing is using the old disk:

{% highlight shell %}
zpool list
zpool export "$OLDPOOL"
lsblk -o NAME,PATH,FSTYPE,MOUNTPOINTS "$SDA"
{% endhighlight %}

If `rpool` shows up in `zpool list`, the export has to succeed. If it doesn't export, or anything on `sda` is mounted, stop and find out why. With the new cache file, `rpool` normally isn't imported at boot at all, and the export just reports that the pool doesn't exist.

## Repartition sda and reattach it

The system is running from the new 50GB pool on `sdb3`, and the old pool is closed. Up to this point, booting `sda` from the BIOS menu would still bring back the original system. The next command ends that.

Clear the old ZFS label, without hiding errors:

{% highlight shell %}
zpool labelclear -f "$SDA3"
{% endhighlight %}

If this fails because the device is in use, go back to the previous step; something still has the old pool open.

Repartition the `sda` disk:

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

Attach the new `sda3` as the second side of the mirror:

{% highlight shell %}
zpool attach -f "$NEWPOOL" "$SDB3" "$SDA3"
{% endhighlight %}

Watch the resilver:

{% highlight shell %}
watch -n 5 zpool status "$NEWPOOL"
{% endhighlight %}

Wait until the resilver finishes.

## Recreate the sda boot partition

Once `sda3` is part of the mirror, recreate the boot partition on `sda2` and register it. `proxmox-boot-tool clean` drops any UUID in the list whose partition no longer exists:

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

`proxmox-boot-tool status` should list two partitions, one on each disk, both set up the same way (`grub` or `uefi`). If it lists only one, `init` registered a stale UUID (the same udev race as on `sdb2`) and `clean` threw it away: run `udevadm settle`, then `init` and `refresh` again.

**UEFI:** repartitioning gave `sda2` a new partition UUID, so the firmware entry for the old `sda2` now points at nothing, and with systemd-boot so does the one for the original `sdb2`. Remove every boot entry for these loaders whose partition UUID isn't one of the two current boot partitions:

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

`echo "$KEEP"` must print two UUIDs before you trust the loop; if it prints fewer, don't run it. The loop only looks at entries named "Linux Boot Manager" or "proxmox", and leaves other operating systems' entries and the firmware's own alone.

What's left depends on the loader. With systemd-boot, you end up with one "Linux Boot Manager" entry per disk. With Secure Boot GRUB, `init` has moved the single "proxmox" entry to `sda2`, and `sdb` boots through its removable-media copy, exactly as on a fresh install. If you'd rather have a named entry for each disk, add one for `sdb`:

{% highlight shell %}
efibootmgr -c -d "$SDB" -p 2 -L "proxmox (sdb)" -l '\EFI\proxmox\shimx64.efi'
{% endhighlight %}

Some firmware, including the one in my test VMs, silently deletes boot entries for disks that are missing at boot. If an entry disappears after the single-disk tests below, `proxmox-boot-tool reinit` puts them back: with systemd-boot it recreates one entry per boot partition; with Secure Boot it points "proxmox" at the last partition in the list again.

> **Field note: `mkfs.vfat` hang on `sda2`**
>
> On one run, `mkfs.vfat` got stuck in uninterruptible I/O while formatting `sda2`. The ZFS resilver still completed successfully, but the formatter did not return. That run didn't yet export the old pool or check the label clear, so the likeliest cause is that `rpool` was still imported when its disk was repartitioned. That's why the procedure now retires the old pool explicitly first. The useful checks were:

{% highlight shell %}
ps -o pid,ppid,stat,wchan:32,cmd -C mkfs.vfat
zpool status newrpool
zpool list
dmesg | tail -100
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$SDA" "$SDB"
{% endhighlight %}

If this happens, first confirm that the system is running from `newrpool`, that `sdb2` is already bootable, and that the ZFS mirror is healthy or at least understood. Then reboot and retry the `proxmox-boot-tool` step for `sda2`.

## Scrub and final verification

Clear any transient counters and run a scrub:

{% highlight shell %}
zpool clear "$NEWPOOL"
zpool scrub "$NEWPOOL"

while zpool status "$NEWPOOL" | grep -q "scrub in progress"; do
  zpool status "$NEWPOOL"
  sleep 5
done
{% endhighlight %}

Final checks:

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

The final state should look like this:

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

A mirrored pool isn't the same thing as a mirrored boot. The last test is to boot from each disk on its own: reboot, pick `sda` in the firmware boot menu (or with `efibootmgr --bootnext`), run the checks above; reboot again, pick `sdb`, and repeat. Physically disconnecting the other disk is a stronger test, if you can; that's what I did on the test VMs. If both land on `newrpool/ROOT/pbs-1`, either disk can die without taking the server down with it. Until then, the migration isn't finished.

## Rollback notes

The backup directory contains:

- GPT backups for both disks.
- ZFS property and dataset listings.
- A recursive ZFS send stream of the original `rpool`, plus the name of its snapshot.
- A tarball of important system configuration.
- The saved variables for the second half of the procedure.
- Checksums for the artifacts.

How you roll back depends on how far you got:

- **Before `zpool labelclear` on `sda3`:** the original system is intact on `sda`. Its pool, boot partition, GRUB configuration and cache file were never touched. Pick `sda` in the firmware boot menu and it boots `rpool` as before. Anything written after the final snapshot lives only on `newrpool`, but with the PBS services stopped for the sync, that should be next to nothing.
- **After `sda` has been repartitioned:** both disks are new. If `newrpool` is broken at that point, recovery means booting rescue media, creating a suitable pool, receiving the saved ZFS stream, and reinstalling the boot loader.

The important part is not the exact commands. The important part is the order:

1. Verify layout.
2. Create and verify backup.
3. Rebuild one mirror leg as a smaller pool.
4. Replicate root.
5. Boot from the new disk, chosen on purpose.
6. Retire the old pool, then destroy and reattach the other mirror leg.
7. Scrub, then boot from each disk on its own.
