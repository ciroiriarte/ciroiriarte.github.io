---
permalink: /datacenter/2026/11/13/pbs-usb-tapes-1-why.html
title: "USB disks as tapes for Proxmox Backup Server (1/3): why, and what's new"
description: Why you might want PBS tape jobs on plain USB disks, what mhVTL gained to make it work (raw-disk cartridges, hot-plug bays, real drive encryption) and where it is heading.
date: 2026-11-13 10:00:00 -0300
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

A Proxmox Backup Server datastore is online storage. It is fast, deduplicated and always online. That's the problem: whoever gets root on the PBS host, or a token with enough privileges, can reach it too. The copy that has to survive ransomware, a fat-fingered `rm` or a fire should sit on a shelf, unplugged, ideally in another building.

The classic answer is tape, and PBS has very good tape support. But an LTO drive costs more than many small sites spend on the whole backup server. A handful of USB disks costs almost nothing, and someone can take them home on Friday.

So the idea of this series is simple: **make USB disks behave like tapes**, and let PBS do what it already does well with tapes.

<!--more-->

This is part 1 of a series of three:

1. **Why, and what's new** (this post): the reasoning, and what is new in mhVTL to make it possible.
2. [The CLI procedure]({% post_url 2026-11-13-pbs-usb-tapes-2-cli %}): mhVTL and PBS from the shell, copy and paste.
3. [The point & click procedure]({% post_url 2026-11-13-pbs-usb-tapes-3-gui %}): the same, from the mhVTL Control dashboard and the PBS web UI.

## What PBS already offers

Before building anything, it's worth checking what PBS already offers.

