---
id: 8
title: 'SLES9 SP3 Release Notes (x86)'
date: '2006-03-25T06:08:33-04:00'
author: Ciro Iriarte
layout: post
guid: 'https://cyruspy.wordpress.com/2006/03/25/sles9-sp3-release-notes-x86/'
permalink: /index.php/2006/03/25/sles9-sp3-release-notes-x86/
categories:
    - SLES
---

Release Notes for SUSE LINUX Enterprise Server 9 for x86 Service Pack 3 SuSE Linux Maintenance Web (3f42148c63f09f8204b32136f311a48d)

|  | applies to |
|---|---|
|  |

**Package**: SLES-9-SP-3-i386-GM-CD1.iso  
SLES-9-SP-3-i386-GM-CD2.iso  
SLES-9-SP-3-i386-GM-CD3.iso  
**Product(s)**: SUSE CORE 9 for x86

**Release:**  20051222  
**Obsoletes:** none  
**SP3 Release Notes&gt;**  
**Note: In addition to these Release Notes you find extensive documentation on CD1. The file `NEWS` details on the new features, updates and fixes in Service Pack 3. A 800+ page manual, numerous HOWTOs and special hints for certain hardware is found in the folder `docu`.**  
These release notes are structured as follows:

- Issues applying for SP3 exclusively.
- Original release notes as shipped with SLES9 GA. 
    - General: Information that everybody should read.
    - Update: Explains changes that are not mentioned in the Admin Guide, Chapter 2.
    - Installation: Additional pertinent information for the installation.
    - Updates and Features: This sections contains a number of technical changes and enhancements for the experienced user.
    - Providing Feedback

If you intend to install the SLES9 GA release, skip the following section “SP3 Release Notes” and start reading below with the “GA Release Notes” section.  
 **Installing with SP3**  
SP3 is just another install CD. It is important to ensure that you either boot of it directly or copy the file “driverupdate” to the installation server.  
**SPident Reports the Service Pack Level**  
SPident is a tool to identify the Service Pack level of the current installation.  
SPident may report that the system has not reached the level of Service Pack 3. This happens, when so-called “optional” updates, which will not be automatically installed by YOU, are not manually selected during update. If you use or need any of these packages which have optional updates you should select these in order to reach SP3 level.  
**Included support for Oracle Cluster Filesystem 2 (ocfs2) for limited use cases**  
At the time of this release notes support is limited to the following conditions:

- x86, AMD64 &amp; Intel EM64T, Itanium, IBM POWER, IBM S/390 &amp; zSeries hardware platform
- valid support agreement with Novell and Oracle
- use as a home for Oracle RAC (${ORACLE\_HOME}, no general purpose use)

Support conditions may be extended over time. Please contact your Novell sales or support representative about the current status.  
**Microsoft Windows(R) or Samba Server as Installation Server**  
If you use a Microsoft Windows system or a Samba server to share the SLES 9 SP 3 installation source, it might happen that the download fails after several packages. In this case ignore the error message and restart the download and the install process. Then the remaining packages are downloaded and installed.  
**Systems with PERC3 or PERC4 RAID controllers**  
To update a GA version to SP2 you need to boot with the SP2 CD1. The ‘Patch CD update’ will not work on these systems.  
An update from SP1 to SP2 can be made with any of the documented update methods.  
**Persistent device name support**  
SLES9 SP3 supports persistent device names. Device names are handled as symbolic links under /dev/disk/by-id, /dev/disk/by-path, and /dev/disk/by-name. Please refer to the manual for details about persistent device names.  
Whenever a device node is required to access a device the symbolic links can be used instead of the real device node. This allows for persistent device name handling across reboots.  
In general, it will be sufficient to edit /etc/fstab to refer to the persistent device names instead of the real device nodes. If, however, the device is to be used during boot additional steps might be required:

- (x86 only) grub has to be used as boot loader. lilo is not capable of handling changed device assignments
- The boot kernel commandline has to be changed to refer to the persistent device name; ie the parameter ‘root=’ has to be modified.
- A new initrd should be generated by calling ‘mkinitrd’ after changing /etc/fstab.
- The boot loader might be required to be reinitialized.
- When using EVMS the ‘ignore\_sysfs’ option has to be set in evms.conf

**Using SCSI or hotplug devices may lead to boot failure or mount problems**  
On reboot, SCSI or hotplug devices may be assigned to different device file names than before. If the root filesystem moved to a different device name, the kernel will not find it and fail booting.  
Workarounds:  
For a root filesystem use `mount by volume label`, see below. For all other filesystems configure `mount by UUID` using YaST2:

- In YaST2 go to the Partitioner
- For every SCSI device partition `/dev/sd?` with a mount point, go to `Edit...` -&gt; `Fstab Options` and select `Mount in /etc/fstab by  UUID`.

Using `mount by volume label` for root filesystem:

- Assign a volume label to the root filesystem and activate `mount by  volume label`  
    Go to the YaST2 Partitioner. Select the root filesystem (`Mount on /`) and go to `Edit`, then `Fstab Options`. Check `Mount  in    /etc/fstab by Volume label`. Enter a label in the field `Volume  Label`, e.g. `rootvollabel`. Be sure to use a volume label that is not used by any other volume in the system. Commit changes (press `Ok`, `Ok`, `Next`).
- Set up the `root=` kernel parameter in the bootloader configuration  
    Go to the YaST2 Boot Loader Setup. Press `Edit Configuration    Files`. In the line that starts with `append =`, add `root=LABEL=rootvollabel` to the kernel command line. `rootvollabel` is the label you assigned to the root filesystem above. Commit changes (press `Ok`, `Finish`).

**Using the Rescue System on Systems with Many Devices**  
The rescue system contains device nodes for a limited number of devices. If your system has more devices, use the command  
`udevstart` on the command line. This creates the missing device nodes in `/dev` for all devices that are listed in `/sys`.  
**AppAmor on SLES9 SP3**  
SLES9 SP3 includes a complete version of Novell AppArmor. It will be installed by selecting the following packages for installation via the package selection tool in YaST:

- subdomain-parser
- subdomain-parser-common
- libimmunix
- subdomain-profiles
- subdomain-utils
- yast2-subdomain
- subdomain-docs

Once installed you can enable/disable the AppArmor service and configure your security profiles from within YaST by selecting the Novell AppArmor icon.  
**Apache Modules util\_ldap and mod\_auth\_ldap**  
The apache modules `util_ldap` and `mod_auth_ldap` have been updated from 2.0.49 to 2.0.52 level, because of the number of bugs fixed in these modules. They are still declared experimental by the authors. The update causes a minor binary incompatibility in the API exposed by the `util_ldap` module. Only third-party software built directly on top of `util_ldap` is affected by this incompatibility. There is \*no\* incompatible change in the functionality provided by the two modules or in their configuration.  
**glibc ldd output changes in SP3**  
The ldd output for dynamic binaries changed between SP2 and SP3. The symbolic link for the dynamic linker is not shown anymore. Applications (like mkinitrd) that parse the ldd output must be updated.  
**Using the Rescue System with kernel modules**  
On some architectures no suitable kernel modules exist in the rescue system. In this case, use the parameter  
`insmod=<kernel-module>` on the kernel command line (the boot prompt) to load `<kernel-module>`. Example:  
`insmod=dm_mod` The parameter `insmod=<kernel-module>` may be given several times to load several kernel modules.  
**GA Release Notes**  
These release notes cover the following areas:

- General: Information that everybody should read.
- Update: Explains changes that are not mentioned in the Admin Guide, chapter 2.
- Installation: Additional pertinent information for the Installation.
- Updates and Features: These sections contains a number of technical changes and enhancements for the experienced user.
- Providing Feedback

