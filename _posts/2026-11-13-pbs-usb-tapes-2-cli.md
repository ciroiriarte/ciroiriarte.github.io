---
title: "USB disks as tapes for Proxmox Backup Server (2/3): the CLI way"
description: Step by step, from the shell. Install mhVTL, define a library with a USB dock as its mail slot, format disks as tape cartridges, and run encrypted PBS tape jobs and restores against them.
date: 2026-11-13 10:01:00 -0300
layout: post
author_profile: true
author: Ciro Iriarte
categories:
- Datacenter
tags:
- Proxmox
- Proxmox Backup Server
- mhVTL
- Tape
- Storage
- backup
---

In [part 1]({% post_url 2026-11-13-pbs-usb-tapes-1-why %}) I explained why you might want PBS tape jobs on plain USB disks. This part builds it from the shell: one virtual library, one LTO-8 drive, a USB dock acting as the library's mail slot, and an encrypted media pool rotating disks.

Every command and output below comes from a fresh lab run. If you prefer clicking, [part 3]({% post_url 2026-11-13-pbs-usb-tapes-3-gui %}) does the same from the web UIs.

<!--more-->

# Starting point

- Proxmox Backup Server 4.2 with a datastore holding some backups. Mine is called `store1`.
- A USB dock or USB-SATA adapter, plus the disks you want to rotate. One disk is one cartridge.
- mhVTL `1.8.0+git20261101.7e3a101` from my [openSUSE Build Service project](https://build.opensuse.org/project/show/home:ciriarte:mhvtl). Everything used here is in mhVTL master but not in a tagged release yet, hence the snapshot.

My lab was a Debian 13 VM with PBS installed on top, and the "USB dock" a USB port on a virtual xHCI controller with 16 GB disks hot-plugged into it. The kernel sees real USB hot-plug events, so mhVTL can't tell the difference. Throughput numbers are from that VM, not a benchmark.

The steps assume a PBS host without mhVTL yet: they replace the sample configuration the package installs. If you already run mhVTL libraries on that host, add the library and drive below to your own `device.conf` instead.

Run everything as root.

# Install mhVTL

Add the repository and install mhVTL. The kernel module is built with DKMS, so name the headers package explicitly:

{% highlight shell %}
install -d /etc/apt/keyrings
curl -fsSL -o /etc/apt/keyrings/mhvtl.asc \
    https://download.opensuse.org/repositories/home:/ciriarte:/mhvtl/Debian_13/Release.key
echo "deb [signed-by=/etc/apt/keyrings/mhvtl.asc] https://download.opensuse.org/repositories/home:/ciriarte:/mhvtl/Debian_13/ /" \
    > /etc/apt/sources.list.d/mhvtl.list
apt-get update
apt-get install linux-headers-amd64 mhvtl      # PBS on top of Debian
#apt-get install proxmox-default-headers mhvtl  # PBS from the ISO (Proxmox kernel)
{% endhighlight %}

**Note:** Headers have to match the running kernel. If you just upgraded the kernel, reboot first, or DKMS builds the module only for the kernel you aren't running yet. Name the headers metapackage, too: without it, apt pulled Proxmox kernel headers into my Debian-kernel box to satisfy `mhvtl-dkms`.

The install doesn't start mhVTL yet, which leaves time for one more step. Linux's `ch` driver leaks a reference to every drive each time a changer appears, so a drive mhVTL removes can't come back until a reboot ([fixed in 7.3-rc7](https://git.kernel.org/torvalds/c/27c0f718d3b3), not in today's PBS kernels). PBS talks to changers through `/dev/sg*` and doesn't need `ch`, so keep it out:

{% highlight shell %}
echo "blacklist ch" > /etc/modprobe.d/mhvtl-no-ch.conf
modprobe -r ch     # if this fails, ch is in use: reboot before going on
{% endhighlight %}

# Define the library

The package ships two sample STK libraries, and PBS won't see either of them. PBS only lists a changer when udev gives it an `ID_SCSI_SERIAL`, which comes from INQUIRY VPD page 0x83. The STK L700 and L80 that mhVTL emulates faithfully don't have it, so I use an IBM TS3500 personality (`03584L22`), which does.

Keep a copy of the samples, then replace `/etc/mhvtl/device.conf` with one library and one drive:

{% highlight shell %}
cp -a /etc/mhvtl /root/mhvtl.orig
{% endhighlight %}


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

There's no `Encryption:` line because AES-256-GCM is the default for drives that support it (see `man device.conf`). PBS chunks are already compressed, so LZ4 is just the cheapest codec to have enabled.

Then `/etc/mhvtl/library_contents.10`: four storage slots and two mail slots, all empty. The disks bring their own cartridges.

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

Drop the second sample library and start mhVTL. A systemd generator builds the `vtllibrary@`/`vtltape@` units from `device.conf`, hence the reload:

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