**Clients never write to tape directly.** PVE and `proxmox-backup-client` always back up to a datastore. A tape backup job then copies snapshots from the datastore into a *media pool* ([PBS docs, Tape Backup](https://pbs.proxmox.com/docs/tape-backup.html)). That suits the plan: the datastore stays the fast first copy, and the disks become the offline second copy.

To get a copy out of the datastore, PBS has three options:

- **Sync jobs** copy snapshots between datastores, locally or to a remote PBS (pull, and push since PBS 3.3).
- **Removable datastores** (since [PBS 3.3](https://www.proxmox.com/en/about/company-details/press-releases/proxmox-backup-server-3-3)) put a whole datastore on a USB disk formatted with ext4 or XFS. You plug it in, sync into it and unmount it ([PBS docs, Removable Datastores](https://pbs.proxmox.com/docs/storage.html)).
- **Tape backup jobs** write snapshots into *media sets*, with allocation and retention policies, a catalog of what is on each tape, and drive encryption.

For one or two disks, a removable datastore is simpler, and probably the better answer. The tape semantics start to pay off when you rotate several disks and want PBS to keep track of them:

| | Removable datastore | Tape job on a mhVTL raw disk |
|---|---|---|
| Extra software | None | mhVTL (kernel module and daemons) |
| On-disk format | ext4/XFS with a chunk store | No filesystem, a sequential tape image |
| Copying | Incremental: a sync copies only new chunks | Full copy per media set (with `--allocation always`) |
| Larger than one disk | No | A media set can span several disks |
| Pulling the disk | Clean unmount, or the datastore stays in maintenance mode | Cartridge exported to the mail slot, data already flushed |
| Rotating N disks | By hand | Media pool with allocation and retention policies |
| What is on the disk in the drawer? | Plug it in and look | PBS keeps a catalog of offline media |
| Encryption | Client-side | Client-side, or the pool key ([AES-256-GCM in the drive](#real-encryption)) |
| Restore | Browse and restore directly | Restore the media set into a datastore first |
| Other backup software | PBS only | Anything that speaks to a tape library |
| Moving to real LTO later | Start over | Same pools and jobs, swap the hardware |

Two small bonuses for the raw disk: no desktop component tries to auto-mount it, and a disk pulled at the wrong time has no filesystem to `fsck`.

## What changed in mhVTL

[mhVTL](https://github.com/markh794/mhvtl) is a virtual tape library for Linux. It emulates SCSI tape drives and robotic changers well enough that backup applications can't tell the difference. Traditionally, each virtual cartridge is a directory of files under `/opt/mhvtl`. That works for testing, but a cartridge stuck inside a filesystem on the backup server doesn't help anyone when the building burns down.

Over the last few weeks, a set of changes landed upstream that lets cartridges live on removable disks. I wrote them; Mark Harvey, the mhVTL maintainer, reviewed and merged them.

### Raw-disk cartridges

A whole block device can now be a cartridge ([#214](https://github.com/markh794/mhvtl/pull/214)). One disk is one tape. No partition table and no filesystem.

The first megabyte is left empty, so nothing on the host thinks the disk is worth mounting. After it come a superblock (plus a mirror copy) with the barcode and layout, the cartridge memory (MAM), and the data stream.

`mhvtl-raw-format` initializes a disk, and since [#293](https://github.com/markh794/mhvtl/pull/293) it also writes a proper MAM, so the drive knows the capacity from the first write.

When a backup application writes a filemark or unloads the tape, mhVTL flushes the disk (`fdatasync`) before answering. In a test environment, disks pulled from the mail slot and plugged back in read back intact every time.

### Hot-plug bays

`mhvtl-bay-monitor` watches udev and binds a physical USB port (its stable `/dev/disk/by-path` name, never `/dev/sdX`) to a library's mail slots. Mail slots are the import/export station of a library: mhVTL calls them MAP, PBS calls them I/E slots.

Plug a formatted disk into the dock and its cartridge appears in a mail slot. Pull it out and the cartridge disappears from the library. Follow-ups handle the corner cases:

- a disk formatted in place ([#294](https://github.com/markh794/mhvtl/pull/294))
- a monitor restarted with a disk in the dock ([#296](https://github.com/markh794/mhvtl/pull/296))
- several docks on one library ([#298](https://github.com/markh794/mhvtl/pull/298))

To PBS this looks exactly like an operator walking up to a real library and dropping a tape in the mail slot.

### Real encryption {#real-encryption}

Until recently, mhVTL drive encryption was *simulated*. The drive accepted the key and wrote the data in plain text, with the key in every block header. Fine for testing an application, but useless for disks that leave the building.

Since [#328](https://github.com/markh794/mhvtl/pull/328), the drive encrypts every block with AES-256-GCM. The key is derived from what the application sends plus a random salt stored in the cartridge memory, and is never written to the disk.

That's the default for drives that support encryption, so a PBS media pool with an encryption key now gives you an encrypted disk. In a test environment, I searched the raw disk for samples of a random file I'd backed up: they were all in the PBS datastore, and none were on the encrypted disk.

### Faster compression

LZ4 and Zstandard joined the old zlib and LZO. It doesn't matter much for PBS, whose chunks are already compressed, and mhVTL stores a block as-is when compression doesn't shrink it.

### A dashboard

[mhVTL Control](https://github.com/ciroiriarte/mhvtl-control) is a separate project of mine: a REST API and web dashboard for mhVTL. It shows the libraries live, edits the configuration with a check step before applying it, and formats raw disks. Part 3 uses it for the point & click version.

## Where this is going

In this series, the USB dock hangs off the PBS host itself. The next step is to move the disks to a separate box.

mhVTL can now export its libraries over **iSCSI**: `mhvtl-fabrics` ([#337](https://github.com/markh794/mhvtl/pull/337)) provisions the targets on top of the TCMU backend, which is still experimental. **Fibre Channel** target support is in the works too. With either, a separate box with hot-swap bays becomes "the tape library", and the PBS host sees an ordinary tape library on the fabric. No mhVTL on the backup server, no USB cable to it, and disks rotated at the box that holds them.

That deserves its own post once it has been through a test environment. For now, [part 2]({% post_url 2026-11-13-pbs-usb-tapes-2-cli %}) builds the local version from the shell.

---

{% include series-pbs-usb-tapes.html current="1" %}
