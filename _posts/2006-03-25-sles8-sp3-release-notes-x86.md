---
id: 7
title: 'SLES8 SP3 Release Notes (x86)'
date: '2006-03-25T06:07:09-04:00'
author: Ciro Iriarte
layout: post
guid: 'https://cyruspy.wordpress.com/2006/03/25/sles8-sp3-release-notes-x86/'
permalink: /index.php/2006/03/25/sles8-sp3-release-notes-x86/
categories:
    - SLES
---

Release Notes for UnitedLinux 1.0 x86 Service Pack 3  
Overview  
1\. Enhancements  
1.1 Installation  
1.2 Standards  
1.3 Platform/Hardware  
1.4 Availability  
1.5 Serviceability  
1.6 Scalability  
1.7 Performance  
1.8 Security  
1.9 Applications and Tools  
2\. Maintenance fixes  
2.1 Bugfixes  
2.2 Security fixes  
3\. New packages released with SP3  
4\. Support restrictions  
5\. Detailed ChangeLog  
6\. Known Bugs  
1\. Enhancements  
1.1 Installation

- support for multiple driver update floppies
- NFS, HTTP and FTP install modes now also supported in autoyast
- all installer/YaST2 fixes now available during installation in manual and autoyast mode when booting from Service Pack CD
- support to update any RPM with SP3 RPMs during initial installation
- support to overlay/replace any binary of the install environment
- support to read in customized partition suggestion, including LVM. Very usefull during automated installations.
- support to install the root partition on an MD RAID1
- fixed USB mouse/keyboard/cdrom problems during installation/reboot
- support DHCP network setup with more than one NIC installed
- support md device with up to 27 disks
- make EULA question timeout for automated installation
- provided docu for setting up the network installation server (see docu/howto/Network-Install-HOWTO.txt on this CD) (see also http://www.suse.de/~nashif/autoinstall/8.1/html/advanced.html)

Important Note:

- The README on the toplevel of CD1 of this Service Pack contains detailed  
    instructions on the different methods to install this Service Pack. Please  
    read them and referred READMEs carefully.  
    After applying the update please have a look at the contents of the file  
    /var/adm/rpmconfigcheck. This file contains a list of configuration files  
    which could not be automatically updated. The reason usually is that the  
    installed version was modified. These files have to be checked and the  
    configurations needs to be adjusted manually.  
    1.2 Standards
- comply with LSB 1.2 spec
- prepared for CC-EAL3 certification
- prepared for DII COE certification
- included IGMPv3 for IPv4 support
- included MLDv2 for IPv6 support

1.3 Platform/Hardware

- updated kernel to 2.4.21 mainline kernel
- moved all our patches to 2.4.21 base
- included many bugfixes from 2.4.22 mainline kernel
- integrated and hardened newest ACPI code

In some rare cases additional boot parameters might be needed.  
If you boot from this Service Pack CD for an installation and encounter  
trouble like not finding the installation CDROM please try the “Failsafe”  
install option.  
If you have trouble on reboot after updating the kernel please try to add  
“acpi=oldboot” at the boot prompt and if even this does not help then add  
“ide=nodma apm=off acpi=off”.

- full HT enablement (HP DL760, IBM x440/x445 and others)
- support many new hardware components via driver and PCI ID updates, e.g. 
    - use full speed on symbios logic2 scsi controller
    - updated Emulex lpfc driver to version 1.23a
    - updated default Qlogic driver to version 6.06.00 (qla2x00), but also included the latest certified version 6.05.00 (qla2x00-60500) the latest beta version 6.06.50 (qla2x00-60650)
    - updated Syskonnect driver sk98lin to v6.18
    - updated IPVS to 1.0.10
    - updated CIFS to 0.8.7
    - updated megaraid2 driver to v2.00.8
    - updated cciss driver to 2.4.48
    - updated e1000 driver to 5.2.13
    - updated e100 driver to 2.3.18
    - updated IBM ServeRAID ips driver to 6.10.52
    - add support for 3c905C Tornado 2 to 3c59x driver
    - updated vtune driver to 1.0.188
    - ALSA update
    - included latest OpenIPMI driver and libs
    - native SATA support for ICH5 (experimental)
    - updated channel bonding driver
- update XFS to 1.3.1
- enablement of several new machines like IBM x445
- added support for blade servers (Egenera, IBM and others)
- support to install multiple kernel RPMs in parallel
- kernel RPM release number and kernel variant queryable at runtime (uname -r)
- several improvements to ease 3rd party module creation 
    - enabled MODVERSIONS for better module insertion/interface support
    - added release-independent fallback search path in modprobe
    - provide pre-configured kernel headers for all kernel variants
    - included detailed docs about building 3rd party kernel modules and about building custom kernels (see docu/howto/Kernel-Build-HOWTO.txt on this CD or install the kernel-source package and see /usr/share/doc/packages/kernel-source/README.SuSE)
    - provided detailed docs about building custom driver update floppies (see docu/howto/Update-Media-HOWTO.txt on this CD)
- detect and report LUNs via SCSI3 for devices which support it
- updated and fixed iSCSI
- support network attached storage devices (NAS)
- support semtimedop syscall
- SCSI subsystem now compiled as loadable module to simplify updates
- many SCSI blacklist updates
- added SCSI parameters for runtime tuning blacklists, probes, etc For Service Pack 3 a number of parameters have been introduced  
    that change aspects of the way the SCSI bus is scanned by Linux.  
    Normally, none of the parameters is needed.  
    `      llun_blklst=C,B,T[,C,B,T[,C,B,T[,...]]]      `  
    Adds devices, addressed by host adapter no (C), bus number (B,  
    normally 0) and Target ID(T) to the blacklist with BLIST\_LARGELUN  
    | BLIST\_SPARSELUN. This helps to detect LUNs above 7 on devices  
    reporting as SCSI-2. It also allows LUNs to be nonconsecutive  
    for the devices addressed with this parameter.  
    \[This parameter has been present since SLES8GA.\]  
    ` 	scsi_sparselun=1       `  
    Globally assumes the LUNs numbering may be non-consecutive.  
    Potentially increases the scanning time, but makes sure all  
    LUNs of a target are detected.  
    ` 	scsi_largelun=1      `  
    Globally assumes devices can have LUNs larger than 7, independent  
    of the SCSI version they report. Normally, only SCSI-3 devices  
    should have LUNs larger than 7.  
    ` 	scsi_noreportlun=1      `  
    For SCSI-3 devices the REPORT\_LUN command is used to avoid the  
    need for a serial scan and thus avoid problems with non-consecutive  
    LUNs. This can be switched off with this parameter, which is needed  
    in case the LUN mapping of the host adapter and the Linux are  
    different. For the zfcp adapter, REPORT\_LUN is not used.  
    ` 	scsi_reportlun2=1      `  
    Also try REPORT\_LUN for SCSI devices that report as SCSI-2 and  
    are connected to a host adapter that supports more than 8 LUNs  
    per target.  
    ` 	scsi_allow_ghost_devices=N      `  
    This allows to access LUNs with a unit number smaller than N to be  
    accessed despite it reporting as offline. This is needed for some  
    EMC storage devices.  
    ` 	scsi_inq_timeout=N      `  
    This allows to set the SCSI scanning timeout in seconds.  
    Some broken hardware needs larger values than the default of 6.  
    There’s one SCSI to IDE converter known to need 25. The default  
    on ppc64 is 25.

Important note:  
The IPsec code in the kernel of Service Pack 3 has received some changes  
that make it necessary to install the freeswan package from Service  
Pack 3 as well to make it work.  
1.4 Availability

- MD driver multipathing improvements and fixes
- updated heartbeat to version 1.0.4
- updated drbd to version 0.6.6
- add hangcheck-timer module which is needed for Oracle failover
- included ocfs module from Oracle

1.5 Serviceability

- updated POSIX event logging to version 1.5.3 (evlog)
- updated linux kernel crash dump (lkcd)
- updated dprobes and Linux Trace Toolkit (dprobes+LTT)
- added kgdb in the source base
- provided documentation for using the RAS features (see docu/howto/RAS-HOWTO.txt on this CD)

1.6 Scalability

- now support by default up to 144 major numbers for up to 2000 disks
- support for optimized high resolution timers
- support page\_cache\_lock to walk the address space’s page lists
- extended NFS mount limit to 1024
- dynamically size the kernel message buffer via log\_buf\_len parameter

1.7 Performance

- support varyio for async I/O over rawio (25% performance win)
- improved InterProcess Communication (IPC) scalability
- using ReadCopyUpdate to build lock-free IPC mechanism
- huge SPECweb99 improvement via improved arch\_get\_unmapped\_area
- support O\_DIRECT via NFS (20-30% with TPC-C workloads)
- AIO and AIO+O\_DIRECT support for block devices
- alternative to remap\_file\_pages
- copyin/out patch
- dynamic configuration/tuning of scheduler via sched\_yield\_scale Added sysctl\_sched\_yield\_scale feature that allows choosing between optimization for scalability and interactiveness. By default it is switched off, so the behaviour is completely unchanged. For certain benchmarks, one wants to “echo 1 &gt; /proc/sys/sched\_yield\_scale”

1.8 Security

- include static Brazilian government certificates
- added Linux Audit System (LAuS) to the kernel
- prepared for CC-EAL3 certification
- prepared for DII COE certification
- included all security fixes (see 2.2 below)

1.9 Applications and Tools

- updated Mozilla to version 1.4
- added gedit package
- added gnome-terminal
- updated Bind (DNS) to version 9.2.2
- updated Samba to version 2.2.8a plus additional patches 
    - Windows XP clients now work out of the box and can automatically join the domain without modifications on the client side
    - handle logons restrictions of userworkstations in domain security
    - added uid/gid caching code which reduces load on winbindd
    - large file system support for smbclient
    - unicode, escape character and 32bit UID support for smbmount
- updated DHCPv6 to version v0.8
- added IGMPv3 for IPv4 support
- added MLDv2 for IPv6 support
- added network traffic shaper (wondershaper)
- updated EVMS to version 1.2.1
- fixed landscape printing in CUPS
- add support for ‘-O \_netdev’ into mount(8)
- added IBM Java 1.4.1 as optional Java (for support see 4.)

2\. Maintenance fixes  
2.1 Bugfixes  
Service Pack 3 contains all bugfixes released via the maintenance Web since  
the GA version. In addition the following packages now getting released with  
SP3 have seen bugfixes/enhancements:

- Updated aaa\_base (bugfix/feature) \[aaa\_base\] 
    - if mount does not yet support -O no\_netdev, fall back to call without.
    - pass scsi parameters from cmdline to scsi\_mod.
    - increase the initial initrd image size to work with k\_debug kernel.
    - fix mkinitrd to handle `-b /’ correctly.
    - mkinitrd: fixed splash code
    - boot.localfs: don’t mount filesystems marked as \_netdev
    - prepare mkinitrd for 2.6 kernels
    - temporarily mount shm filesystem over /etc/lvmtab.d in the linuxrc script to have more space available for lvm commands.
    - add md to list of introduced modules.
    - remove the check for xntp before writeback to hwclock
    - Remove now-obsolete oem resize support.
    - update mkinitrd to correctly add the mod\_sd module when any SCSI modules are listed in /etc/sysconfig/kernel in INITRD\_MODULES.
    - mkinitrd: dhcp: allow servername in rootpath
    - add missing mount line in rc for /proc file system
    - mkinitrd: handle line continuation and quoting in /etc/modules.conf
- Updated acl (bugfix/feature) \[acl\]  
    \[acl-devel\] 
    - Update manual pages
- Updated at (feature) \[at\] 
    - added laus patch for auditing support
- Updated attr (feature) \[attr\]  
    \[attr-devel\] 
    - Update manual pages
- Updated autoyast2 (bugfix/feature) \[autoyast2\]  
    \[autoyast2-installation\] 
    - workaround file conflict during SP3 install
    - allow setting of the partition type (primary/extended)
    - LVM/RAID can now be reconfigured using autoyast
    - fixed bug to enable swap on RAID
    - report correct RAID sizes
    - fix LVM cloning in autoyast
    - perl scripts now run during post-install phase
    - create extended partitions with id 15 when cloning
- Updated bind9 (bugfix/feature) \[bind9\]  
    \[bind9-devel\]  
    \[bind9-utils\] 
    - update to version 9.2.2; maintenance/ bugfix release
    - add NAMED\_ADD\_CONF\_FILES to /etc/sysconfig/named to handle additional configuration files get copied into the chroot jail
    - create named.conf.include if it does not exist
    - move root.hint to an extra source file, named.root
    - use /etc/named.d and /var/lib/named/master directory in the example configuration from the sample-config directory
    - add config: syslog-ng to sysconfig.syslog-named
    - add NAMED\_ARGS to sysconfig.named
    - create /etc/rndc.key with 512bit sized key in %post
    - create /etc/rndc.key in the init script if it’s missing
    - always include /etc/rndc.key in rndc-access.conf
    - add default /etc/named.d/rndc-access.conf (on install, not on update)
    - set owner of /etc/named.d and /etc/named.d/rndc-access.conf to root:
    - add SuSEconfig.named
    - add all included files to NAMED\_CONF\_INCLUDE\_FILES of /etc/sysconfig/named while update if NAMED\_CONF\_INCLUDE\_FILES is empty
    - add additional sysconfig meta data
    - unify init scripts; add one space at the end to all echos
    - fix try-restart part of init skript
    - set PATH to “/sbin:/usr/sbin:/bin:/usr/bin”
    - fix file section
    - create additional sub directories log, dyn and master in /var/named
    - add a non active logging example to named.conf
    - also create named user/group in utils preinstall
    - create named user/group in preinstall and install
    - set /etc/named.conf to root:named and 0640
    - add an example to additional info mail for dynamic updates
    - add more information to the README.{SuSE,UnitedLinux}
    - add sysconfig file for chroot jail; default is yes
    - add chroot features to init script for start and reload
    - add separate binaries to PreReq
    - add –localstatedir=/var to configure call
    - add and autocreate /etc/rndc.{conf,key}
    - move rndc binaries and man pages to utils package
    - set ownership of /var/named to root:
    - document new features in the README
    - fix init script to return correspondig message to checkproc return code
    - add additional info mail about ownership of /var/named if journal files are used
- Updated cron (feature) \[cron\] 
    - added laus patch for auditing support
- Updated cups (bugfix) \[cups\]  
    \[cups-client\]  
    \[cups-devel\]  
    \[cups-drivers\]  
    \[cups-drivers-stp\]  
    \[cups-libs\] 
    - fixed landscape problem from different creators
- Updated dante (security/bugfix/feature) \[dante\]  
    \[dante-devel\]  
    \[dante-server\] 
    - fix error trying to socksify ssh
    - add libdsocks.a to devel file list
- Updated dhcp6 (feature) \[dhcp6\] 
    - Upgraded to 0.85, added unsigned int configuration parse patch.
- Updated dprobes (bugfix/feature) \[dprobes\] 
    - dpcc and tailprint weren’t built on i386 anymore
    - enabled support for other archs (i386, ia64, ppc, ppc64, s390, s390x)
- Updated drbd (bugfix/feature) \[drbd\] 
    - upgrade to 0.6.6 which includes proper fixes for the previous hotfixes
    - correct memory barrier handling between resyncer and write IO to prevent unlikely race which could cause data corruption.
    - fix data corruption during sync if write access occurs with a blksize != 4096 bytes.
    - on upgrade, the old RPMs would remove the datadisk script. Recreate it via triggerpostun to fix upgrade bugs.
    - configure kernel source
    - fix for unacked
    - fix distribution detection.
    - build fixes for ARCH=um (no effect on other archs).
- Updated evlog (security/bugfix/feature) \[evlog\]  
    \[evlog-devel\]  
    \[evlog-snmp\] 
    - updated to 1.5.3
    - applied patch to SNMP subagent
    - fixed “rcevlog status” if snmp agent is not installed
    - suppress evlogmgr messages resulting from evlogd not running
    - tcp\_rmtlog FIFO goes into /var/run, not /opt/evlog
    - include /var/log/evlog in file list
    - fixed bracketing messed up by Opteron patch
    - fixed conflict between evlog/evlog-snmp
    - added missing /usr/share/snmp/mibs/LINUX-EVENT-LOG-MIB.mib
    - merged patches to enable SNMP access to event log
    - fixed a few more hardcoded pathnames in various source files
- Updated evms (feature) \[evms\] 
    - update to version 1.2.1 of user level tools
    - use new sysconfig metdata
    - fix some things in start script
    - add missing documentation files to RPM
- Updated freeswan (bugfix/feature) \[freeswan\] 
    - sample config: Make it working. conn %default should precede real configs.
    - ipsec look: Parse spd and sadb to produce diagnostic output
    - start KLIPS even without %defaultroute (hotplugging).
    - delete SA\_IPIP as well, otherwise we leak them with USAGI kernel space.
    - configure kernel sources before compiling.
    - reenable libinet6 usage for SLES8.
    - rename the des\_crypt.3 manpage to freeswan\_des\_crypt.3 to avoid conflict with the des\_crypt.3 from the man-pages package
    - Ignore “compress” option in config file (and warn user).
    - added patch to support MS L2TP
    - remove uninstalled secrets.
    - fix for chown usage.
    - remove libinet6 from neededforbuild
    - added missing directories to filelist
    - remove .cvsignore files
- Updated gcc (security/bugfix/feature) \[cpp\]  
    \[gcc\]  
    \[gcc-c++\]  
    \[gcc-g77\]  
    \[gcc-info\]  
    \[gcc-java\]  
    \[gcc-objc\]  
    \[libgcc\]  
    \[libgcj\]  
    \[libgcj-devel\]  
    \[libobjc\]  
    \[libstdc++\]  
    \[libstdc++-devel\] 
    - add fix for PR11693.
- Updated glibc (security/bugfix/feature) \[glibc\]  
    \[glibc-devel\]  
    \[glibc-i18ndata\]  
    \[glibc-info\]  
    \[glibc-locale\]  
    \[timezone\] 
    - do parallel “make check”, lowers build time considerably
    - add GB18030 backport from glibc 2.3.2
    - add real memcpy fix
    - add pause() backport from glibc 2.3.x
- Updated gnome-session (security/bugfix/feature) \[gnome-session\] 
    - expand gnome-session script to stop all running gnome configuration and object servers on logout
- Updated grub (bugfix) \[grub\] 
    - update to 0.93 version
    - reconsolidated graphics patches
    - now build network and non-network stage2
    - fix for machines with &gt; 1GB of mem
    - fix for hardware RAID device naming scheme
    - no graphics menu if ‘savedefault –once’ is used
    - no graphics menu if ‘hiddenmenu’ is used
    - don’t package grub-terminfo
    - made patch to force LBA off
- Updated heartbeat (bugfix/feature) \[heartbeat\]  
    \[heartbeat-ldirectord\]  
    \[heartbeat-pils\]  
    \[heartbeat-stonith\] 
    - upgrade to version 1.0.4
    - fix for heartbeat starting resources twice and concurrently in the non-nice\_failback configurations.
    - fix CCM/STONITH integration issue which could affect EVMS in cluster mode.
    - fix memory leak in heartbeat API.
    - fix for an unused variable.
    - set CCM FIFO permissions correctly.
    - handle netmask correctly in findif.
    - fix for reload bug.
    - fix for STONITH not being executed on startup if other node is down.
- Updated hotplug (bugfix) \[hotplug\] 
    - add mousedev and keybdev to the static usb modules list hotplug can not detect the needed drivers in some cases
- Updated hwinfo (bugfix) \[hwinfo\]  
    \[hwinfo-devel\] 
    - avoid pci config type detection on Gateway 920
    - updated e100 module data
    - more modules need mii.o
    - ibmsis driver info updated
    - serial mouse probing could hang in some cases
    - don’t read from cd drives that don’t exist
- Updated inn (bugfix) \[inn\] 
    - convertspool: use split -a 5
- Updated iputils (bugfix/feature) \[iputils\] 
    - add ifenslave
- Updated KERNEL (security/bugfix/feature) \[k\_athlon\]  
    \[k\_debug\] (can be found on the second Service Pack 3 CD)  
    \[k\_deflt\]  
    \[k\_psmp\]  
    \[k\_smp\]  
    \[kernel-source\]  
    The SP3 kernel has been extensively tested on high workloads and during  
    stress and benchmark tests. The following bugfixes were applied: 
    - fixed IPv6 refcounting problems that prevented module unloading
    - avoid potential reiserfs log deadlock
    - avoid potential stack overflow in SCSI mid layer
    - fix VM race in execve
    - fix memory leak in LVM
    - prevent memory corruption when reading /proc files
    - prevent stack overflow in nfsd/fh\_verify
    - fix overflow of used-bytes counter in old quota format
    - fix fs corruption when reiserfs is cleaning up lost files after crash
    - fix a signedness bug in the ACL code
    - fix potential race in exit\_mmap
    - fix to release NFS locks when process is killed
    - prevent oops in silly-delete/umount race
    - fix locking bug in md/raid1
    - fix correct setup of ioperm bitmap
    - fix potential memleak in procfs
    - fix O(1) scheduler load balancing
    - fixes for &gt;32 CPUs
    - fixes for ext3\_read\_inode() race and quota/truncate oops
    - fix signedness bug in proc-mapped-base feature
    - prevent serverworks chipset from crashing machine upon DMA errors
    - fix per-CPU interval timer smp locking bug
    - fix unshare-files bug that causes processes to lose POSIX file locks after execve(2)
    - fix overflow problem in NFSv3 decode\_fh
    - prevent possible DoS in netfilter code
    - fix TIME\_WAIT problem with nfsd fix
    - fix access to /proc/  
        /cmdline
    - increase size of SCSI sense buffer to 96 bytes
    - fix nfsd vulnerability
    - fix execve() file read race vulnerability
    - have sd\_open() schedule instead of spinning hard
    - prevent memory corruption in copy\_namespace
    - fix deadlock in IPC SHM locking
    - remove SMP-unsafe check in \_\_remove\_inode\_page
    - fix SMP races in floppy driver
    - fix kernel panic with pptpd when mss &gt; mtu
    - fix possible DoS-Attack through /dev/console (TIOCCONS)
    - fix console redirect bug
    - fix incorrect memcpy in ioports fix
    - prevent kmalloc deadlock on LVM with lvm\_mp\_private struct
    - prevent IP ID wraparound in extremely constructed situations
    - fix retry on short packages for NFS server over TCP
    - fix NFS ACL checking problem which prevented access
    - avoid race condition in submit\_bh
- Updated kdelibs3 (bugfix/feature) \[kdelibs3\]  
    \[kdelibs3-cups\]  
    \[kdelibs3-devel\] 
    - add ICP-Brasil CA
    - fix for konqueror to render indented lists correctly (for DII-COE cert)
- Updated linux-iscsi (bugfix/feature) \[linux-iscsi\] 
    - update to version 3.4.0.3
    - port patch to use internal syscall iface to 3.4.0.3.
    - add patch from NetApp
    - create an individual /etc/initiatorname.iscsi in %post
    - enhance init script
    - add missing dir to filelist
- Updated lkcdutils (bugfix/feature) \[lkcdutils\]  
    \[lkcdutils-netdump-server\] 
    - update to CVS lkcdutils
    - fixed LKCD lkcd\_netconfig
    - fixed netdump support
    - fix to display bitfields on BE archs
    - support for dynamic log\_buf\_len
    - fixed fillup to update DUMP\_FLAGS to the new format
    - fix for detecting PAE in the dumps
    - fix for parsing dumps
    - add boot.lkcd script
- Updated modutils (feature) \[modutils\] 
    - support new /lib/modules/’uname -r’ structure
    - support new override path
- Updated mozilla (feature) \[mozilla\]  
    \[mozilla-calendar\]  
    \[mozilla-devel\]  
    \[mozilla-dom-inspector\]  
    \[mozilla-irc\]  
    \[mozilla-mail\]  
    \[mozilla-spellchecker\]  
    \[mozilla-venkman\]  
    \[mozilla-xmlterm\] 
    - updated Mozilla to 1.4 final + more CVS patches
    - updated enigmail to 0.76.5
    - added ICP-Brasil CA
- Updated nfs-utils (bugfix/feature) \[nfs-utils\] 
    - fix statd for ha-nfs (add STATD\_HOSTNAME)
- Updated ngpt (feature) \[ngpt\]  
    \[ngpt-devel\] 
    - update to ngpt 2.2.2
- Updated openssl (feature) \[openssl\]  
    \[openssl-devel\] 
    - add root certificate for the ICP-Brasil CA
- Updated pam (bugfix) \[pam\]  
    \[pam-devel\] 
    - fix unresolved symbols and segfault of pam\_xauth.so
- Updated pam-modules (bugfix/feature) \[pam-modules\] 
    - pam\_pwcheck: don’t print wrong error if opasswd file does not exist yet.
    - fix pam\_pwcheck to not modify global PAM data.
    - backport patch for pam\_unix2 which allows forcing root to change the password at next login
- Updated parted (feature) \[parted\] 
    - update to version 1.6.6
- Updated pciutils (feature) \[pciutils\]  
    \[pciutils-devel\] 
    - updated pci.ids
- Updated ps (bugfix/feature) \[ps\] 
    - update procps to 3.1.11 and psmisc to 21.3 to work with newer kernels
    - make ps shut up when fed with wrong parameters
    - fix “#C” display problem with more than 99 CPUs
    - top: fix process size overflow at 4G
- Updated quota (bugfix/feature) \[quota\] 
    - update to version 3.08
    - fix path in init scripts
    - move quotacheck binary to /sbin as /usr maybe not mounted at boot.quota
- Updated raidtools (bugfix/feature) \[raidtools\] 
    - up to 1.00.3 (allows up to 27 disks in a set)
    - fix crash of mkraid if /etc/mtab does not exist
    - updated HowTo
- Updated reiserfs (bugfix/feature) \[reiserfs\] 
    - update to 3.6.10
    - make -a imply -q
- Updated samba (bugfix/feature) \[samba\]  
    \[samba-client\]  
    \[samba-vscan\] 
    - update to version 2.2.8a
    - Windows XP clients will no longer need a patch and work out of the box
    - remove tdbtorture from package on request of the Samba team
    - remove /etc/logrotate.d/samba as it conflicts with /etc/logrotate.conf
    - add patch to handle logons restrictions of userworkstations in domain security
    - move /var/log/samba and /var/run/samba to samba-client
    - add patch for smbclient to get a working -TI option
    - add nss-soname
    - add patches for smbmount; this includes LFS, unicode, escape character and 32 bit uid suppprt
    - add nmbstatus utility
    - add schannel feature from Volker Lendecke
    - move winbind init script and rc sysm link to the client package
    - remove superfluous linkvfs patch
    - activate root = administrator admin in smbusers by default
    - add smbprngenpdf
    - autocreate samba.opts.ini while build
    - add new sysconfig tags
    - cleanup %post script part which takes care of old configuration location
- Updated scsi (bugfix/feature) \[scsi\]  
    \[xscsi\] 
    - update to scsidev-2.31
    - update rescan-scsi-bus.sh to support LUNs larger than 9
    - new option –nooptscan to always scan all LUNs, even if LUN 0 is not found in rescan-scsi-bus.sh
    - add sysconfig metadata
- Updated scsirastools (bugfix/feature) \[scsirastools\] 
    - update to scsirastools-1.4.3
    - 64 bit cleanliness
    - docu updates
    - sgmode: adjust format dev page if block size changes
    - sgraidmon: return value, debug log, check for last dev in raid
    - sgafte: new util
    - mdevt: grub boot images are in menu.lst
    - support for 12byte serial numbers
- Updated shadow (feature) \[shadow\] 
    - added laus patch for pwdutils and shadow for auditing support
- Updated strace (bugfix/feature) \[strace\] 
    - update to strace 4.4.98
- Updated sysconfig (bugfix) \[sysconfig\] 
    - fix the path to vconfig
    - set MTU after the interface is up
- Updated sysstat (bugfix/feature) \[sysstat\] 
    - fix for systems with more than 32 cpus and a lot of memory
    - be more descriptive in an error message
    - added LSB comments to init script
    - increased /proc/stat line size from 1024 to 8192 for systems with lots of disks
- Updated sysvinit (bugfix) \[sysvinit\] 
    - change detection of serial versus terminal lines
- Updated tcpdump (bugfix) \[tcpdump\] 
    - tcpdump-qeth wrapper script has been obsolete by libpcap workaround
- Updated ucdsnmp (bugfix) \[ucdsnmp\] 
    - init script has to sleep before starting the agents, not after
- Updated unitedlinux-release (feature) \[unitedlinux-release\] 
    - add PATCHLEVEL = 3 entry to /etc/UnitedLinux-release
- Updated util-linux (feature) \[util-linux\] 
    - add support for -a -O \_netdev
    - add patch for noreserved option for NFS
- Updated xf86 (bugfix) \[xf86\] 
    - disable sis.o module in km\_drm (it has unresolved symbols) and removed a bad hack in Makefile.module.
    - make sux work even if no network available
    - workaround in sux due broken gnome session managment
- Updated xfsprogs (bugfix/feature) \[xfsprogs\]  
    \[xfsprogs-devel\] 
    - synchronization with kernel in SP3.
    - removed patch where mkfs.xfs defaults to create filesystem with block size=page size.
    - many other fixes (see CHANGES in doc directory).
- Updated xntp (bugfix) \[xntp\]  
    \[xntp-doc\] 
    - fix bug in ntp-4.1.1-noroot.patch that made ntpd ignore an existing drift file instead of reading it.
- Updated yast2-bootloader (bugfix) \[yast2-bootloader\] 
    - do not prevent modules cdrom and ide-cd in initrd
    - do not add (hd9) and higher to GRUB’s device map because of some problems
- Updated yast2-mouse (bugfix) \[yast2-mouse\] 
    - do not call XF86Mouse::update when no mouse is detected
    - prevent probing in Save function
    - do not reprobe mouse in continue mode
- Updated yast2-online-update (bugfix) \[yast2-online-update\] 
    - fix calling patch CD update from ncurses YaST control center
    - mark /etc/suseservers as %config(noreplace) so that it doesn’t overwrite a user-generated file
- Updated yast2-printer (bugfix/feature) \[yast2-printer\] 
    - default queue setting without any environment variable
    - allowed queue names with upper letters
- Updated yast2-storage (bugfix) \[yast2-storage\] 
    - fix rounding error in displaying max lvm lv size
- Updated ypserv (bugfix/feature) \[ypserv\] 
    - update to version 2.9.91
    - fix problems with svc\_run

2.2 Security fixes  
Service Pack 3 contains all security fixes released via the maintenance Web  
since the GA version.  
3\. New packages released with SP3  
The following new packages have been introduced with Service Pack 3:

- IBMJava2-JAVACOMM\_1\_4
- IBMJava2-JRE\_1\_4
- IBMJava2-SDK\_1\_4
- OpenIPMI
- OpenIPMI-devel
- gedit2
- gnome-terminal
- ibmusbasm
- laus
- laus-devel
- libzvt2
- libzvt2-devel
- mkisofs
- pam-laus
- perl-Curses
- perl-XML-DOM
- perl-XML-Generator
- perl-XML-RegExp
- syslinux
- ttf-arphic
- ttf-arphic-bkai00mp
- ttf-arphic-bsmi00lp
- ttf-arphic-gbsn00lp
- ttf-arphic-gkai00mp
- wondershaper

Important Note:  
These packages are provided on the Service Pack 3 CDs but depending on the  
installation method you use these may not get automatically installed. Please  
use “rpm -U ” to install any of these packages. The  
ttf-arphic\* packages can be found on the second Service Pack 3 CD.  
4\. Support restrictions  
For support of the following packages we recommend to contact the manufacturer  
of the respective piece of software directly:

- IBMJava2-JAAS
- IBMJava2-JAVACOMM
- IBMJava2-JAVACOMM\_1\_4
- IBMJava2-SDK
- IBMJava2-SDK\_1\_4
- acroread
- avm\_fcdsl
- java2

5\. Detailed ChangeLog  
The file “ChangeLog” in the toplevel of CD1 contains a summary of all the  
changes that were made for these updated packages. This gives you a good  
highlevel view of the changes and should be sufficient in most cases.  
You can of course always get the very detailed technical information about any  
package changes from the RPMs themselves by doing  
`         rpm --changelog -qp <FILENAME>.rpm `  
where .rpm is the name of the rpm.  
6\. Known Bugs

- tg3 driver and jumbo frames (MTU 9000) There is an issue with the tg3 driver when a MTU of 9000 is defined for the interface (e.g. ifconfig eth0 mtu 9000). The network connection may be lost. Please use the bcm5700 driver if you configure such large MTUs.