The devices take a few seconds to show up after the restart. (My run shows `/dev/sch0` because `ch` wasn't blacklisted yet. With the blacklist in place, that column shows `-`.)

# Bind the dock to a mail slot

`mhvtl-bay-monitor` maps a physical disk location to a library's mail slots. The location is the stable `/dev/disk/by-path` name of the USB port, never `/dev/sdX`. Plug any disk into the dock and look it up:

{% highlight shell %}
ls -l /dev/disk/by-path/ | grep usb
{% endhighlight %}

{% highlight text %}
pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0 -> ../../sdb
pci-0000:00:01.0-usbv3-0:1:1.0-scsi-0:0:0:0 -> ../../sdb
{% endhighlight %}

Use the plain `usb-` name. The `usbv3-` one carries the USB version the disk negotiated, so a disk that falls back to USB 2 would show up under another name. Every disk plugged into this port lands in the same bay, which is exactly what a rotation needs.

Bind it to library 10 and start the monitor. The second column is the intended mail slot; for now the cartridge lands in the first free one, which with a single dock is always the same:

{% highlight shell %}
BAY=/dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0
echo "10  1  $BAY" > /etc/mhvtl/mhvtl_raw_bays.conf
systemctl enable --now mhvtl-bay-monitor
journalctl -u mhvtl-bay-monitor -o cat | grep -E 'handle_add|monitoring'
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_add(): bay /dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0 not placed: no readable MVTL cartridge in bay
mhvtl-bay-monitor: main(): monitoring 1 bay(s) for raw-disk hot-plug events
{% endhighlight %}

The disk in the dock is blank, so nothing is placed yet. That's expected.

# Configure PBS

PBS now finds the changer and the drive:

{% highlight shell %}
proxmox-tape changer scan
proxmox-tape drive scan
{% endhighlight %}

{% highlight text %}
│ /dev/tape/by-id/scsi-USBLIB01 │ IBM    │ 03584L22 │ USBLIB01 │
│ /dev/tape/by-id/scsi-00USBDRV01-sg │ IBM    │ ULT3580-TD8 │ 00USBDRV01 │
{% endhighlight %}

Create them:

{% highlight shell %}
proxmox-tape changer create usblib --path /dev/tape/by-id/scsi-USBLIB01
proxmox-tape drive create usbdrive --path /dev/tape/by-id/scsi-00USBDRV01-sg \
    --changer usblib --changer-drivenum 0
{% endhighlight %}

Next, an encryption key and a media pool that uses it. `key create` prompts for a password. Print the paper key and store it away from this server: without the key, nobody can read the disks, you included.

{% highlight shell %}
proxmox-tape key create --hint offsite-2026
(umask 077; proxmox-tape key paperkey <fingerprint> --output-format text > /root/offsite-paperkey.txt)
proxmox-tape pool create offsite --allocation always --retention "20 days" \
    --encrypt <fingerprint>
{% endhighlight %}

`--allocation always` starts a new media set on every run. As long as a run fits on one disk, each disk is a self-contained copy that can leave the building. If it doesn't, the media set spans several disks, and they travel (and restore) together. Retention has to be shorter than the rotation cycle, or the disk coming back is still protected and PBS asks for a new one. With three disks rotated weekly, a disk returns after 21 days, so 20 days works.

In the changer, mail slots are numbered after the storage slots. With four slots, the dock is element 5:

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

# Initialize a disk

This happens once per disk and **erases whatever is on it**. Format the disk in the dock as a cartridge. The `L8` barcode suffix makes it LTO-8 media, matching the drive, and the capacity is whatever the disk holds:

{% highlight shell %}
mhvtl-raw-format $BAY --barcode USB001L8
{% endhighlight %}

{% highlight text %}
Formatted /dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0 as raw cartridge 'USB001L8' (partitions: 100, min record 65536 bytes)
{% endhighlight %}

The monitor notices on its own and drops the cartridge into the mail slot:

{% highlight shell %}
journalctl -u mhvtl-bay-monitor -o cat | tail -1
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_add(): placed USB001L8 (library 10 MAP, bay /dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0)
{% endhighlight %}

PBS caches the changer state, so ask for a fresh read:

{% highlight shell %}
proxmox-tape changer status usblib --cache false
{% endhighlight %}

{% highlight text %}
Unit Attention, Additional sense: Import or export element accessed
│ import-export │        5 │ USB001L8   │             │
{% endhighlight %}

The "Unit Attention" is the library telling PBS that someone touched the mail slot. That's how a real library behaves too.

PBS won't label media sitting in a mail slot (`changer device does not list any media labels`), so move it into a storage slot first. Then `barcode-label` labels every unlabeled cartridge in the library with its barcode:

{% highlight shell %}
proxmox-tape changer transfer usblib --from 5 --to 1
proxmox-tape barcode-label --drive usbdrive --pool offsite
{% endhighlight %}

{% highlight text %}
checking/loading media 'USB001L8'
Label media 'USB001L8' for pool 'offsite'
TASK OK
{% endhighlight %}

# Run a backup

`--export-media-set` moves the cartridge back to the mail slot when the job ends, so the disk is ready to pull as soon as the task finishes:

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

For the weekly routine, make it a job:

{% highlight shell %}
proxmox-tape backup-job create weekly-usb --store store1 --pool offsite \
    --drive usbdrive --schedule "sat 02:00" --export-media-set true
{% endhighlight %}

`proxmox-tape backup-job run weekly-usb` runs it on demand.

Is the disk really encrypted? I searched all 16 GB of the raw device for four 32-byte samples of a random file in that backup. Each sample showed up once in the PBS datastore and nowhere on the disk.

# Pull the disk

Check that the cartridge is in the mail slot, then unplug the disk:

{% highlight shell %}
proxmox-tape changer status usblib --cache false | grep import-export
{% endhighlight %}

{% highlight text %}
│ import-export │        5 │ USB001L8   │             │
{% endhighlight %}

The monitor takes the cartridge out of the library:

{% highlight shell %}
journalctl -u mhvtl-bay-monitor -o cat | tail -1
{% endhighlight %}

{% highlight text %}
mhvtl-bay-monitor: handle_remove(): removed USB001L8 (library 10 MAP, bay /dev/disk/by-path/pci-0000:00:01.0-usb-0:1:1.0-scsi-0:0:0:0)
{% endhighlight %}

PBS keeps the disk in its inventory as offline media, with its catalog:

{% highlight shell %}
proxmox-tape media list
{% endhighlight %}

{% highlight text %}
│ label-text │ pool    │ media-set-name           │ seq-nr │ status │ location │ catalog │
│ USB001L8   │ offsite │ Fri Nov 13 13:09:32 2026 │      0 │ full   │ offline  │      ok │
{% endhighlight %}

If a backup ran without `--export-media-set`, do the export yourself before pulling the disk:

{% highlight shell %}
proxmox-tape unload --drive usbdrive
proxmox-tape export-media --drive usbdrive USB001L8
{% endhighlight %}

# The weekly routine

Once the disks are initialized, a rotation is:

1. Plug in the disk that is due. It shows up in mail slot 5.
2. `proxmox-tape changer transfer usblib --from 5 --to 1`
3. Let the job run. It exports the disk back to slot 5.
4. Unplug it and take it off site.

An expired disk is reused by the pool automatically. `mhvtl-raw-format` and `barcode-label` are only needed for new disks. In the lab, a second disk (`USB002L8`) went through the same steps, and the job wrote to it on its own.

# Restore

Plug the disk back in, move it to a storage slot, and restore its media set into a datastore. `proxmox-tape media list` shows the media-set UUID:

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

The key is in PBS's key store, so the restore didn't ask for anything. The 2 GiB random file in that snapshot came back with the same SHA-256 as the original.

The restore leaves the disk in the drive. Send it back to the mail slot before unplugging it:

{% highlight shell %}
proxmox-tape unload --drive usbdrive
proxmox-tape export-media --drive usbdrive USB001L8
{% endhighlight %}

On a rebuilt PBS, the key store and the media catalog are gone. Set up mhVTL and the PBS changer and drive again as above, but **don't format or label the disks**. Plug in the disk, move it to a slot, then bring the key back from the paper copy and let PBS read the disk:

{% highlight shell %}
proxmox-tape key restore --key-file /root/offsite-paperkey.txt   # asks for the key password
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

Then restore the media set as above. I tested this by wiping the key, pool, inventory and catalogs on the lab PBS: the restore into a new datastore worked and the checksum matched.

# Caveats

- **Don't pull a loaded disk.** I tried: while the disk was out, the drive reported "Medium format corrupted". After plugging it back in, `proxmox-tape unload` followed by `proxmox-tape load-media USB001L8 --drive usbdrive` brought it back, and a full catalog rescan read the data fine. Still, wait for the mail slot.
- **USB bridges and flushes.** mhVTL asks for a flush on every filemark and unload, but some cheap USB-SATA bridges ignore cache flushes. Buy a decent UAS dock.
- **More docks.** A second dock is another line in `mhvtl_raw_bays.conf` (restart `mhvtl-bay-monitor` afterwards). Each disk lands in the first free mail slot, not necessarily the one in its line, so check `changer status --cache false` for the barcode before moving or pulling anything. Pulling one disk only takes its own cartridge out.
- **Encryption needs this snapshot or newer.** On mhVTL builds older than [#328](https://github.com/markh794/mhvtl/pull/328), drive encryption is simulated and the key is written next to the data. Check `man device.conf` for the `Encryption:` option. If it's not there, use [PBS client-side encryption](https://pbs.proxmox.com/docs/backup-client.html#encryption) instead.
- **New code.** Raw-disk cartridges are young. Test a restore before you rely on them, as with any backup.