**General**  
**Updated SLES 9 manuals and translations of YaST messages**  
You will find the SLES 9 manuals in pdf format on CD1 in the directory “docu”. They contain a vast collection of valuable information. Please read them as they may answer many questions for you. Translations for YaST are also included.  
Feedback on documentation and translations should be mailed to  
` documentation@suse.de ` **Polish language support**  
If Polish language support is needed, please make sure to install the packages `kde3-i18n-pl` and `yast2-trans-pl`. You have to select them manually from the selection list.  
**3-D Support for nVidia Graphics Cards**  
The RPM packages `NVIDIA_GLX` and `NVIDIA_kernel` for the nVidia driver with 3-D support are no longer available. To install the nVidia driver, use the nVidia-driver patch in YOU (YaST Online Update). The drivers for 2D support are still included in SLES.  
**Removable Media / subfs**  
Removable media are now integrated via subfs. It is not necessary to mount the media manually. A `cd /media/*` triggers the automatic mounting. Note that media cannot be ejected while a program is accessing them.  
**vmware Installation**  
If you install within vmware, you should disable acceleration in vmware: `Edit-> Virtual Machine Settings -> Options -> Advanced -> Disable  acceleration`  
**Globus Toolkit 2.0**  
The Globus Toolkit 2.0 was part of SUSE Linux Enterprise Server 8. Because of major changes in the Globus TK API and of binaries we have decided to not include Globus Toolkit 2.x or 3.x into SUSE Linux Enterprise Server 9. Support for the Globus Toolkit is available through a consulting agreement. Please contact http://www.suse.com/contact for available offerings.  
**CIFS**  
The Common Internet File System (CIFS) which is shipped together with the Kernel is currently not supported. The current implementation is not stable enough to work in a production environment.  
**Update**  
**Network Device Setup**  
The network device setup has been changed. Previously the configuration of a non-existing interface triggered initialisation of the hardware. Now, new hardware is searched for and initialised first, which then triggers the setup of the new network interface.  
Additionally new names are introduced for the configuration files. Since the name of a network interface is created dynamically and the usage of hotplug devices increases more and more, a name like ethX is not usable anymore for configuration purposes. Therefore we now use unique descriptions like the MAC-address or the PCI slot for naming of interface configurations.  
Note: You can use interface names once they are present. ifup eth0 / ifdown eth0 still works.  
The configuration for devices is found in /etc/sysconfig/hardware. The interfaces these devices provide is found as usual (only with different names) in `/etc/sysconfig/network`.  
An extended README is available under /usr/share/doc/packages/sysconfig/README.  
**DHCP-Server**  
If the DHCP daemon is set to start at boot time and the system is updated from SLES8 to SLES9, this setting will be lost during the update process due to a packaging bug. To re-enable starting of the DHCP server at boot time, use the command `chkconfig -a dhcpd` or, alternatively, the YaST2 runlevel editor.  
**Sound configuration**  
After an update from an older distribution the sound cards will have to be reconfigured. This can be done using the sound module of YaST2. Invoke YaST as user `root` using the command `yast2 sound`.  
**Non UTF-8 filenames**  
Files on filesystems created by 9.0 and older distributions (when not set otherwise) use non-UTF-8 encoding. If these file names contain non ASCII characters, they will be garbled on SLES 9 and later versions. One fix is to use the convmv script which changes the encoding of the files to UTF-8.  
**XML Stylesheets and DTDs**  
The FHS now requires XML resources (DTDs, stylesheets, etc.) to be installed in `/usr/share/xml`. Therefore, some directories are no longer available in `/usr/share/sgml`. If you encounter problems, modify your scripts or makefiles or use the official catalogs (especially `/etc/xml/catalog` or `/etc/sgml/catalog`).  
**Codepage with mounting VFAT partitions**  
When mounting VFAT partitions the parameter formerly called `code=` must be changed to `codepage=`. If mounting a VFAT partition causes problems, check if the file `/etc/fstab` contains the old name for the parameter.  
**Apache 1.3 has been replaced by Apache 2**  
The apache web server (version 1.3) has been replaced by apache2 (version 2.0.49). A system update on a machine with a HTTP server installation will remove the apache package, install apache2 after which will need to adapt your setup manually, because there is no automated facility available.  
Configuration files that were under `/etc/httpd` are now in `/etc/apache2`. Apache2 requires either package `apache2-prefork` (recommended for stability) or `apache2-worker`.  
**During update there may be some conflicts requiring manual attention**  
Known issues:

- horde requires either apache2-mod\_php4 or apache-mod\_php4. In this case either deinstall horde (if you do not need it), or select the mod\_php4 package belonging to the Apache version you want to use.
- dprobes conflicts with oprofile (over libbfd) In this case please chose deinstallation of dprobes. dprobes is not provided with SLES 9.

**Using SAMBA with LDAP**  
If you used Samba on SLES 8 with SAMBA\_SAM set to “ldap” in /etc/sysconfig/samba you need to migrate your Samba LDAP configuration to the new Samba 3 LDAP schema as included in SLES 9.  
**Raw Devices**  
There have been significant changes in the implementation of raw devices. For more details, see `/usr/share/doc/packages/util-linux/README.raw` which is provided in the `util-linux` package.  
**Installation**  
**Some systems might not install with the default settings.**  
In this case first try the “Installation – ACPI Disabled” option, and if this doesn’t work either, choose the option “Installation – Safe Settings”.  
Please report these cases via http://www.suse.com/feedback.  
**Emulex Controller**  
Please use the following minimum firmware revisions on Emulex hardware.  
```
LP10000, LP10000DC, LP10000ExDC                 1.90a4 LP1050, LP1050DC, LP1050Ex                      1.80a1 LP982, LP9802                                   1.81x1 LP9000, LP9002C, LP9002DC, LP9002L, LP9402DC    3.90a7 (3.92a2 for LP9002) LP8000, LP8000DC, LP850                         3.90a7 (Dragonfly >= 2.00),  3.30a7 (Dragonfly   To update the firmware of your Emulex hardware, install the Emulex Applications kit from here:<br></br>
` http://www.emulex.com/ts/index.html ` And use either the lputil (text menu) or HBanywhere (gui) tools. You should also check the OEM page for information about your specific OEM adapter:<br></br>
` http://www.emulex.com/ts/docoem/framibm.htm ` <strong>Installing with an FTP-Server</strong><br></br>
If you use an FTP-Server to provide the CDs for installation, there is a restriction for the path you specify during the installation. Currently, you may only specify relative paths. That means that every path specified starts at the login directory of the ftp server. There is no difference whether you use a personal or anonymous login.<br></br>
<strong>Same CD requested twice</strong><br></br>
Depending on the selection you chose it is possible that some CDs have to be inserted twice during the installation process. This is a known issue, but due to dependencies it cannot always be avoided. A workaround is to install via network or harddisk instead of CDs.<br></br>
<strong>PCI Hotplug</strong><br></br>
To support real PCI hotplug on systems with AMD or Intel processors, the  `acpiphp` kernel module needs to be loaded by the `pci.rc` script. You can enable this by setting the sysconfig variable `HOTPLUG_DO_REAL_PCI_HOTPLUG=yes`.<br></br>
During installation, YaST will write a configuration file which contains the  module to load for a specific PCI  slot:<br></br>
`/etc/sysconfig/hardware/hwcfg-bus-pci-0001:d0:01.0` If the card in this PCI slot is replaced with a different type of card, the required module may not match anymore. As a result, no driver for the new card will be loaded. Please remove all `/etc/sysconfig/hardware/hwcfg-bus-pci-*` files, the  PCI hotplug scripts will always load  the correct module, even without an explicit hardware configuration file.<br></br>
<strong>Setting up an installation server for network installations</strong><br></br>
If you have a SLES9 already installed, use the YaST installation-server module to create a network install source. It can be found below `Misc - Installation Server` in the YaST main screen.<br></br>
Note: the SLES9 GA version of the YaST installation-server module can not integrate SLES9 service pack iso images. This bug was fixed in SLES9 SP1. Either upgrade the server to SP1 or newer, or just update the yast2-instserver.rpm:<br></br>
` rpm -Uvh /SP1-CD1/suse/noarch/yast2-instserver-2.9.22-0.2.noarch.rpm ` Restart YaST after the yast2-instserver package update.<br></br>
Every new service pack CD provides an updated rescue system on CD1/boot/rescue. To use this new rescue system on a YaST generated installation source, remove the 'boot' symlink in the toplevel directory.<br></br>
` rm boot  mkdir boot  cp SUSE-SLES-Version-9/CD1/boot/root ./boot/root  cp SUSE-SLES-9-Service-Pack-Version-2/boot/rescue ./boot/rescue ` To manually set up an installation Server for installations via NFS/FTP/HTTP the CDs have to be copied into a special directory structure.<br></br>
Go to a directory of your choice and execute the following commands:<br></br>
`mkdir -p installroot/sles9/CD1` `# now copy the contents of SLES CD1 into this directory` `mkdir -p installroot/core9/CD1` `# now copy the contents of SLES CD2 into this directory` `mkdir -p installroot/core9/CD2` `# now copy the contents of SLES CD3 into this directory` `mkdir -p installroot/core9/CD3` `# now copy the contents of SLES CD4 into this directory` `mkdir -p installroot/core9/CD4` `# now copy the contents of SLES CD5 into this directory` `mkdir -p installroot/core9/CD5` `# now copy the contents of SLES CD6 into this directory` `mkdir -p installroot/sp2/CD1` `# now copy the contents of SLES SP2 CD1 into this directory` `mkdir -p installroot/sp2/CD2` `# now copy the contents of SLES SP2 CD2 into this directory` `mkdir -p installroot/sp2/CD3` `# now copy the contents of SLES SP2 CD3 into this directory` `cd installroot` `mkdir boot` `ln -s ../sles9/CD1/boot/root boot/root` `ln -s ../sp2/CD1/boot/rescue boot/rescue` `ln -s sp2/CD1/driverupdate driverupdate` `ln -s sp2/CD1/linux linux` `ln -s sles9/CD1/content content` `ln -s sles9/CD1/control.xml control.xml` `ln -s sles9/CD1/media.1 media.1` `mkdir yast` `echo "/sp2/CD1 /sp2/CD1" > yast/instorder` `echo "/sles9/CD1 /sles9/CD1" >> yast/instorder` `echo "/core9/CD1 /core9/CD1" >> yast/instorder` `echo "/sp2/CD1 /sp2/CD1" > yast/order` `echo "/sles9/CD1 /sles9/CD1" >> yast/order` `echo "/core9/CD1 /core9/CD1" >> yast/order` If you are now asked for the installation directory just specify<br></br>
`installroot` If you want to set up an MS windows system as an install server go to the directory dosutils/install. There is a script `install.bat` that will create the structure and asks you for the CDs. There are also the files `instorder` and `order` that have to be copied to the  directory `\suseinstall\yast`. Before you copy the `order` file please replace the Variables UserAccount, PASSword and IP-Number with the respective values of your MS windows machine. During the installation process you only need to specify the share suseinstall.<br></br>
If you use a SAMBA-Server as installation server, simply use the commands mentioned above to create the appropriate structure. Use the `instorder` and `order` files from `dosutils/install` and replace the Variables UserAccount, PASSword and IP-Number with the respective values. The following shares need to be exported:<br></br>
`installroot` (the directory installroot)<br></br>
`sles9-CD1` (the directory installroot/sles9/CD1)<br></br>
`core9-CD1` (the directory installroot/core9/CD1)<br></br>
`core9-CD2` (the directory installroot/core9/CD2)<br></br>
`core9-CD3` (the directory installroot/core9/CD3)<br></br>
`core9-CD4` (the directory installroot/core9/CD4)<br></br>
`core9-CD5` (the directory installroot/core9/CD5)<br></br>
`sp2-CD1` (the directory installroot/sp2/CD1)<br></br>
`sp2-CD2` (the directory installroot/sp2/CD2)<br></br>
`sp2-CD3` (the directory installroot/sp2/CD3)<br></br>
<strong>Problems with "xhost +" to display remote X sessions on your local screen</strong><br></br>
This is only relevant if you control an installation over a network and want to display your remote X or YaST session on your local display. On some Linux/Unix-Systems it is no longer sufficient to enter the command "xhost +" to grant access to the local X-Server. For security reasons the X-Server no longer listens on port 6000. To verify whether the X-Server still listens on port 6000 enter the command:<br></br>
`netstat -an | grep 6000` If the line<br></br>
`tcp    0      0 0.0.0.0:6000     0.0.0.0:*   LISTEN` does not show up, the server is not listening. In this case you can either enable port 6000 or use the command<br></br>
`ssh -X "Address of the system be installed"` which will always work.<br></br>
<strong>Qlogic 2310 FC adapters</strong><br></br>
If there is more than one Qlogic FC Adapter installed and they are NOT used for multipathing, the parameter `ql2xfailover=0` must be specified if the module `qla2xxx` is loaded. Otherwise the `LUNS` on the second adapter will not show up.<br></br>
The option `ql2xfailover` is deprecated and will be removed in future versions.<br></br>
<strong>Adding storage drivers after initial installation needs manual intervention</strong><br></br>
During installation, all block-device drivers for storage controllers are added to an "initial ramdisk". This ensures accessibility for attached storage at all times.<br></br>
Adding such a controller (with attached storage) at a later point in time will initially work as expected (as a side-effect of the new hot/coldplug capabilities), but later (e.g. after creating a LV on those disks) it may not function.<br></br>
To ensure system integrity at all times, we recommend to follow YaST2 standards and add the appropriate module to INITRD_MODULES in /etc/sysconfig/kernel, and then rerun /sbin/mkinitrd.<br></br>
<strong>Multipathing with MD-Devices</strong><br></br>
To upgrade MD multipathing from SLES 8 to SLES 9 please start the system with the kernel parameter "barrier=off". YaST will then offer the MD device for update.<br></br>
<strong>Multipathing with LVM1</strong><br></br>
During the update the multipathing volumes will only be recognised as standard LVM volumes.<br></br>
It is then recommended to use EVMS. EVMS will recognise LVM1 multipathing.<br></br>
<strong>Multipathing with LVM2</strong><br></br>
Please visit<br></br>
`http://support.novell.com/techcenter/sdb/en/2005/04/sles_multipathing.html` for a describtion how to setup and use multipathing.<br></br>
<strong>Updates and Features</strong><br></br>
<strong>Updated core system with latest versions/features of all packages,  e.g.</strong>
```

- kernel 2.6.5 – SUSE Linux Kernel version
- glibc 2.3.3 – main C library
- GCC 3.3.3 – GNU compiler collection
- XFree 4.3.99 – Xfree X11 graphical user interface
- KDE 3.2.1 – K Desktop Environment
- GNOME 2.4.2 – GNOME Desktop Environment
- Samba 3.0.4 – file &amp; print &amp; more services
- Apache 2.0.49 – apache webserver version 2.x
- Bind 9.2.3 – domain name server

**New and improved YAST (our install and administration tool)**

- new YaST license (GPL)
- improved/new installation methods (NFS, HTTP, FTP, VNC, ssh, SLP)
- many config modules have been added or improved: 
    - DNS – domain name server configuration front end
    - DHCP – dynamic host configuration protocol front end
    - NIS – network information service config front end
    - LDAP – LDAP server configuration front end
    - CA – certificate authority setup front end
    - VPN – virtual private network setup front end
    - Mail – mail server configuration front end
    - TFTP – tiny ftp server configuration front end
    - Install-server – configure SLES as an installation server
    - YOU-server – provide updates to other SLES servers
    - Boot-server – boot-and-deploy-other-systems setup
    - CD creation – CD image creation support
    - UML install – UserMode Linux installation front end (not available on x86\_64)
- LDAP enablement (for users/groups + DHCP, DNS and Mail config)
- Systems management enablement through CIM (providers + CIMOM)

**Next generation 2.6.5 Linux kernel with many improvements over 2.4 kernels**

- performance 
    - improved HT and NUMA support
    - better support of big SMP systems
    - fine granular locking which boosts parallel execution
    - many kernel tuning parameters (like I/O scheduler)
- scalability 
    - support more than 64 CPUs
    - support thousands of devices/disks (64bit major/minor)
    - new greatly improved block I/O layer
    - improved network stack with IPv6, IPSEC and Mobile IPv6
- hotplug support (SCSI, USB, Firewire, PCI, CPU)
- persistent device names, unified device handling through sysfs
- new record breaking memory management (objrmap, anon VMA)
- class based kernel resource management (CKRM)
- ACPI improvements (xapic on big machines, suspend to disk/RAM)
- RAS enhancements (netconsole, crash dump, dprobes, event log)
- Infiniband support

**umount.cifs permissions**  
By default umount.cifs isn’t installed setuid root. If you would like to allow users a umount of CIFS filesystems please adjust the permissions by adding:  
/sbin/umount.cifs root:root 4755  
to /etc/permissions.local and run SuSEconfig afterwards.  
**Improved HA support**

- heartbeat, drbd and multipath working with 2.6 kernel
- cluster volume manager (EVMS)
- cluster IP alias

**Full enablement and support of UTF-8**  
**Ready for the Asian market including translations and commercial fonts**  
**Inclusion of Red Carpet Enterprise daemon**  
SLES 9 includes the Red Carpet Daemon. To install the Red Carpet Daemon please execute the following command: `/usr/sbin/inst-rcd`.  
**New Type of Installation Source: SLP**  
New feature: linuxrc understands a new installation source, `slp`. If you select `install=slp` at the bootloader prompt, linuxrc will send a SLP (Service Location Protocol) request for service `install.suse` to the network and prompt you to select an entry from the list of returned URLs. See RFC 2608 and `http://www.openslp.com` for more information on SLP.  
**OpenSSH Updated to Version 3.8p1**  
The `gssapi` support has been replaced with the `gssapi-with-mic` to fix possible MITM (man-in-the-middle attacks) attacks. These two versions are not compatible. This means that you cannot authenticate from older distributions by kerberos tickets because different methods for authentication are used.  
**libiodbc has been Dropped**  
People using FreeRADIUS now have to link against unixODBC as libiodbc has been dropped.  
**Change in Resolver Library**  
Incompatible change: the resolver library treats the `.local` top level domain as link-local domain and sends multicast DNS requests to the multicast address 224.0.0.251 port 5353 instead of normal DNS requests. If you already use the `.local` domain in your nameserver configuration you will have to switch to another domain name. See `http://www.multicastdns.org` for more information on multicast DNS.  
**Wireless LAN Cards**  
Some wireless LAN cards (PrismGT, Centrino, Atmel, ACX100) need firmware to operate. Due to licensing issues we can not ship these firmware binaries. Please read `/usr/share/doc/packages/wireless-tools/README.firmware` for information on how to obtain and install the firmware.  
**Support for Intel PRO/Wireless 2100 (aka Centrino)**  
There is now experimental support for Intel Centrino WLAN adapters. The driver is not complete, WEP support and operation modes other than managed mode are missing.  
**SSH and Terminal Applications**  
When using remote access (notably SSH, telnet and RSH) between SUSE LINUX 9.1 / SLES 9(in its default configuration with UTF-8 enabled) and older systems (9.0 and lower, where UTF-8 is not enabled by default or not supported), terminal applications might display garbled characters.  
This is because OpenSSH does not forward locale settings so that system-defaults are used which might not match the remote terminal settings. This affects text mode YaST and applications run remotely as non-root user. The applications run as root are only affected when the users changes the default locales for root (only LC\_CTYPE is set by default).  
**POSIX compliant, high performance threads support (NPTL)**  
SUSE LINUX 9.1 / SLES 9 features a new pthread implementation called NPTL, which is faster and better than the old implementation called linuxthreads.  
If your program is incompatible with this new threading implementation, we also provide the old one. To switch to the old version, set the environment variable LD\_ASSUME\_KERNEL to 2.4.21 by using (e.g.) `export LD_ASSUME_KERNEL=2.4.21` in bash.  
**Applications using ncurses**  
If problems occur with ncurses based applications running on the text console then simply issuing `unicode_stop` (reverting keyboard and console from unicode mode) should usually provide a fix.  
**SuSEplugger**  
SuSEplugger now supports drive notifications and therefore does not poll the devices. Drives that fail to support notification might not react. A workaround is to enable polling to get back the old behavior.  
**Printer Configuration**  
For information about the changes with printing see `http://support.novell.com/techcenter/sdb/en/2004/03/jsmeix_print-einrichten-91.html`  
**modules.conf / modprobe.conf**  
Parameters for loadable modules have now to be placed in modprobe.conf.  
**vacation tool**  
The current version of vacation is neither 32/64 bit nor endian-safe.  
If you use this tool in mixed environments please run vacation on the mail delivering server, which is normally the NFS server, or retry with the added option -f to force the creation of ~/.vacation.db  
**YaST partitioner will fail to assign the correct partition type during repartitioning.**  
The yast2 partitioner can fail to assign the correct partition type when you repartition. On a partition that was deleted and then recreated, if you change the type on the partition YaST will assign the original partition type. This may lead to a non-booting system if the partition is part of a software RAID or LVM.  
For example, the default partition scheme sets sda1 to type PReP on ppc. If you delete and then recreate sda1 and then change the type to DOS, YaST will still set it as PReP.  
To change the partition type, boot into the rescue system. Run `fdisk  /dev/sda` (or whatever the disk device node is in your setup) and change the type using the ‘t’ command.  
**Autoloading of PCI drivers**  
Autoloading of PCI drivers is done via coldplug in SLES9. But not all drivers will be loaded automatically, because some hardware needs additional configuration options. A whitelist of known-to-be-good hardware exists in `/etc/sysconfig/hotplug  COLDPLUGING_PCI_CLASSES_WHITELIST`.  
It lists the allowed PCI classes, per default network, storage and a few more. To add also serial PCI drivers (like the Jasmine serial adapter), add a ’07’ to the list of allowed classes. After this change, the jsm driver will be loaded automatically during boot.  
`/sbin/lspci -n` lists the available PCI adapters and their class number on your system.  
**Autoloading of non-PCI drivers**  
To have a non-PCI driver like the ‘lp’ kernel module in SLES 9 automatically loaded, create a ‘hwcfg-static-0’ file in /etc/sysconfig/hardware/ directory with the following contents:  
` STARTMODE='auto'  MODULE='lp' ` The ‘-0’ can be any number.  
**Providing Feedback to our products**  
On the top level of the first CD you will find a very detailed ChangeLog. Please also read the READMEs on the CD.  
In case of encountering a bug please report it through your support contact.  
Your SUSE LINUX Enterprise Team  
**MD5SUMs**  
CD1: `286979c957693ff7c9f63a7d723c43af`  
CD2: `d31c7c830b75ace72699ce4ece3c25d0`  
CD3: `1e73f8cd2ae13174451c565e7eae6d8f`