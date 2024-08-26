---
id: 46
title: 'Running SCO Openserver 5.0.7 in VirtualBox'
date: '2009-10-08T16:38:22-04:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=46'
permalink: /index.php/2009/10/08/running-sco-openserver-5-0-7-in-virtualbox/
categories:
    - Projects
    - Virtualization
---

**Update:** *As of VirtualBox 3.0.10, Openserver 5.0.7 should not require workarounds to install, only SCSI support is pending… (check the listed bugreports).*

A customer required to replace and ancient SCO server used to run Foxplus, given that Openserver 5 is unlikely to be able to run with new hardware the only available route in this case was to virtualize the Openserver server. To date iBCS or ABI or whatever is the latest incarnation, didn’t work for us.

We are running SLES10SP2@x86\_64 as host, but any host running VirtualBox should work. The original installation was done on 3.0.4 but this steps where tested in 3.0.8 for this article. The only missing functionality is GUI.

**VM configuration**

*General*

- Operating System: Other
- Version: Other

*System*

- Base Memory: 512M
- Enable ACPI
- Processor: 1
- Enable VT-x/AMD-V
- Enable Nested Paging (showed improvement in file creation tests)

*Hard Disks*

- IDE Controller: 1 disk (6GB, dynamic). None of the official SCSI drivers detect the virtualized SCSI adapters of VirtualBox

*CD/DVD Drive*

- Image mounted: OpenServer-5.0.7Hw-10Jun05\_1800.iso

*Network*:

- Intel PRO/1000 MT Desktop

**Installation Procedure** (I will only list relevant changes in each steps)

- *Preparing your disk and choosing software* –&gt; *Optional Software*: In “Graphical Environment” we should deselect “X Server and Graphics Drivers” as Video Configuration Manager causes “Guru Meditation”.

- *Configuring optional software* –&gt; *Network card*: Deferred (it won’t work before installing MP5)

**Post installation**

*Install MP5*

- Mount osr507suppcd5.iso. Run “custom” and select “Software” –&gt; “Install New” –&gt; “From &lt;your\_vm\_name&gt;” –&gt; “Media Device” = CD-ROM Drive 0

Select and Install**:**

- SCO Openserver Release 5.0.7 Maintenance Pack 5
- SCO Openserver Release 5.0.7 Graphics and NIC Drivers

Reboot

*Network configuration*

- Run scoadmin –&gt; Networks –&gt; Network Configuration Manager –&gt; Hardware –&gt; Add new LAN Adapter. It should detect the Intel NIC.

**Fix Guru Meditation on poweroff**

Shutdown events to reboot or poweroff triger “Guru Meditation” also. For the time being I found a workaround for poweroff, but reboot is still broken.

Edit /etc/conf/pack.d/uapm/space.c, search for function “uapm\_offstates” of type “ulong\_t”and modify events 0 and 3 to triger “APMPWR\_OFF”.

Here’s a patch:

> — space.c.orig 2009-10-08 16:38:00.000000000 -0400  
> +++ space.c 2009-10-08 16:38:00.000000000 -0400  
> @@ -76,10 +76,10 @@  
> \*/
> 
> ulong\_t uapm\_offstates\[\] = {  
> – APMPWR\_READY, /\* 0 AD\_HALT No auto reboot \*/  
> \+ APMPWR\_OFF, /\* 0 AD\_HALT No auto reboot \*/  
> APMPWR\_READY, /\* 1 AD\_BOOT Auto reboot \*/  
> APMPWR\_READY, /\* 2 AD\_IBOOT (same as AD\_BOOT) \*/  
> – APMPWR\_SUSPEND, /\* 3 AD\_PWRDOWN Turn off power \*/  
> \+ APMPWR\_OFF, /\* 3 AD\_PWRDOWN Turn off power \*/  
> APMPWR\_STANDBY, /\* 4 AD\_PWRNAP Turn off if no A/C \*/  
> APMPWR\_SUSPEND, /\* (anything else) (essentially AD\_HALT) \*/  
> };

Relink the kernel and reboot:

> cd /etc/conf/cf.d  
> ./link\_unix

**Pending bug reports**:

- http://www.virtualbox.org/ticket/3953
- http://www.virtualbox.org/ticket/5096
- http://www.virtualbox.org/ticket/5164

That’s all, hope that the guys at Sun can fix this issues in future releases…