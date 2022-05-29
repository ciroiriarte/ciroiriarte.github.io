---
id: 32
title: 'Rebuilding partition table'
date: '2009-03-15T20:00:26-04:00'
author: ciroiriarte
excerpt: 'Recovering partition table from data on disk'
layout: post
guid: 'http://cyruspy.wordpress.com/?p=32'
permalink: /index.php/2009/03/15/rebuilding-partition-table/
categories:
    - OSS
tags:
    - fdisk
    - 'rebuild partition table'
    - testdisk
---

Ok, an ex school partner brought me his laptop today and told me that it suddenly stopped working (yeah right).

Booted a linux rescue disk and after inspecting the hard disk I found it had 3 partitions:

> Disco /dev/sdb: 160.0 GB, 160041885696 bytes  
> 255 heads, 63 sectors/track, 19457 cylinders  
> Units = cilindros of 16065 \* 512 = 8225280 bytes  
> Disk identifier: 0xac23bbdb
> 
> Disposit. Inicio Comienzo Fin Bloques Id Sistema  
> /dev/sdb1 1 18748 150593278+ 83 Linux  
> /dev/sdb2 18749 19457 5695042+ 5 Extendida  
> /dev/sdb5 18749 19457 5695011 82 Linux swap / Solaris

Hmm, Linux partition.. But how can this be?, he’s a Windows-only guy… Obviously someone screwed it big time…

Tried to mount the first partition, but it didn’t have a valid filesystem aparently. Took out the disk and mounted it on a external SATA &lt;–&gt; USB cage and plugged it on my laptop.

First of all tried to check what was on each partition, “file” utility only stated “data”, but “strings” on the partition showed there still was the WinXP data on the disk. Apparently someone booted the laptop with a linux installer and aborted the installation process, not before it screwed the partition table.

First thought, “well, I’ll delete the current partitions and create a single NTFS on the whole disk and the data fill just appear!”, having created the partition tried to access the data and failed miserably….

So, obviously, as it’s a laptop it probably has those so-usually-found-this-days utility partition. How can I guess the partition table from the bits on the disk?!.

After researching for a while found about [TestDisk](http://www.cgsecurity.org/wiki/TestDisk). Downloaded, installed and run it against the disk and some minutes later It found the original partition table!!!

Got lucky, but YMMV…