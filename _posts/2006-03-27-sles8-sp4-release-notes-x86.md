---
id: 10
title: 'SLES8 SP4 Release Notes'
date: '2006-03-27T22:02:16-04:00'
author: ciroiriarte
layout: post
guid: 'https://cyruspy.wordpress.com/2006/03/27/sles8-sp4-release-notes-x86/'
permalink: /index.php/2006/03/27/sles8-sp4-release-notes-x86/
categories:
    - SLES
---

# Release Notes for UnitedLinux 1.0 x86 Service Pack 4

## Knowledgebase

*(Last modified: 21MAR2005)*

- - - - - -

**solutions**

Release Notes for UnitedLinux 1.0 x86 Service Pack 4  
SuSE Linux Maintenance Web (2703b9bc0638a38f2dbe780920d828a6)

| ![](http://support.novell.com/img/h_arrow.gif) | applies to |
|---|---|
|  |

**Package**: UnitedLinux-1.0-SP-4-i386-GM-CD1.iso  
UnitedLinux-1.0-SP-4-i386-GM-CD2.iso  
**Product(s)**: SuSE Linux Enterprise Server 8 for x86

**Release:**  20050321  
**Obsoletes:** none  
Release Notes for UnitedLinux 1.0 x86 Service Pack 4

 **Please note that you need the Service Pack 3  
ISOs / CDs to be able to install Service Pack 4. You always need to install  
SP3 first! You find it here:**   
[UnitedLinux 1.0 x86  
Service Pack 3](http://support.novell.com/techcenter/psdb//psdb/02b099a19e5c7a10489286a84188b3fa.html)  
However you are able to start a fresh installation from the SP4 CDs. You will  
be asked for the SP3 CDs later on then.  
Overview  
1\. Enhancements  
1.1 Installation  
1.2 Platform/Hardware  
1.3 Applications and Tools  
2\. Maintenance fixes  
2.1 Bugfixes  
2.2 Security fixes  
3\. Detailed ChangeLog  
4\. Known Bugs  
5\. MD5SUMs  
1\. Enhancements  
1.1 Installation

- all installer/YaST2 fixes now available during installation  
    in manual and autoyast mode when booting from Service Pack CD

Important Note:  
The README on the toplevel of CD1 of this Service Pack contains detailed  
instructions on the different methods to install this Service Pack. Please  
read them and referred READMEs carefully.  
After applying the update please have a look at the contents of the file  
/var/adm/rpmconfigcheck. This file contains a list of configuration files  
which could not be automatically updated. The reason usually is that the  
installed version was modified. These files have to be checked and the  
configuration needs to be adjusted manually.  
1.2 Platform/Hardware

- support many new hardware components via driver and PCI ID updates,  
    e.g. 
    - consolidated Qlogic driver to version 7.03.00 (qla2x00)
    - updated e1000-new driver to 5.6.10.1
    - updated cciss driver to latest version from 2.4.28-rc2
    - added bcm5700-new driver as 7.3.5
    - included megaide driver
    - updated IBM ServeRAID driver (ips) to 7.10.18
    - update PCI ID list for megaraid2 driver

1.3 Applications and Tools

- Updated linux-iscsi toversion 3.6.2
- Updated jfsutils to version 1.1.7
- Updated reiserfs tools to version 3.6.19

2\. Maintenance fixes  
2.1 Bugfixes  
Service Pack 4 contains all bugfixes released via the maintenance Web since  
SP3 (Service Pack 3). In addition the following packages now getting released  
with SP4 have seen bugfixes/enhancements:

- 3ddiag 
    - fixed insecure tmp file handling (Bug #33795)
    - Don't send info mail about changes on new products \[Bug #21414\]
- acl 
    - #35084: Fix a memory leak in acl\_init().
    - Fix a long standing bug in acl\_get\_file() for Default ACLs (that  
        probably was there from hour one): Default acls bigger than the  
        access acl of the same file could not be retrieved; this is very  
        unusual.
    - added change to acl.5 (EAL3)
- acroread 
    - Update to version 5.010 which has a security fix that solves  
        a problem with malformed mail containing pdf attachments  
        (see SUSE bugzilla bug #49257).
    - Security update to version 5.09  
        buffer overflow/shell meta character vulnerability  
        see bug 43788 or iDEFENSE or the heise online news
- ami 
    - Bugzilla 40452: "LTC8294-Korea: AMI IM caused Seg fault after  
        destroying one of some TextFields": apply fix supplied  
        by Mitsuru CHINEN mchinen@yamato.ibm.com.
    - add shift-ctrl-endian-problem.patch, see Bugzilla #32149.  
        Patch thanks to Mitsuru CHINEN mchinen@yamato.ibm.com.
    - Bugzilla #32272: add destroy-hanja-dialog.patch to fix segfault  
        after some operations for the candidate window.
    - Bugzilla #26766: apply 64bit and endianness patches  
        for all platforms.  
        Thanks to Mitsuru Chinen mchinen@yamato.ibm.com for noticing  
        this and his explanation.  
        Applying these patches always is necessary because the problems  
        are caused by the difference of endianness between a server and  
        a client.  
        Applying these patches for all platforms should be safe,  
        I do that in the the SuSE 9.0 packages already since June  
        and no problems occured so far.
    - fix the rest of Bugzilla #26766: make it work with mlterm  
        as well.  
        Again many thanks to Mitsuru Chinen mchinen@yamato.ibm.com for  
        the explanation how to fix it.
    - Fix bigendian problem #27181 for all ppc, ppc64, and s390 too.
    - Bugzilla #27181: fix endianness problem to make ami  
        detect KDE correctly.
    - Bugzilla #26766: apply fix from Mitsuru Chinen for 64bit  
        architectures.
- apache-devel 
    - security fixes from 1.3.31 \[#40611\]: 
        - CAN-2004-0174 (cve.mitre.org)  
            Fix starvation issue on listening sockets where a  
            short-lived connection on a rarely-accessed listening  
            socket will cause a child to hold the accept mutex and  
            block out new connections until another connection  
            arrives on that rarely-accessed listening socket.  
            Enabled for some platforms known to have the issue  
            (accept() blocking after select() returns readable).  
            Define NONBLOCK\_WHEN\_MULTI\_LISTEN if needed for the  
            platform and not already defined.
        - CAN-2003-0987 (cve.mitre.org)  
            Verification as to whether the nonce returned in the  
            client response is one we issued ourselves by means of a  
            AuthDigestRealmSeed secret exposed as an md5(). See  
            mod\_digest documentation for more details.  
            The experimental mod\_auth\_digest.c does not have this  
            issue.
        - CAN-2003-0020 (cve.mitre.org)  
            Escape arbitrary data before writing into the  
            errorlog. Unescaped errorlogs are still possible using  
            the compile time switch  
            "-DAP\_UNSAFE\_ERROR\_LOG\_UNESCAPED".
    - security fix for mod\_ssl: fix buffer overflow in  
        ssl\_util\_uuencode() \[#40791\]
    - security fix (CAN-2003-0993): Allow and Deny rules with IP  
        addresses (e.g. 192.168.1.1) where parsed incorrectly on 64-bit  
        platforms with big endianness. It only affected IP addresses with  
        no netmask definition. \[#35450\]  
        [htt  
        p://nagoya.apache.org/bugzilla/show\_bug.cgi?id=23850](http://nagoya.apache.org/bugzilla/show_bug.cgi?id=23850)  
        apply the patch only on s390x.
    - security fix (CAN-2003-0542): fix buffer overflows in mod\_alias  
        and mod\_rewrite that are possible when using a regular expression  
        with more than 9 captures \[#32756\]
    - rmeove 0host entries for pidfile and logfiles, which alarmed our  
        patchrpm breakage tests
- apache 
    - security fix from 1.3.33:  
        \[CAN-2004-0940 (cve.mitre.org)\]: mod\_include: Fix potential  
        buffer overflow with escaped characters in SSI tag string.  
        \[#47740\]
    - security fix from mod\_ssl 2.8.20:  
        \[CAN-2004-0885 (cve.mitre.org)\]: fix SSLCipherSuite bypass in  
        mod\_ssl \[#47117\]
    - Applied some gaurds against invalid ctx pointers in  
        mod\_ssl. \[#33968\]  
        mod\_ssl-2.8.10-paranoid-pointer-2.diff was an unsuccessful PTF  
        previously.
    - Security fix from mod\_ssl 2.8.19: fix ssl\_log() related format  
        string vulnerability in mod\_proxy hook functions. \[#43114\]
    - security fix in mod\_proxy: Reject responses from a remote server  
        if sent an invalid (negative) Content-Length. \[#41970\],  
        CAN-2004-0492
    - use "chown -Rh" where needed after last fileutils change
    - security fixes from 1.3.31 \[#40611\]: 
        - CAN-2004-0174 (cve.mitre.org)  
            Fix starvation issue on listening sockets where a  
            short-lived connection on a rarely-accessed listening  
            socket will cause a child to hold the accept mutex and  
            block out new connections until another connection  
            arrives on that rarely-accessed listening socket.  
            Enabled for some platforms known to have the issue  
            (accept() blocking after select() returns readable).  
            Define NONBLOCK\_WHEN\_MULTI\_LISTEN if needed for the  
            platform and not already defined.
        - CAN-2003-0987 (cve.mitre.org)  
            Verification as to whether the nonce returned in the  
            client response is one we issued ourselves by means of a  
            AuthDigestRealmSeed secret exposed as an md5(). See  
            mod\_digest documentation for more details.  
            The experimental mod\_auth\_digest.c does not have this  
            issue.
        - CAN-2003-0020 (cve.mitre.org)  
            Escape arbitrary data before writing into the  
            errorlog. Unescaped errorlogs are still possible using  
            the compile time switch  
            "-DAP\_UNSAFE\_ERROR\_LOG\_UNESCAPED".
    - security fix for mod\_ssl: fix buffer overflow in  
        ssl\_util\_uuencode() \[#40791\]
    - security fix (CAN-2003-0993): Allow and Deny rules with IP  
        addresses (e.g. 192.168.1.1) where parsed incorrectly on 64-bit  
        platforms with big endianness. It only affected IP addresses with  
        no netmask definition. \[#35450\]  
        [htt  
        p://nagoya.apache.org/bugzilla/show\_bug.cgi?id=23850](http://nagoya.apache.org/bugzilla/show_bug.cgi?id=23850)  
        apply the patch only on s390x.
    - security fix (CAN-2003-0542): fix buffer overflows in mod\_alias  
        and mod\_rewrite that are possible when using a regular expression  
        with more than 9 captures \[#32756\]
    - remove 0host entries for pidfile and logfiles, which alarmed our  
        patchrpm breakage tests
- arts 
    - fix a security issue in temp file handling (by Waldo #42486)
    - Make artsdsp abort on x86\_64 when trying to run a 32 bit  
        application.
- autoyast2 
    - Bug #42979 L3: Module options not copied into installed system
    - #34437, #36278: Fixed DTD
    - #33849: creating 4 primary partitions with control created with  
        backup module not possible
    - #36459: Dont complain about needed space during partitioning,  
        this is done when configuring software
    - #33871: Added script for creating CDs from multiple sources
    - #33899: Set intial installation language
    - #33848: clone software selection correctly
    - doc updates
    - #33844: Support for LVs over RAID
- cadaver 
    - really fix security problems in libneon (#41725)
    - fix security problems in libneon (#41725)
- cups 
    - fixed problem in new passwd file generation (bugzilla#49370)
    - xpdf security fix, CAN-2005-0064 (bugzilla#49840)
    - xpdf security fix, CAN-2004-1125 (bugzilla#49463)
    - DoS attack not fixed; not affected (bugzilla#49545)
    - lppasswd security fix, CAN-2004-1268 (bugzilla#49370)
    - hpgltops security fix, CAN-2004-1267 (bugzilla#49369)
    - additional xpdf fixes CAN-2004-0888, CAN-2004-0889  
        (bugzilla#44963)
    - fixed ogonki (bugzilla#31756)
    - fixes for pdftops, CAN-2004-0888, CAN-2004-0889 (bugzilla#44963)
    - additional fixes for cupsomatic, CAN-2004-0801 (bugzilla#44233)
    - fixed security problem in cupsomatic, CAN-2004-0801  
        (bugzilla#44233)
    - fix for DoS with zero len UDP packages (bugzilla#44088)
    - fix for 64bit arthimetic/casting problems in sleep()  
        (bugzilla#40880)
    - pam2 config files now installed on non-i386 arch  
        (bugzilla#39920)
    - /usr/lib now replaced by architecture dependend path  
        (bugzilla#39385)
- cvs 
    - fix the patch for malformed Entry lines (cvs-1.12.7-exploit-fix)  
        (#42397)
    - update last patch to fix WinCVS support (20040521 version)
    - new krahmer+esser security fix for (#39773) 
        - error\_prog\_name "double-free()" (SE)  
            CAN-2004-0416
        - argument integer overflow (SK)  
            CAN-2004-0417
        - serve\_notify() out of bound writes (SK)  
            CAN-2004-0418
    - expoit-fix for malformed Entry lines. This can be exploited via  
        a buffer overflow (#39773)
    - fix pserver client side leak (#36659)
    - fix format string vulnerability (#33851)
    - added security patch for modules path (#33631)
- cyrus-sasl 
    - Bugfix ID#46847 – VUL-0: SASL environment variable local root
- devs 
    - fix permissions of /dev/perfctr (#49581)
    - create ttyS1 node for VT220 on s390\* (bug #29239)
    - create 12 iseries/vt0 nodes (#24495)
    - Remove special fb\* device numbers for SPARC, use standard one
    - makedevs.floppy: don't create devices for ix86 specific devices  
        on SPARC
- dhcp-server 
    - add another patch related to the VU#317350 fix, restricting the  
        length of client provided fqdn (for use as DDNS domain name) to  
        255 characters, as found in the dhcp-3.0.1rc14 tarball, and as  
        recommended by ISC. \[#41975\]
    - security fixes \[#41975\]: 
        - fix buffer overflow in the DHCP server that can be  
            exploited by the client by specifying multiple  
            'hostnames' to execute arbitrary code or at least crash  
            the server. VU#317350
        - add patch to use vsnprintf() instead of vsprintf() calls.  
            VU#654390
        - use mkstemp() to create temp files \[#40267\]
        - dhcrelay: add patch from Florian Lohoff (slightly  
            modified), that makes the maximal hop count of forwarded  
            packages configurable (-c maxcount), sets the default to  
            4, and rejects packages with a hop count higher than  
            maxcount (CAN-2003-0039,  
            http://www.kb.cert.org/vuls/id/149953). Add a  
            variable to /etc/sysconfig/dhcrelay to pass such  
            additional options. \[#31963\]
    - when copying include files into the chroot jail, create  
        subdirectories as needed, thus retaining the path to the files  
        (closes bug \[#28284\])
    - remove 0host filelist entries and preun creation of pid files,  
        since it catches the attention of the patchrpm breakage tests.  
        Clean up the libraries from the jail when the server is stopped.
    - Don't send update messages on UnitedLinux \[#26460\]
- dprobes 
    - Work with new grammar
- drbd 
    - Fix #43582: Build module correctly on x86\_64.
    - Upgrade to 0.6.13 to fix #42885: Data corruption if secondary  
        node fails during sync.
    - Update to 0.6.12 from upstream, most critical fixes:
    - With the non-blocking IO hints, a bug was introduced that could  
        lead to partially sent IO hints. -&gt; loss of connetion. This  
        issue is fixed now.
    - Fix for timeout when asender is dead; this could lead to a  
        "stalled" Primary.
    - Sending of IO hints is done non-blocking; this fixes blocking  
        bottom halves or bdflush and the like in low memory situations;  
        by Lars Ellenberg.
    - Finally fixed the remaining race cases where the Primary could  
        lock up when Secondary failed during sync.
    - Fail IO if not primary.
    - Reparent processes to init if parent dies.
    - We don't need kernel-source to build.
    - km\_ Makefile updated.
- enscript 
    - fix patch for CAN-2004-1186 (#49680)
    - Add three security fixes CAN-2004-1184,1185,1186 (bug #49680)
    - Adopt CAN-2004-1184 to enscript 1.6.2
- ethereal 
    - fixed security bugs in HTTP, SMB, X11 dissectors and invalid RTP  
        timestamp \[#49253\] (CAN-2004-1140, CAN-2004-1141, CAN-2005-0084,  
        CAN-2004-1142)
    - fixed missed security bugs (in SIP, AIM, SPNEGO and MMSE  
        dissectors) \[#47183\] enpa-sa-00014 (CAN-2004-0504,  
        CAN-2004-0505, CAN-2004-0506, CAN-2004-0507)
    - fixed security bugs (in iSNS, SMB and SNMP dissectors) \[#42820\]  
        enpa-sa-00015 (CAN-2004-0633, CAN-2004-0634, CAN-2004-0635)
    - added missing online help \[#39518\]
    - updated to version 0.10.3 (security update) \[#35449\]  
        \* several security fixes; enpa-sa-00013; CAN-2004-0176  
        CAN-2004-0367, CAN-2004-0365
    - fixed default filter (ipv6 problem)
    - fixed locating manuf file in /etc \[#34386\]
    - removed obsoleted patches
    - fixed security bug (in SMB dissectors);\[#33650\] enpa-sa-00012
    - fixed security bugs (in GTP,ISAKMP,SOCKS dissectors);  
        enpa-sa-00011
- file 
    - Fix some buffer overflows (bug #48576)
- freeradius 
    - added remote crasher fixes (#47389) 
        - CAN-2004-0938
        - CAN-2004-0960
        - CAN-2004-0961
    - security Fix for remote denial-of-dervice attack by sending a  
        malformed package (#33321)
- freeradius-devel 
    - security Fix for remote denial-of-dervice attack by sending a  
        malformed package (#33321)
    - security-fix for buffer-overflow in CHAP implementation  
        (#27892)
- freeswan 
    - Fix for certificate chain authentication bug (#42153)
- gawk 
    - Replace igawk with version from gawk-3.1.3 \[#33932\].
- gcc 
    - Fix using custom allocators for basic\_strings in  
        libstdc++. (#40711)
    - Integrated overlaying temp stackslots problems fix from Michael  
        Matz (LTC#7624, SUSE#39078)
    - Fix miscompilation in rdist \[#33343\].
    - Fixed double null pointer check deletion problem on  
        architectures with more than 1 CC. (#34257)
    - Make ios::copyfmt copy the imbued locale (#34327)
    - Use cmpstrsi instead of doing unsafe strcmp-&gt;memcmp  
        transformation. (#33963)
    - Don't discard GOT pointer if only used in a catch handler  
        (#33987)
    - Make loop transformation regard REG\_EQUAL notes (#34193)
    - No seperate version for ppc
- gd 
    - fixed more overflows – CAN-2004-0941 \[#47666\]
    - fixed several integer overflows \[#47666\]
- gdk-pixbuf 
    - add unresolved external reference (SuSE Bug Id #45423)
    - added patches for 
        - CAN-2004-0782 Heap-based overflow in  
            pixbuf\_create\_from\_xpm
        - CAN-2004-0783 Stack-based overflow in xpm\_extract\_color
        - CAN-2004-0788 ico loader integer overflow. (SUSE Bug  
            Id#44100)
- gdm2 
    - attach patch to prevent a possible DoS Attack in gdm  
        Bug Id #32314
    - rename the actual gdm binary (gdm-binary) to gdm for  
        rcxdm to be able to start and shutdown gdm (Bug Id#31149)
- glibc 
    - removed crap-o-matic parallel build code that fails every  
        other time, replaced it with %jobs macro
    - Add partial fix for \[Bug #48330\] (possible loop in getaddrinfo)
    - Add dns-network security patch \[Bug #47900\]
    - Use malloc for buffer in dns-host, dns-network and res\_query  
        \[Bug #47750\]
    - Add backport of backtrace functionality for ia64 \[#42870\].
    - Fix makecontext with more than 6 arguments on x86-64 \[#40546\].
    - Fix poll syscall interface \[#39587\].
    - Fixed ppc tcsetattr patch, removed unneeded hunk which breaks  
        stty.
    - Fix tcsetattr on PPC
    - Changed struct ucontext for ppc and ppc64 to fit the  
        glibc-2.3 version. Is still binary compatible  
        to both kernel and userland. LTC#5172/SUSE#32813.
    - added pt\_chown.5 man-page (EAL3)
    - Fix getgrouplist patch
    - Add getgrouplist fix for too much groups
    - AMD64: fix s\_ceill and s\_floorl
    - PPC: Fix pthread spin lock problem \[Bug #33148\]
    - IA64: Fix pthread spin lock problem \[Bug #33090\]
- gnome-vfs2 
    - Replaced insecure old extfs modules by fixed modules from mc,  
        fixed the rest (CAN-2004-0494, CRD: 04.08.2004) (#43152).
- gnome-vfs 
    - Replaced insecure old extfs modules by fixed modules from mc,  
        fixed the rest (CAN-2004-0494, CRD: 04.08.2004) (#43152).
- gpm 
    - fixed segfault, when opening console failed (bug #31970)
- gtk2 
    - added patches for 
        - CAN-2004-0782 Heap-based overflow in  
            pixbuf\_create\_from\_xpm
        - CAN-2004-0783 Stack-based overflow in xpm\_extract\_color
        - CAN-2004-0788 ico loader integer overflow.  
            (SUSE Bug Id#44100)
- heimdal 
    - fixed cross-realm vulnerability \[#37079\]
    - fixed segfault in krb5\_get\_init\_creds\_password \[#33485\]
    - fixed changing password against MIT server \[#27320\]
- htdig 
    - Fix a cross site scripting flaw as found by Michael Krax; apply  
        the patch proposed by Phil Knirsch (modified for version 3.1.6);  
        CAN-2005-0085 \[# 50238\].
    - add patch from stable (htsearch\_64.patch) to fix #49619  
        to make htsearch work
- imlib 
    - Even more additional XPM security fixes. #48061
    - Also apply the patch to the cut &amp; pasted BMP loader in  
        Imlib/.
    - Added additional overflow checks to BMP loader.
    - fixed buffer overflow in BMP loader. CAN-2004-0817,#44228
- iptables 
    - fixed uninitialised variable \[#47850\] – CAN-2004-0986
    - configure kernel source
- ircd 
    - Apply patch to prevent buffer overflow in m\_join()
- java2 
    - Added 8148528re jre (by pmladek@suse.cz) to ensure that a valid  
        plugin link to the non-vulnerable plugin is created.
    - updated to release 13 to fix privilege escalation vulnerability  
        in plugin (#48498):  
        <http://sunsolve.sun.com/search/document.do?assetkey=1-26-57591-1>
- jfsutils 
    - Update to 1.1.7 \[#49728\]
- kdelibs3 
    - protect against ftp command injection (#49034, SWAMP 101)
    - fix Konqueror Window Injection Vulnerability (#49194)
    - hide passwords in URLs when they are visible to the user
    - update patch for Frame Injection in khtml, fixing a regression  
        (wrong frames might get used)
    - fix possible Frame Injection in khtml (by Waldo #43271)
    - fix for unsecure tmp file handling (by Waldo #42486)
    - security fix telnet service (#11606)  
        files could have been overwritten or created
    - email addresses were used as direct command line argument with  
        kmail
- Kernel 
    - disable bcm5700-new test code to fix problem with unresolved  
        symbols (SUSE50674)
    - update IBM ServeRAID driver (ips.c) to 7.10.18
    - patches.common/qla2xxx-disable-fdmi: Disable FDMI for qla2xxx  
        (SUSE50738).
    - patches.common/scsi-addsingledev-online  
        patches.common/scsi-ltcbzid-12614-lvm-mp.diff  
        Fix online behaviour of SCSI-disks if  
        fcp connection is lost (SUSE50607)
    - JFS: Handle out of space errors more gracefully (SUSE50945)
    - patches.common/xattr-race-minimal-fix.diff: Fix race in xattr  
        sharing (SUSE50424).
    - fix usb-serial driver, bring it to 2.4.28 level (bug SUSE48489)  
        remove obsolete patches.common/usb-serial-palm-sched\_oops.patch add  
        patches.common/usb-serial-2.4-1.1438.6.5.patch  
        http://linux.bkbits.net:8080/linux-2.4/cset@40cef0fbpF3A\_edUhi8H  
        a2Qi09Batw add patches.common/usb-serial-2.4-1.1482.2.2.patch  
        http://linux.bkbits.net:8080/linux-2.4/cset@4186b9cdrEhF6Csz1SSx  
        9dzswhwG8Q
    - add new PCI IDs to megaraid2 driver (SUSE50720)
    - S/390: build sclp\_cpi as module (SUSE49607).
    - patches.common/natsemi-long-cable-fix: add module option  
        to disable natsemi short cable hack (SUSE46903)
    - disable old qla2xxx v6 driver for ppc64 and use new version v7
    - patches.common/xattr-sharing-bug.diff: Fix long-standing xattr  
        sharing bug (#50424).
    - update e1000-new driver to 5.6.10.1
    - consolidate qla2xxx drivers to version v7.03.00
    - add patches.common/scsi-define-task-aborted  
        Fix STATUS mask and define TASK\_ABORTED (#49150)
    - add patches.common/scsi-increase-error-timeout  
        Increase error timeout to avoid races (#49692)
    - add patches.s390/s390-tape-defcc-common  
        S390: fix tape tar or db2 backups hang (#49781)
    - add patches.s390/linux-2.4.22-s390-20-june2003-patches/\*  
        S/390: Include official IBM codedrop.
    - add patches.s390/linux-2.4.23-s390-21-june2003-patches/\*  
        S/390: Include official IBM codedrop.
    - Removed obsolete patches.
    - fix oops in generic\_file\_direct\_IO (#48909 – LTC12515)
    - JFS: remove buggy txAbortCommit, and use txAbort instead  
        (#50430 – LTC13830)
    - fix ia64 that got broken by the fix to #49896
    - Disable rawio readv/writev implementation (andrea, #48530)
    - fix potential problem with overlapping VMAs (#49896)
    - add missing check to vt resizing code (#49171)
    - UML does not have audit subsystem
    - fix race in SMP page fault handler; correct version (#49652)
    - fix audit subsystem filtering flaw (#49801)
    - fix race in SMP page fault handler (#49652)
    - add missing mmap\_sem around do\_brk calls (#49492)
    - patches.s390/s390-hsi-disable-time-delay.patch  
        Fix hipersockets (49639 – LTC13256).
    - patches.common/cmsg-compat-signedness-fix: one of the size  
        checks was wrong and broke some 32bit applications on 64bit  
        kernels (49517).
    - add some more entries to scsi\_scan blacklist (#49498)
    - patches.common/igmp-fix: use final version of fix (#48895)
    - patches.common/usb-storage-reset-device: only allow usb-storage  
        to reset if it owns the whole device (#38798, #35425)
    - patches.common/x86\_64-int80: fix roothole in x86\_64 int80  
        handler (#49210)
    - patches.common/lkcd-e1000-netpoll: provide API required by  
        LKCD netdump to e1000 driver (49083).
    - add patches.ppc/ibm-ppc64-vmx-signal.patch  
        improve vmx context switching (#47367 – LTC11883)
    - update patches.ia64/linux-2.4.21-ia64-030702  
        move the include/linux/pci\_ids.h change out of the way
    - patches.common/cmsg-compat-signedness-fix: CMSG compat code  
        needs signedness fixes too. (49047).
    - patches.common/cmsg-signedness: Fix CMSG validation checks  
        wrt. signedness. (49047).
    - patches.common/fix-ip-options-leak: Do not leak IP  
        options. (49057).
    - patches.common/igmp-fix: fix possible DoS in igmp code (#48895)
    - patches.common/serialize-dgram-read.diff: Serialize dgram read  
        using semaphore just like stream (#48427).
    - add patches.s390/qeth-transmission-failures.patch  
        Fix qeth transmission failures (48706 – LTC12756)
    - add patches.s390/linux-2.4.21-s390-20-june2003-patches/\*  
        S/390: Include official IBM codedrop.
    - add patches.s390/linux-2.4.21-s390-21-june2003  
        S/390: Include official LCS driver update
    - Removed obsolete patches.
    - patches.common/sg-sles8-fixes-update: missed one place where proc  
        output needs to drop the lock.
    - patches.common/elf-loader-setuid:  
        additional checks for elf loader vulnerability
    - patches.common/cciss-update:
    - patches.common/cciss-device-id:  
        use new PCI ID for new cciss driver (#45148)
    - patches.common/fix-aout-leak:  
        fix a.out leaking fds and memory (#48199)
    - patches.common/elf-loader-setuid:  
        fix ELF loader when handling setuid binaries (#45632)
    - patches.s390/lcs-driver-update  
        S/390 LCS network driver update (#34111)
    - patches.common/cciss-update:  
        update cciss driver to latest version from 2.4.28-rc2 (#45148)
    - patches.common/smbfs-overflows: included additional fixes (#46204)
    - patches.ia64/linux-2.4.21-ia64-030702:  
        fix trivial reject in pci.ids file
    - moved tag SLES8\_SP4\_BETA1
    - patches.common/fix-cciss-x86\_64:  
        make cciss driver at least compile on x86\_64
    - tagged SLES8\_SP4\_BETA1
    - config/\*/\*:
    - patches.common/bcm5700-new:
    - patches.common/bcm5700-new-adapt:  
        add version 7.3.5 of bcm5700 driver as "bcm5700-new"
    - patches.common/10\_try-cciss-only-4G-1:
    - patches.common/cciss-update:  
        update cciss driver to 2.4.52 instead of cloning it
    - add patches.s390/linux-2.4.21-s390-19-june2003-patches/\*  
        Update to official IBM codedrop.
    - Removed obsolete patches.
    - Added compatible ioctls for softdog (#40925).
    - Update the sg fix patch (#47458)
    - Fix leak on building SCSI command blocks (#47817)
    - add patches.common/usb-drivers-memset.patch  
        fix some memleak to userspace in some usb drivers (#47595)
    - patches.common/fix-clear\_LDT-wrong-context: clear\_LDT sometimes  
        was called in the wrong context (#47430)
    - add patches.common/cciss\_2442\_to\_2448\_x86\_64.patch  
        add patches.common/cciss\_2448\_to\_2452\_x86\_64.patch  
        update cciss also on x86\_64 (#45148)
    - add patches.ppc/ibm-ppc64-signal-set-current-state.patch  
        add memory barrier after chaning current-&gt;state (#47603 –  
        LTC11921)
    - patches.common/fix-get\_user\_pages: fix broken get\_user\_pages;  
        properly account reserved pages (#47337, #47343)
    - patches.common/scsi-complete-account: Fix SCSI io accounting  
        locking (47322, axboe@suse.de).
    - patches.common/md-resync-speed: Fix resync speed for stacked md  
        devices. (L3 #47143)
    - patches.common/md-start-array: Avoid the automatic nested md device  
        discovery if starting one array explicitly. (L3 #46966)
    - add patches.common/set\_pte-races (#46948 – LTC11574)  
        Fix threaded user page write memory ordering  
        Make sure we order the writes to a newly created page with the  
        page table update that potentially exposes the page to another CPU.
    - name new cciss driver "cciss-new" instead of "cciss\_new". Now  
        this is consistent with the handling of "e1000-new".
    - add new version 2.4.52 of cciss driver as cciss\_new (#45148)
    - Update patches.s390/linux-2.4.21-s390-18-june2003-patches/\*  
        Replaced corrupted files (Transmission error from IBM).
    - Add modversion dump file /boot/symvers-$(uname -r).gz as in 2.6  
        kernels for modversion checking.
    - add patches.s390/linux-2.4.21-s390-18-june2003-patches/\*  
        Update to official IBM codedrop.
    - Removed obsolete patches.
    - Enabled patch for #44487.
    - patches.common/smbfs-overflows: Patch from Urban Widmark to  
        fix remotely exploitable denial of service in kernel SMB code (#46204)
    - add  
        patches.s390/linux-2.4.21-s390-17-june2003-patches/linux-2.4.21-s390-17-0{7,8,9}-june2003  
        Update to official IBM codedrop.
    - patches.common/lkcd-smp-update: compilation fix for ia64.
    - add patches.common/jfs-memleak-invalidate\_metapages.patch  
        JFS: fix memory leak in \_\_invalidate\_metapages (#35499 – LTC6726)
    - add patches.ppc/ibm-ppc64-linux-2.4.21-213-set\_pte.patch  
        fix race condition between PTE set and \_\_hash\_page on PPC64  
        (#45980 – LTC11381)
    - patches.common/lkcd-smp-update: Fix lkcd crash on smp  
        machines (#44919).
    - patches.common/pte-establish-race: avoid userspace corruption  
        during COWs with threads on x86 PAE with &gt;4G of ram.
    - make gendisk\_lock irq safe (bug #45742)
    - fix for ES7000 machines to properly detect all CPUs (#32926)
    - patches.fixes/netfilter-ipt-log-crash: Prevent ICMP crash in  
        netfilter logging (46016)
    - Disable CONFIG\_UID16 for s390x (#43176)
    - Drop broadcast packets if qeth can't handle them (#42433)  
        add patches.s390/qeth-drop-bcast-packets.patch
    - Disabled IBM preliminary patches.
    - export some aio symbols to catch up with 2.6
    - Added Preliminary IBM Codedrop 2.4.21-s390-17 (2004-09-17)  
        add patches.s390/linux-2.4.21-s390-17-june2003-patches
    - Added Preliminary IBM 'Korora' Codedrop.  
        add patches.s390/ctcmpc  
        add patches.s390/layer2\_10gig  
        add patches.s390/z90crypt
    - Fix sys\_ioctl definition for 31bit emulation  
        add patches.s390/s390x-ioctl32-args
    - Update patches.s390/mcast\_new\_complete.diff to match  
        IBMs version.
    - fix JFS resize bug on big-endian (#41535)
    - prevent oops in ip6t\_LOG (#44213)
    - Added IBM Codedrop 2.4.21-s390-13 (2004-05-18)  
        add patches.s390/linux-2.4.21-s390-13-june2003-patches
    - Added IBM Codedrop 2.4.21-s390-14 (2004-06-14)  
        add patches.s390/linux-2.4.21-s390-14-june2003-patches
    - Added IBM Codedrop 2.4.21-s390-15 (2004-07-14)  
        add patches.s390/linux-2.4.21-s390-15-june2003-patches
    - Added IBM Codedrop 2.4.21-s390-16 (2004-09-14)  
        add patches.s390/linux-2.4.21-s390-16-june2003-patches
    - Removed temporary fixes which were merged in the codedrops.
    - Disabled CONFIG\_UID16 for s390x.
    - update write-return-eio to handle the generic\_osync\_inode case
    - write-return-eio: In case we encountered an IO error (-EIO), we  
        better make sure we return it, as the amount of bytes written  
        before is not reliable then. (#43622)
    - sunrpc/svcsock: don't propagate TCP recvfrom errors up to nfsd;  
        this causes nfsd to exit (#45132)
    - scsi-scan-largelun: Update SCSI blacklist from 2.4.28-pre3.
    - scsi-scan-allow-ghost-devs: Move determination of SCSI level  
        earlier, so we can issue REPORT\_LUN to targets where we could  
        not register LUN 0 due to PQ/PDevTp == 3/0x1f. \[#39279\]
    - scsi-logging-parm: Don't put a version on symbol.
    - scsi-scan-allow-ghost-devs: Don't abort scanning on PQ/PDevTp  
        == 3/0x1f; just don't attach to this LUN (unless  
        scsi\_allow\_ghost\_devices is larger than the LUN). For ghosts,  
        only allow sg to attach. \[#39279\]
    - scsi-scan-newopts: bflags could have been used uninitialized  
        for INQUIRY length determination.
    - get\_user\_pages\_pte\_pin-async2: Asynchronous kevented to avoid  
        async IO deadlock (andrea, 43220, 43761).
    - One more audit patch \[#43066\].
    - audit: fix handling of return value.
    - audit: add support for clone2 syscall.
    - fix race condition in sg.c I/O completion (#42678)
    - get\_user-pages\_pte\_pin-fix: Fix the kiovec free oops with lvm  
        snapshotting (#33482, #44065).
    - More nfsd xdr decoding fixes (#43603)
    - patches.s390/s390x-lstat-return.patch (#43118)  
        S/390: Do not modify stat buffer on error.
    - patches.s390/s390x-mmap-error.patch (#43554 – LTC10008)  
        S/390: Fix mmap segfault on error.
    - Revert last change.
    - Moved syscall-audit-ia32\_syscall\_enable to patches.ia64 (#43066)
    - Use CONFIG\_IA64.
    - syscall-audit-ia64-utimes: utimes has two timeval arguments,  
        fix audit code for it on ia64 (#43066).
    - Add ia32\_syscall\_enable sysctl \[#43066\].
    - fix kNFSd signed issues (#43603)
    - Fix syscall-audit patches to compile.
    - queue-signals-peruser.diff: Fix missing initialisation of signal  
        counter in signal DoS patch. (#39181, okir)
    - Fixed s390/ppc compile problem with syscall-audit-semtimedop
    - Merged several patches for audit subsystem (#43066, #43561)
    - add missing license tags for dump\_gzip.c and dump\_rle.c (#42159)
    - fix wrong cache descriptors (#41051)
    - Fix proc-info-leak bugfix (#43390).
    - add patches.common/proc-info-leak-ppc\_rtas\_tone\_volume\_read  
        missing variable
    - Fix proc-info-leak to compile on S/390 (netiucv).
    - Fix proc-info-leak to compile on S/390 (ctcmain).
    - make fix for firewire overflow problem actually compile
    - fix integer overflow in firewire code (#42402)
    - Clean up signal queue DoS patches: Just apply the sysctl per user  
        instead of globally (#39181).
    - export symbol block\_commit\_write (#43205)
    - activate fixes for /proc info leak (#41074)
    - Add LAuS patches for ia64.
    - fix direct io on ext3 (#42239)
    - JFS: Make sure journal records get flushed to disk (#42651)
    - add missing check in chown() system call (#42400)
    - #39181 pending signal queues: denial of service. Hide the new  
        RLIMIT\_SIGPENDING resource from user space.
    - Make CONFIG\_RELEASE a string instead of an integer.
    - add EXPORT\_SYMBOL\_NOVERS(\_sb\_findmap); for  
        s390 and s390x (#42137)
    - pss-user-pointer: Properly check userspace pointer (#42050)
    - fix memory overwrite bug in airo driver (#42096)
    - fix copy\_from\_user/copy\_to\_user thinko in ALSA (#42095)
    - asus\_acpi: parse arguments in a safe way (#42052)
    - properly use \_user in OSS ioctls (#42050)
    - don't write user pointers without checking in decnet (#42049)
    - check existance of device in eql (#42217)
    - Make CONFIG\_RELEASE a string instead of an integer.
    - Switch to sequence-patch.sh from kernel-source-26. Adjust.
    - fix wrong 32 bit syscall table on x86\_64 for syscall audit (#41972)
    - Backport from kernel-source-26: Remove stray quotes from  
        EXTRAVERSION: CONFIG\_CFGNAME is a quotes string like "default";  
        those quotes ended up in EXTRAVERSION and were removed or not  
        depending on the context in which this variable was used.
    - Fix x86-64 MCE decoding patch that went in previously (#41593)
    - gdth-pci-dma-2: Fix ICP Vortex driver for machines with &gt;4GB  
        RAM. (#41495, axboe).
    - S390: Update patches.arch/s390-dirty-2.6.5  
        Update to version suggested by akpm (#42066).
    - S390: add patches.s390/dirty-2.4.21  
        fixing data corruption under memory pressure for s390 (#42066)
    - S390: add patches.s390/w4sense-cc3.patch  
        Fix data corruption on heavy load with ESS.
    - fix user-triggerable local DoS (#41951)
    - use correct fix for e1000 infoleak bug (#39680)
    - Add missing file
    - Fix machine check handler on x86-64 (#41593)
    - Really fix LDT/TSS limit on x86-64 (#41574)
    - Fix fpu register leak \[#41411\].
    - add patches.ppc/ibm-ppc64-bcm5700-7.1.23  
        need memory barriers in the Rx path (#41393 – LTC9003)
    - fix vmalloc-page-fault bug with nested irqs (#40550)
    - fix incorrect error handling in map\_user\_kiobuf
    - fix info leak in e1000 driver (#39680)
    - fix for &gt; 1TB SCSI disk (#41262)
    - enable patches.common/highuid16.patch
    - add patches.common/highuid16.patch, but leave it disabled  
        the last patch to fix uid32 problem in smbfs caused unresolved  
        symbols. make it i386 only for the time being. (#41090 – LTC8819)
    - remove EXPORTSYMBOL-declaration of overflowuid\_overflowgid  
        in arch/s390x/s390\_ksysm.c
    - adding patches.s390/add\_config\_uid16\_to\_s390x to enable  
        CONFIG\_UID16 for s390x
    - qla-select\_next\_path\_fix-v6.07.02: Handle failover without  
        oopsing during module reinsertion (PPC, #40872).
    - Adding CONFIG\_UID16=y to default config of s390x
    - add patches.ppc/ppc64-24-hdio-ioctls  
        mark HDIO\_DRIVE\_TASK as compatible ioctl (#40641 – LTC8579)
    - add patches.common/usb-storage-ioerror\_ohci-locking-2.4.21.patch  
        serialize ohci URB unlink handling (#25555,#30673 – LTC4369)
    - S/390: Add patches.s390/linux-2.5.21-s390-zfcp-retry.patch  
        Fix rash retries on zfcp (#35557).
    - S/390: Added more includes to init/kerntypes.c  
        (As per request of Michael Holzheu holzheu@de.ibm.com)
    - fix uid32 problem in smbfs (#39579)
    - add patches.ppc/ibm-ppc64-lparcfg (#39602 – LTC6863)
    - Merge from UL1\_SP4\_BRANCH
    - add patches.common/fs-exec-coredump-LFS (#38733)  
        from Andrea to allow core files larger than 2 GB
    - add add patches.common/get\_user\_pages\_pte\_pin (#39138 – LTC7702)  
        patch from Andrea to prevent unmapping of pinned pages
    - fix buffer overflow in panic() (#39054)
    - fix proc file permissions of qla2xxx driver (#39347)
    - fix memory leak in do\_fork() (#39223)
    - add patches.common/qla-vary\_io, ppc64 only at the moment  
        (#37610 – LTC7160)
    - Fix mcast-msfilter-int-overflow patch.
    - mcast-msfilter-int-overflow: Fix integer overflow in ip\_setsockopt  
        MCAST\_MSFILTER (#39207).
    - add support for Treo600 (trivial backport from 2.6) (#39132)
    - add two more HP devices to SCSI scan blacklist
    - S/390: Fix multicast handling for iucv (#35593).  
        (UL1\_SP4\_BRANCH)
    - Fix user\_to\_kernel\_hz\_overflow(x) macro (werner, andrea).
    - Enable nbd module on ia64.
    - Add Apple Xserve to the SCSI blacklist with LARGELUN | SPARSELUN.
    - Semaphore fix (#38517, i386 &amp; x86-64).
    - S/390: added patches.s390/mcast\_new\_complete  
        Fixing Multicast handling on S/390 (#35593).  
        (UL1\_SP4\_BRANCH)
    - fix cpu\_sibling\_map on summit machines (#33284).
    - fix I/O resource allocation failure during PCI hotplug (#32694)
    - fix info leak in jfs filesystem (#36125)
    - add CLOVERLEAF device to scsi\_scan blacklist
    - fix some more ACPI IRQ problems (#36058, #34704, #35314)
    - sunrpc-svcsock-drop: Be more careful about dropping connections  
        in RPC, work around for buggy NFS clients (#34733, okir).
    - fix ocfs2 mount problem (#32962)
    - added some HP devices to scsi\_scan blacklist (#36207)
    - scsi\_scan blacklist entry for DEC HSG80 needs BLIST\_SPARSELUN  
        instead of BLIST\_FORCELUN (#37453)
    - S/390: Update to IBM codedrop 2004/03/15  
        added patches.s390/linux-2.4.21-s390-12-june2003-patches  
        removed superseded patches:  
        patches.s390/zfcp\_hbaapi\_buffersize.patch  
        patches.s390/zfcp-watchdog.patch  
        patches.s390/qdio-guest-lan.patch  
        (UL1\_SP4\_BRANCH)
    - S/390: add patches.s390/qdio-guest-lan.patch  
        fix performance slowdown of Hypersocket Guest Lan (#36652)  
        (UL1\_SP4\_BRANCH)
    - S/390: add patches.s390/zfcp-watchdog.patch  
        watchdog for stalled FCP channel (#37072)  
        (UL1\_SP4\_BRANCH)
    - S/390: add patches.s390/zfcp\_hbaapi\_buffersize.patch  
        fix size of SCSI SENSE buffer for zfcp hbaapi (#36486).  
        (UL1\_SP4\_BRANCH)
    - 390:disable parts of linux-2.4.21-s390-10-05-june2003-net(#35593)  
        (UL1\_SP4\_BRANCH)
    - Fix user triggerable oops in x86-64 32bit emulation
    - add patches.ppc/sles8-qla-v6.07.02-2.4.21-147.patch (#36225)  
        update device driver to fix potential data integrity problem
    - allow IPv6 netfilter modules to be loaded on x86\_64 (#34810)
    - add new version 5.2.30.1 of e1000 driver as e1000-new.o
    - fix info leak in xfs filesystem (#35463)
    - add missing size check in r128 driver also to 4.0 version
    - lvm hash bucket calculation fix, solves snapshot creation  
        problems on 32bit machines with &gt; 4GB of ram. Bug #34418
    - use agpgart-bus also on i386 to solve problem also in 32 bit
    - don't try to use forcedeth driver on S/390 machines
    - add HP ProLiant and Compaq ProLiant to dmi blacklist so that ACPI  
        gets disabled automagically on these systems
    - fix ipv4 raw ip checksum error, triggered by gcc 3.3 (#34820)
    - 64-bit kernel emulation of 32-bit CDROM\_SEND\_PACKET ioctl was  
        incomplete and could cause kernel crashes (#35159)
    - fix vulnerability in soundblaster driver (#35279)
    - fix info leak in ext3 filesystem (#35212)
    - add yet another missing size check in r128 driver (#33945)
    - fix vulnerability in iso9660 filesystem (#34841)
    - add forcedeth driver for NVIDIA nForce media access controllers
    - blacklist-patch.HP: ACPI blacklist update forCompaq/HP Proliant  
        machines (#33167).
    - patches.common/scsi-req-q-ptr: Make sure proper request queue  
        ptr is passed, to avoid missing wakeups. Finally solves  
        starvation (#33215, LTC5252, axboe, mpeschke)
    - patches.common/lvm-dont-shift-pv: Don't shift PV pointers  
        to prevent null ptr deref. (#34042, sbader, obsoletes  
        lvm-mp-oops-on-null-pv).
    - patches.common/vm\_reserve: Also use vm\_reserve boot param, if  
        CONFIG\_DISCONTIGMEM (NUMA) is set on i386. (#34418)
    - add patches.ppc/ibm-ppc64-log\_rtas\_len-overflow  
        avoid overflow in rtas functions (#34595 – LTC5991)
    - add patches.ppc/ibm-ppc64-errinject.patch  
        copy enough data in ppc\_rtas\_errinjct\_write (#35048 – LTC6543)
    - Fix off by one errors in x86-64 IOMMU code (#35039)
    - fix IGMP/ipt\_REJECT checksum on x86-64 (#35140)
    - add patches.ppc/vmalloc-patch-suse-sym2  
        protect page\_table\_lock during interrupts (#32275 – LTC4738)
    - fixed #33167 (HP &amp; xAPICs) through DMI id updates
    - prevent potential DoS attack via mremap (#34729)
    - fix user space access in C-Media PCI OSS sound driver
    - fix #33945 for both versions of the r128 DRI driver
    - Implement mapped\_base for x86-64 (#34548)
    - Fix aacraid patch
    - Update aacraid and dpt\_i2o drivers to latest versions on x86-64
    - Reenable dpt\_i2o driver on x86-64
    - S390: Moved IBM codedrop 2004/01/16 to UL1\_SP4\_BRANCH.
    - S390: Add missing symbol nr\_running().
    - S390: Reenable missing  
        patches.s390/linux-2.4.21-s390-timer-03-june2003.diff.
    - add patches.ia64/disable-showMem (#33317)
    - add patches.ppc/ibm-ppc64-pseries-cpu\_update for upcoming cpus
    - Part of a patch from Greg Banks, which will hopefully fix  
        the "dirty inodes after unmount, self-destruct in 5 seconds"  
        problem (#30943)
    - check interpreter type to prevent possible local DoS (#34287)
    - return proper error codes for do\_munmap() failure in mremap
    - s390x: fix 31-bit emulation of /proc/&lt;pid&gt;/mapped\_base(#34276)
    - patches.fixes/xattr-keep-block: Fix xattr bug when keeping  
        the same disk block in ext\[23\].
    - Audit subsystem: included patches that were submitted as part  
        of the EAL3 certification effort but not included in the SLES8  
        kernel so far. These patches affect the audit subsystem only.  
        patches.common/syscall-audit-noparanoia  
        patches.common/syscall-audit-nohang
    - S390: Update to IBM 'blizzard' codedrop 2004/01/31  
        Added new patches linux-2.4.21-s390-08-june2003-patches  
        Added new patches linux-2.4.21-s390-09-june2003-patches  
        Added new patches linux-2.4.21-s390-10-june2003-patches  
        Updated timer-patch.  
        Updated config files to select new options.
    - lvm-mp-oops-on-null-pv: lvm-mp code introduced conditions where  
        we could hit a NULL pv and deref it: Ooops. (axboe, #34042)
    - shmem-swap: Fix handling of swapout behaviour on machines with  
        large amounts of unlocked shared memory (SAP), all controlled  
        by vm\_shmem\_swap sysctl, defaulting to off (andrea, #33964): 
        - Avoid excessive swapping ("objrmap").
        - Save extra page table scan.
        - Avoid I/O performance to be destroyed by shmem swapout.
    - qla2xxx-enable-conf-modules: Build the \_conf modules as well.  
        (#34155, #34191).
    - scsi-queue-next-unconditionally: Call request\_fn()  
        unconditionally all needed checks are done there. The break was  
        wrong and should have been continue (axboe, mpeschke, #33215).
    - scsi-restart-ops-unconditionally: Ditto. We don't need the  
        host lock any more then. (axboe, mpeschke, #33215).
    - disable excessive status messages in aacraid driver
    - scsi-noderef-freed-host: If the error handler thread died, we  
        could have dereferenced host in a freed structure SCpnt  
        structure. (axboe, #33783).
    - add patches.common/usb-serial-palm-sched\_oops.patch  
        fix BUG() in sched.c:910 (#31948)
    - add patches.common/jfs-on-block\_flushpage  
        do not call block\_flushpage in \_\_invalidate\_metapages  
        (#27332 – LTC3109)
    - fix race condition in qla1280 error handling code (#33847)
    - check size for memory allocations in r128 DRI driver (#33945)
    - fix possible crash in USB vicam driver (#34118)
    - don't leak info in i386 fault handler (#34051)
    - add patches.ppc/suse-ppc64-kallsyms  
        allow CONFIG\_KALLSYMS even if KDB is off (#34052 – LTC5882)  
        enable CONFIG\_KALLSYMS=y in iseries64 .config
    - scsi-dma-sectors: The limitation of new\_dma\_sectors in scsi\_dma  
        was buggy and would overflow. Fix. (IBM, axboe, #33215)
    - acpi-t40-ec-osdl1038: ACPI on T40: Fix Embedded Controller  
        detection as well. (#32222)
    - Fix compilation with gcc 3.4
    - Avoid overflowing size\_buffers\_type (andrea, FSC, see #33964).
    - Avoid a starvation situation in scsi midlayer (axboe, #33215).
    - Disable dpt\_i2o driver on x86-64
    - Limit file names in ncpfs (#34100)
    - scsi-error-deadlock: fix locking in scsi\_error.c to prevent  
        possible deadlock. (#)
    - add patch for SiL 3114
    - Fix MTRR size computation on x86-64
    - Fix bugs in NUMA node discovery
    - max\_scsi\_luns was not effective when REPORT\_LUNS was used. Fixed.
    - add patches.common/reiserfs-jl-refcount (prevent too early free  
        of journal\_list), should fix #32729 and may also fix bug #34026
    - add patches.common/scsi-type-TYPE\_UNKNOWN  
        Scsi\_Device-&gt;type is being set to -1. (#34009 – LTC5783)  
        It's causing us to access the scsi\_device\_type array at -1.
    - add patches.ppc/ibm-ppc64-bcm5700-7.1.22  
        use the latest broadcomm driver on powerpc, keep NAPI enabled
    - update patches.common/sd\_many  
        fix scsi module unload problem (#33282 – LTC5355)
    - scsi-scan-largelun: Add Pathlight/ADIC and Crossrds to blacklist.
    - Fix rpm3 performance problem.
    - Fix LDT limit on x86-64
    - add patches.ppc/ibm-ppc64-kdb-sdr1  
        KDB superreg option doesnt print SDR1 register (#33854 – LTC5587)
    - Add dynamic-hz-ata-new for new libata on x86-64
    - Update libata to new version for x86-64
    - Enable libata drivers in x86-64
    - Add workaround for AMD K8 Errata #87
    - Make x86-64 IOMMU flushing more conservative
    - Fix ptrace 32bit hole for x86-64
    - fix NFS directio bug that causes data corruption when creating  
        files larger than 4 GB
    - don't abort if one single additional km\_ package fails
    - remove km\_dvb
    - s390: added missing epoll syscalls (#33668)
    - add missing check in mremap
    - add cross-ppc64-binutils cross-ppc64-gcc-core unconditionally  
        to avoid autobuild magic (#33250 – LTC5419)
    - s390:fix ffs() to pick up the preinitialized result value(#33450)
    - provide preconfigured header files for ppc64 kernels  
        now for real…
    - s390: fix bad ffs() return value, fixes fat and netfilter(#33450)
    - s390: fixes for ESS caching(5409) and ESS flashcopy(4676/#33446)
    - provide preconfigured header files for ppc64 kernels  
        (#33250 – LTC5419)
    - s390:integrate IBM June 2003 code drops 2003-10-31 and 2003-11-28
    - nfsd-fhalias(for HA-NFS): avoid console spew from invaid IP 0.
    - add patches.ppc/ibm-ppc64-proc-copy\_user  
        audit pseries/iseries proc interface (#33345)
    - Disable dma engine test in tg3 driver on SN2 \[#32928\].
    - Update CPE/CMC polling code to avoid deadlock \[#32885\].
    - fix 32bit \[f\]truncate64 for x86-64
    - reenable x86\_64-sci fix (#32893)
    - Fail build if one of the km\_\* modules fails.
    - Remove km\_basilisk and km\_vmware.
    - Set CONFIG\_SUSE\_KERNEL and CONFIG\_UNITEDLINUX\_KERNEL correctly  
        in the pre-configured headers. By accident neither was defined  
        there so far. (The k\_\* packages did fix that, though.)
    - #33097: patches.common/xattr-pointer-arith fixes a pointer  
        arithmetic bug in the xattr code.
    - Remove patches.common/x86\_64-sci.
    - Revert last change again by request of rf.
    - Revert smp boot cpuid/apic handling for non summit to  
        before #32570,#32571, fixes #32926, verified on x440, but not  
        yet on HP
    - Port i386 ACPI SCI fixes to x86-64 (#32893)
    - Set correct TSS limit on x86-64
    - Fix ACPI mem handling issue with T40. \[#32222\]
    - patches.common/sd\_many: Fix reported SCSI disk size if between 1  
        and 2TB (cosmetic). \[#32358\]
    - patches.common/ide-scsi-impl-abort: idescsi\_abort(): Fix locking  
        \[#32855\]
    - Fix ia32 stat emulation \[#32824\].
    - corrected hangcheck according to mail from Joel Becker
- laus 
    - added patch laus-0.1\_ia64-headerupdate-247.diff to update  
        audit.h and resolve inconsistency between kernel and user-space
    - replaced laus-0.1\_message-realign.diff with  
        laus-0.1\_message-realign-b.diff because the original patch  
        copy too less data which results in broken output
    - fixed some patches introduced before (Bug #44047)  
        + semtimedop() syscall number changed from 2.4 to 2.6  
        + make the defines in the source not in the ia64 header  
        to avoid problem with old glibc headers and compiling  
        the code manually
    - added more patches from Klaus Weidner to support clone2  
        and the xattr syscall family on IA64 (Bug #44047)
    - added patch for alignment problem on ia64
    - added fix for build problem on ia64
    - added fix from Klaus Weidner to correct ip:port output format  
        (#42606)
    - added fix from Klaus Weidner to support missing system call  
        semtimedop() neeed for EAL3 (#42606)
    - removed licence disclaimer in laus.h that prevents distributing  
        (#42606)
    - fixed inconsistency in audit init-file (#32777)
    - man-pages didnt get installed due to not listing them in  
        Makefile.am
- less 
    - removed potential tmp file race \[#39272\]
- lha 
    - Added patch for obscure buffer overflow (#40975).
    - Fixed buffer overflows for long filenames (CAN-2004-0234).
    - Added directory traversal protection (CAN-2004-0235) (#39178).
- libpng-devel 
    - replaced security patches with the official ones \[#43008\]
    - fixed several buffer overflows \[#43008\]
    - added missing part of pngtran overflow patch \[#42043\]
    - fixed possible buffer overflow
- libtiff 
    - fixed directory entry count overflow (CAN-2004-1183) \[#49469\]
    - fixed overflow in tiffdump
    - Do not crash if we are using unsupported codecs (like OJPEG).
    - do not call TIFFTileSize with uninitialized values \[#44635\]
    - prevent division by zero
    - fixed much more buffer overflows (the older  
        tiff-alt-bound-CheckMalloc.patch  
        is included in the new libtiff-3.5.7-alt-bound.patch now) \[#44635\]
    - fixed more buffer overflows \[#44635\]
    - fixed multiple buffer overflows
    - CAN-2004-0803 \[#44635\]
    - disabled old jpeg support because of security problems \[#45116\]
- libusb 
    - Backport get\_usb\_busses interface \[Bug #50691\]
- libxml 
    - added patch to fix buffer overflows in FTP and HTTP URL handling  
        as well as in DNS code. (bug #49362)
- libxml2 
    - Fix several buffer overflows that can occur while processing  
        FTP and HTTP URLs as well as in DNS name handling code. These  
        bugs can be exploited remotely to execute arbitrary code. Patch  
        provided by Thomas Biege \[# 47670\].
    - Fix buffer overflows discovered in the FTP and HTTP URL parsing  
        code (backported from CVS head by Thomas Biege). \[# 34572\]
    - Apply libxml2-htmlparser.diff to fix buffer overflow in  
        HTMLparser.c; this prevents yelp from working.  
        Patch provided by Shane O'Connor \[# 32831\].
- liby2util 
    - don't use system() for calling gpg (#42776).
    - 2.6.23
    - Fixed bug that inhibits logging on big-endian architectures.  
        \[#28136\]
    - 2.6.22
- linux-iscsi 
    - Update to linux-iscsi-3.6.2
- lvm 
    - add accidientially omitted hunk to EMC powerpath patch
    - add support for EMC powerpath (#34836)
    - Update to v6c (Codedrop from IBM Developerworks / #31758).
    - fix bug in script pvpathsave when running on readonly fs
    - fix bug in start script regarding calls to pvpath{save,restore}
    - make it possible to use GPT partitions as PVs
- mailman 
    - added mailman-2.0-dirtraversal.patch \[bug #50563, CAN-2005-0202\]
    - fix for Python bug \[bug #39200\]
    - fix for DoS bug to be described in CAN-2003-0991
    - added postinstall code to correctly set /etc/mailman.mail-group  
        (group for mail script aliases) \[bug #27369\]
- mc 
    - Fix the handling of symlinks inside tarballs which would lead  
        to a segfault with suitably constructed tarballs.
- mod\_dav 
    - security fix \[CAN-2004-0809 (cve.mitre.org)\]: fix possible  
        DoS in mod\_dav by remotely triggerable null-pointer  
        dereference [htt  
        p://nagoya.apache.org/bugzilla/show\_bug.cgi?id=31183](http://nagoya.apache.org/bugzilla/show_bug.cgi?id=31183)  
        \[#45231\]
- mod\_php4 
    - fix vulnerabilities in unserializer (bug #48635)
    - fix broken int unserializing on 64-bit (bug #49617)
    - fixed several vulnerabilities (bug #48635, patch secfix1)
    - fixed php.ini settings "leak" from vhosts/.htaccess files  
        (bug #48431, patch secfix2)
    - security fix for array parsing (bug #45710, patch array)
    - fix memory limit problem, a problem with strip\_tags and  
        several stability issues (bug #42949);  
        Patches: everything\_except\_mm, memory\_limit\_in\_execution,  
        sfix
    - session variables where not read due to wrong type usage;  
        bug #33699, patch sessread
    - print() did not yeald any output on s390x when a session  
        had been started due to wrong type usage; fix in patch  
        sessid
- mod\_python 
    - update to 2.7.10, which fixes a vulnerability whereby a  
        specific query string processed by mod\_python would cause  
        the httpd process to crash. \[#34115\]
- mod\_ssl 
    - security fixes from 1.3.31 \[#40611\]: 
        - CAN-2004-0174 (cve.mitre.org)Fix starvation issue on listening sockets where a  
            short-lived connection on a rarely-accessed listening  
            socket will cause a child to hold the accept mutex and  
            block out new connections until another connection  
            arrives on that rarely-accessed listening socket.  
            Enabled for some platforms known to have the issue  
            (accept() blocking after select() returns readable).  
            Define NONBLOCK\_WHEN\_MULTI\_LISTEN if needed for the  
            platform and not already defined.
        - CAN-2003-0987 (cve.mitre.org)  
            Verification as to whether the nonce returned in the  
            client response is one we issued ourselves by means of a  
            AuthDigestRealmSeed secret exposed as an md5(). See  
            mod\_digest documentation for more details.  
            The experimental mod\_auth\_digest.c does not have this  
            issue.
        - CAN-2003-0020 (cve.mitre.org)  
            Escape arbitrary data before writing into the  
            errorlog. Unescaped errorlogs are still possible using  
            the compile time switch  
            "-DAP\_UNSAFE\_ERROR\_LOG\_UNESCAPED".
        - security fix for mod\_ssl: fix buffer overflow in  
            ssl\_util\_uuencode() \[#40791\]
        - security fix (CAN-2003-0993): Allow and Deny rules with  
            IP addresses (e.g. 192.168.1.1) where parsed incorrectly  
            on 64-bit platforms with big endianness. It only affected  
            IP addresses with no netmask definition. \[#35450\]  
            [http://nagoya.apache.org/bugzilla/show\_bug.cgi?id=23850](http://nagoya.apache.org/bugzilla/show_bug.cgi?id=23850)  
            apply the patch only on s390x.
        - security fix (CAN-2003-0542): fix buffer overflows in  
            mod\_alias and mod\_rewrite that are possible when using a  
            regular expression with more than 9 captures \[#32756\]
        - remove 0host entries for pidfile and logfiles, which  
            alarmed our patchrpm breakage tests
- Mozilla 
    - fixed news:// URL handling code (#49571, bmo #264388)
    - XPCNativeWrapper is needed for #249332 (bmo #270729)
    - more security related bugfixes (#47658)
    - fixed trigger logic (#48701)
    - some security related bugfixes (#45640)
    - endianess bugfix for x86-64 (#34743)
    - several fixes including (backported from 1.4.3):  
        CAN-2004-0597  
        CAN-2004-0718  
        CAN-2004-0722 (#43569)  
        CAN-2004-0757  
        CAN-2004-0758  
        CAN-2004-0759  
        CAN-2004-0760  
        CAN-2004-0761  
        CAN-2004-0762  
        CAN-2004-0763 (#43312)  
        CAN-2004-0764  
        CAN-2004-0765
    - update to 1.4.2 (20040220) 
        - NSS update for S/MIME related crash (SUSE #33771)  
            (Mozilla #229242)
        - patch for fontEncoding.properties included
    - added build-fix for s390x (#32963)
    - fixed installation of fontEncoding.properties (#34321)  
        (thanks to Jungshik Shin)
    - update to 1.4.x (20031215)
    - added mozplugger to add-plugins.sh
    - added patch to expunge IMAP folders if "remove immediately"  
        delete model is used
    - update enigmail to 0.76.7
    - added mozplugger (part of bug #31616).
    - adopted RealPlayer inclusion for new path (#30990)
    - make mozilla open URLs not files
    - build with XFT support on SLEC
    - use kprinter as default print command on SLEC (#31734)
    - added compat symlinks for GNOME settings (#32326)
- mysql 
    - fix for several vulnerabilities (bug #47135):
    - ALTER TABLE … RENAME checked CREATE/INSERT  
        rights of the old table instead of the new one (patch alter)
    - a buffer overrun in the mysql\_real\_connect function (patch dns)
    - multiple threads ALTERing the same (or different) MERGE tables  
        to change the UNION could cause the server to crash or stall  
        (path merge)
    - Privilege Escalation on GRANT ALL ON `Foo\\\_Bar` (patch grant)
    - scripts mysqld\_multi and mysqlbug allow local users  
        to overwrite arbitrary files via a symlink attack (patch symlink)
    - made mysqlhotcopy working again as it was broken by  
        the upstream patch for a security problem (bug #46994, patch  
        hotcopy)
    - applied patch for a security hole in mysqlhotcopy (bug #43829)
- ncpfs 
    - correct logic in CAN-2005-0014 patch
    - add file permisions check for ~/.nwclient (##49677 –  
        CAN-2005-0013)
    - add fix for possible buffer overflow in ncplogin (#49677 –  
        CAN-2005-0014)
    - add ncpfs-2.2.4-NWDSCreateContextHandleMnt.patch  
        buffer overflow in ncplogin and ncpmap – CAN-2004-1079 (#48702)
- nessus 
    - fix race condition caused by unset $TMPDIR (#43771)
    - don't send email on update to root on UnitedLinux \[Bug #26460\]
- nss\_ldap 
    - nss\_ldap-199.ldapgrp.diff: Fixes handling of users which  
        are member of more than 64 groups (Bugzilla: #49472)
- openldap2 
    - is\_entry\_objectclass.dif: Entries with objectclass:  
        extenisbleObject were missing from search results of the  
        first query (Bugzilla: #34463)
    - backglue-slaptool.dif: slapcat was segfaulting if a  
        back-ldap database was configured as a subordinate of a  
        back-ldbm database (Bugzilla: #33625)
    - backglue-onelevel.dif: One-level search operations on  
        subordinate databases where failing with an "unwilling to  
        perform" error. (Bugzilla: #36203)
    - ucs\_memleak.dif: Memory leak in liblunicode (Bugzilla:  
        \#33648)
    - rcldap-checktls.dif: Removes over-restrictive check for SSL  
        configuration from the init-script. (Bugzilla: #33560)
    - schema\_check.dif: Disallow the removal of the RDN-Attribute from  
        entries (Bugzilla: #27538)
    - avl\_ptrcmp.dif: Fixes the maintenance routines for attribute  
        indexes, index definitions could have been ignored by slapd  
        (Bugzilla: #28145)
    - ldbm.dif: fixes possible index corruption in back\_ldbm which  
        could lead to wrong search results (Bugzilla: 27152)
    - bdb\_passwd.dif: fixes a small memory leak in password extended  
        operation code of back-bdb (Bugzilla: 26817)
- openmotif 
    - Fixed XPM security problems #43420.
    - Fix XmResizeHashTable \[#44499\].
- openssh 
    - fixed previous fix of security bug in scp \[#35443\]  
        (CAN-2004-0175) (was too restrictive)
    - fixed security bug in scp \[#35443\] (CAN-2004-0175)
    - changed sshd.8 and sshd\_config.5 (EAL3)
- openssl 
    - add security fix for CAN-2004-0079 (possible null-pointer  
        assignment during SSL/TLS handshake)
    - removed a part of the openssl-timing-attacks.patch which  
        addresses the timing attack on RSA keys problem  
        see [  
        http://www.openssl.org/news/secadv\_20030317.txt](http://www.openssl.org/news/secadv_20030317.txt).  
        The patch to rsa\_lib.c was not thread safe.
- permissions 
    - changed permission of /var/lock/subsys to 755
    - changed permissions of /var/lock \[Bug #37759\]
    - Remove /var/run from list \[Bug #28289\]
- postgresql-devel 
    - New Patch release: 7.2.7. Fixes a security issue with LOAD and  
        some other bugs (#50191). See HISTORY for details.
    - New patch release: 7.2.6. Fixes several security and data  
        corrupton bugs (#47619). See HISTORY for details.
    - Added postgresql-7.2.2-7.2.6.patch.bz2 for completeness and  
        removed all patches that became obsolete by the version update.
    - Adapted a patch from Debian to fix a buffer overflow in ODBC  
        driver (src/interfaces/odbc/): added parameter for target buffer  
        size to make\_string() to prevent buffer overflows and corrected  
        all calls to it (http://bugs.debian.org/247306, SuSE Bugzilla  
        \#40714).  
        With previous versions it was possible to crash (and possibly  
        exploit) e. g. apache if a PHP script connected to a ODBC  
        database with very long credential strings (DSN, username,  
        password, etc.).
    - Backported a buffer overflow fix from version 7.3.4.  
        (Bug #29483)
    - Use test-and-set locks for x86\_64 instead of slow semaphores.  
        (postgresql-x86\_64.patch, Bug #27308)
    - Applied the bug and security fixes, that went into version 7.2.3,  
        and 7.2.4. (Bug #25784, postgresql-7.2.4.patch).
    - Backported the ppc and ppc64 test-and-set inline assembler code  
        from the 7.3.1 packages (postgresql-ppc.patch).  
        Disabled obsolete postgresql-ppc-largemem.patch, and  
        postgresql-ppc64.patch.
    - Added postgresql-ppc-largemem.patch to fix hangs when building  
        on certain types of PPC machines with huge memory.
- pure-ftpd 
    - Apply fix to remove possible DoS attacks \[#42821\]
- python 
    - fix vulnerability in SimpleXMLRPCServer (bug #50321,  
        CAN-2005-0089)
- qt3 
    - jpeg support got broken by last patch, fixed again
    - fixes for handling of broken images (#43356)
- rpm 
    - speed up rpmdbAdd/Remove if a package contains lots of  
        equal basenames (e.g. module.h or index.html)
- rrdtool 
    - added libpng-1.0.9.diff fixing security holes in  
        libpng (bug #43008)
- rsh 
    - added patch rexec-netrc. Rexec is now parsing ~/.netrc file  
        to get username and password. (patch got from  
        [https://bugzilla.redhat.com/bugzilla/show\_bug.cgi?id=135643](https://bugzilla.redhat.com/bugzilla/show_bug.cgi?id=135643))  
        \[Bug #50142\]
- rsync 
    - prevent failure on startup:  
        IPV6\_V6ONLY might be undefined or unsupported
    - update to 2.6.2 / ported patches (#39672)
    - fixes a problem with non-chroot modules
    - add -4 and -6 options to manpage (#36144)
    - update to version 2.6.0
    - update to real 2.5.7
    - fix heap overflow (#33478)
    - Fix quoting in configure script.
    - added make test
    - use defattr
    - update to 2.5.6
    - can combine ssh and daemon access
    - supports URL like syntax rsync://
    - IPv6 support in hosts.allow/deny
    - recursive hang fixed upstream
- ruby 
    - added fixes for lib/cgi.rb, lib/cgi-lib.rb, lib/cgi/session.rb  
        from ruby-1.6.snap, fixes: #47886 (CAN-2004-0983)
- samba 
    - Fix order of evaluation in the bitmap code; Samba.org svn  
        revision 4120; \[#49804\].
    - Fix remote exploitation of an integer overflow vulnerability in  
        the smbd daemon; patch made by Thomas Biege thomas@suse.de; CAN-2004-1154; \[#49119\].
    - Always stop winbind if the init script is called with stop,  
        \[#47108\].
    - Fixed potential file access outside of defined shares. \[#46352\],  
        CAN-2004-0815
    - Fix smbd crash in case of not send find\_first by a Microsoft  
        Windows XP with installed Service Pack 2, \[#43737\];  
        bugzilla.Samba.org \[#1520\].
    - Fix reopen\_logs() in case of used macros for the filename,  
        \[#43773\]; LTC \[#10274\].
    - Fix smbd crash if vscan is used, \[#43853\].
    - Fix MS DFS for Microsoft Windows XP and 2k3 clients, \[#44101\].
    - Fix buffer overrun in 'mangling method = hash', \[#43061\].  
        CAN-2004-0686.
    - Fix schannel patch which made machine account password changes  
        for Microsoft Windows XP and 2000 domain members impossible  
        \[#40087\].
    - Add package release to VERSION in include/version.h.
    - Fix error packets return code to allow clients the reuse of a  
        former assigned virtual uid \[#42022\].
    - Use /var/log/samba/ as a secure directory for all smb-print  
        scripts \[#36676\].
    - Fix password change broken by Microsoft hotfix MS04-011 \[#40087\].
    - Remove bogus nettime code.
    - Enhance waiting for cupsd function in the smb init script 
        - only check with lpstat every two seconds
        - remember start time in seconds and calculate the waiting  
            time in relation to this; this is important if a  
            configured CUPS server is unreachable. In this case we  
            now really wait only 30 seconds and not 30 times of the  
            lpstat timeout.
        - Thanks to Bjoern Jacke bjoern@j3e.de for the  
            patch.
    - Fix path to smb-print.log \[#36676\].
    - Fix for timestamp problem on 64 bit architectures \[#34464\].
    - Fix unnecessary mount requests if 'add user script' isn't used  
        \[#33194\].
- screen 
    - fix ansi NumArgs overflow \[#33379\]
- sharutils 
    - fix -o option handling (#39122)
- sitecopy 
    - add sitecopy-neon-CAN-2004-0179.diff (#41711)
    - add sitecopy-neon-CAN-2004-0398.patch (#41711)
    - add sitecopy-neon-0.23.7.diff (#41833)
- squid 
    - fix for remote DoS in snmp module CAN-2004-0918 (bugzilla#47198)
    - fixed wrong ownership of /usr/sbin/squid\_ldapauth (reported by  
        mc)
- tftp 
    - Fix security hole with possibly overflowing bcopy \[#47676\]
- ttf-hanyi 
    - The package ttf-hanyi was included in UnitedLinux 1.0 only for  
        testing purposes. Novell has now bought a proper license for this  
        font. This change removes the license and adds the new one.
- unarj 
    - inform about our fixes in the printed notice (#48553)
    - add subdirectory creation for the x command.
    - fix wrong time handling when daylight saving time.
    - fix date handling for year 2000 (it is leap year).
    - fix buffer overflow and tree traversal (#47184)
- utempter 
    - Fix incorrect check for /../ in path names (#39169)
    - added man-page utempter.8 (EAL3)
- xchat 
    - Fix SOCKS5 buffer overflow \[#39184\]
- xf86 
    - reverted broken security fix for Xsession script (see also  
        comment #16 of Bug#34253)
    - xfree86\_4.1.0\_glx\_dri\_integer\_overflow.diff:  
        The GLX and DRI code of the Xserver did not verify the "screen"  
        parameter in several functions. This failure leads to a  
        denial-of-service condition and probably to arbitrary code  
        execution as root. (CAN-2004-0093, CAN-2004-0094) (Bug #35206)
    - fixed tmp races in postinstall scripts and Xsession script  
        (Bug #34253)
    - fixed more buffer overflows in fontfile/ direc (#34296)
    - put together old and new bugs in  
        fontfile-sec\_bufferoverflows.diff
    - dirfile.diff:  
        at the same location just a few lines below the same problem
    - dirfile.diff:  
        A buffer overflow in the X server can be triggered by using a  
        malformed fonts.alias file. This bug can be used to gain local  
        root privilege (Bug #34296).
    - p\_pam\_setcred.diff:  
        Due to inproper checking of failure-conditions of pam\_setcred()  
        in XDM while using pam\_krb5 a user with valid login credentials  
        (Kerberos) may get root access to the system. (Bug #33788)
    - Disable sis.o module in km\_drm (it has unresolved symbols),  
        and remove a bad hack in Makefile.module. THis was discussed  
        with sndirsch@suse.de and mantel@suse.de.
    - p\_LTC3984.diff:  
        \* fixed double who entries for xterm (Bug #29126)
    - fixed build on sles8\*s390\*
    - This should fix bug #26187 
        - Make sux work even if no network available (bug #25315)
        - Workaround in sux due broken gnome session managment (bug  
            \#24052)
    - p\_ia64\_cirrus.diff:  
        \* workaround in cirrus driver for IA64 compiler bug (Bug #22735)
    - p\_ia64\_nv.diff:  
        \* fixes nv driver crash on HP zx6000 (Bug #21988)
    - p\_xlclocale.diff:  
        \* A buffer overflow vulnerability was fixed
    - p\_fixes.diff:  
        \* removed bogus brackets behind #undef
    - p\_x86-64\_lp64.diff:  
        \* fixed build for new gcc (defines now LP64)
    - Fix 64bit bug in VESA driver \[#22416\].
    - p\_x86\_64-2.diff: 
        - Mesa: turning on IEEE support for x86-64. This gives some  
            performance boost in 3D apps
        - X11.tmpl: fixing further warning message of  
            C-preprocessor during imake
        - radeon driver: fixing problem with division by 0 error in  
            case dotclock is out of the possible clock ranges of the  
            pll clocks.
    - readded lost patch 'p\_x86\_64.diff':  
        \* merging section allocation for x86\_64, using mmap() for  
        allocation
    - p\_loader.diff: fixed another loader problem on x86\_64
    - p\_xf86-4.2-2-pci\_domain.diff:  
        \* fixes pci scanning on p650, p640 and others.
- xinetd 
    - updated to version 2.3.11 (fixed a lot of security bugs)  
        \[#27081\]
    - removed obsoleted flag RECORD from xinetd.conf on line  
        log\_on\_failure
    - fixed bug in parsing config file \[#22876\]
    - removed obsoleted reuse option from rcxinetd script
    - added new fix from CVS (check\_from\_solar\_designer,  
        close\_listening\_descriptor and used\_valgrind\_to\_fix)
- xloader 
    - reverted broken security fix for Xsession script (see also  
        comment #16 of Bug#34253)
    - xfree86\_4.1.0\_glx\_dri\_integer\_overflow.diff:  
        \* The GLX and DRI code of the Xserver did not verify the "screen"  
        parameter in several functions. This failure leads to a  
        denial-of-service condition and probably to arbitrary code  
        execution as root. (CAN-2004-0093, CAN-2004-0094) (Bug #35206)
    - fixed tmp races in postinstall scripts and Xsession script  
        (Bug #34253)
    - fixed more buffer overflows in fontfile/ direc (#34296)
    - put together old and new bugs in  
        fontfile-sec\_bufferoverflows
    - dirfile.diff:\* at the same location just a few lines below the same problem
    - dirfile.diff:  
        \* A buffer overflow in the X server can be triggered by using a  
        malformed fonts.alias file. This bug can be used to gain local  
        root privilege (Bug #34296).
    - p\_pam\_setcred.diff:  
        \* Due to inproper checking of failure-conditions of pam\_setcred()  
        in XDM while using pam\_krb5 a user with valid login credentials  
        (Kerberos) may get root access to the system. (Bug #33788)
    - Disable sis.o module in km\_drm (it has unresolved symbols),  
        and remove a bad hack in Makefile.module. THis was discussed  
        with sndirsch@suse.de and mantel@suse.de.
    - p\_LTC3984.diff:  
        \* fixed double who entries for xterm (Bug #29126)
    - fixed build on sles8\*s390\*
    - This should fix bug #26187  
        \* Make sux work even if no network available (bug #25315)  
        \* Workaround in sux due broken gnome session managment (bug #24052)
    - p\_ia64\_cirrus.diff:  
        \* workaround in cirrus driver for IA64 compiler bug (Bug #22735)
    - p\_ia64\_nv.diff:  
        \* fixes nv driver crash on HP zx6000 (Bug #21988)
    - p\_xlclocale.diff:  
        \* A buffer overflow vulnerability was fixed
    - p\_fixes.diff:  
        \* removed bogus brackets behind #undef
    - p\_x86-64\_lp64.diff:  
        \* fixed build for new gcc (defines now LP64)
    - Fix 64bit bug in VESA driver \[#22416\].
    - p\_x86\_64-2.diff: 
        - Mesa: turning on IEEE support for x86-64. This gives some  
            performance boost in 3D apps
        - X11.tmpl: fixing further warning message of  
            C-preprocessor during imake
        - radeon driver: fixing problem with division by 0 error in  
            case dotclock is out of the possible clock ranges of the  
            pll clocks.
    - readded lost patch 'p\_x86\_64.diff':  
        \* merging section allocation for x86\_64, using mmap() for  
        allocation
    - p\_loader.diff: fixed another loader problem on x86\_64
    - p\_xf86-4.2-2-pci\_domain.diff:  
        \* fixes pci scanning on p650, p640 and others.
- xshared 
    - xpm-fix-for-682.diff (X.Org Bug #1920, Comment #18) 
        - removes restrictive checks about filename/path (Bug  
            \#48768)
        - more fixes (X.Org Bug #1920/1924)
        - obsoletes xpm-sec5.diff, xpm-secfix-imakefile-thomas.diff,  
            xpm-secfix-thomas
    - improved xpm-secfix-thomas.diff (Bug #43240)
    - p\_max-pci-devices.diff:  
        \* change PCI devices limit (Bug #43679)
    - p\_trans\_open\_max  
        \* change TRANS\_OPEN\_MAX limit (Bug #47111)
    - xpm-sec5.diff, xpm-secfix-thomas.diff,  
        xpm-secfix-imakefile-thomas.diff:  
        \* fixed more known xpm security problems (Bug #43240)
    - p\_xpm-sec.diff:  
        \* fixed known xpm security problems (CAN-2004-0687,CAN-2004-0688,  
        Bug #43240)
    - finally fixed tmp race in Xsession script (Bug #34253)
    - reverted broken security fix for Xsession script (see also  
        comment #16 of Bug#34253)
    - xfree86\_4.1.0\_glx\_dri\_integer\_overflow.diff:  
        \* The GLX and DRI code of the Xserver did not verify the "screen"  
        parameter in several functions. This failure leads to a  
        denial-of-service condition and probably to arbitrary code  
        execution as root. (CAN-2004-0093, CAN-2004-0094) (Bug #35206)
    - fixed tmp races in postinstall scripts and Xsession script  
        (Bug #34253)
    - fixed more buffer overflows in fontfile/ direc (#34296)
    - put together old and new bugs in fontfile-sec\_bufferoverflows
    - dirfile.diff:  
        \* at the same location just a few lines below the same problem
    - dirfile.diff:  
        \* A buffer overflow in the X server can be triggered by using a  
        malformed fonts.alias file. This bug can be used to gain local  
        root privilege (Bug #34296).
    - p\_pam\_setcred.diff:  
        \* Due to inproper checking of failure-conditions of pam\_setcred()  
        in XDM while using pam\_krb5 a user with valid login credentials  
        (Kerberos) may get root access to the system. (Bug #33788)
    - Disable sis.o module in km\_drm (it has unresolved symbols),  
        and remove a bad hack in Makefile.module. THis was discussed  
        with sndirsch@suse.de and mantel@suse.de.
    - p\_LTC3984.diff:  
        \* fixed double who entries for xterm (Bug #29126)
    - fixed build on sles8\*s390\*
    - This should fix bug #26187 
        - Make sux work even if no network available (bug #25315)
        - Workaround in sux due broken gnome session managment (bug  
            \#24052)
- yast2 
    - #42979: Module option during installation not copied into  
        installed system
    - #33929: Save As Dialogue may inadvertedly overwrite existing  
        files
    - added cfg\_displaymanager.scr
    - fixed package requirements for product slec
- yast2-x11 
    - removed cfg\_displaymanager.scr (moved to yast2 package)
- zebra 
    - fixed security bug \[#33993\] (CAN-2003-0858): local users  
        could send malicious netlink messages that cause DoS condition
    - fixed DoS condition, which exists in zebra when layer 3 access  
        is possible to the telnet management port  
        2601/tcp. (CAN-2003-0795) \[#32656\]
- zip 
    - reworked zip-longpath.patch, missing free's after malloc
    - added zip-longpath.patch (Bugzilla #47932)

2.2 Security fixes  
Service Pack 4 contains all security fixes released via the maintenance Web  
since the release of Service Pack 3.  
3\. Detailed ChangeLog  
The file "ChangeLog" in the toplevel of CD1 contains a summary of all the  
changes that were made for these updated packages. This gives you a good  
highlevel view of the changes and should be sufficient in most cases.  
You can of course always get the very detailed technical information about any  
package changes from the RPMs themselves by doing  
`<br></br>rpm --changelog -qp <FILENAME>.rpm<br></br>`  
where `<FILENAME>.rpm` is the name of the rpm.  
4\. Known Bugs

- Service Pack 3 is not installable with the install scripts if  
    you start the installation with Service Pack 4 If you boot with Service Pack 4 to start the installation, the  
    install.sh/install\_update\_rpms.sh scripts of Service Pack 3 will  
    abort with an error. Copy the install\_sp3\_rpms.sh script from  
    Service Pack 4 CD1 and use that to install Service Pack 3.
    
    There are no problems if you install the Service Packs with YOU,  
    which is the preferred method.
- SPident reports inconsistent Service pack levelSPident is a tool to identify the Service Pack level of the  
    current installation. SPident may report that the system has not reached the level  
    of Service Pack 4. This happens, when so-called "optional" updates,  
    which will not be automatically installed by YOU, are not manually  
    selected during update. To fully reach the level of Service Pack 4  
    you have to manually select these packages in YOU.
- The new k\_debug kernel did not fit on CD1 anymore. If you are using  
    the k\_debug kernel or wish to install this kernel, you need to install  
    the RPM from the second CD: `<br></br>rpm -Fvh /media/cdrom/UnitedLinux/i586/k_debug-2.4.21-278.i586.rpm<br></br>`
- The aacraid, e1000-new and bcm5700-new drivers will not be loaded  
    automatically for new hardware. In this case you have to enter  
    "insmod=&lt;DRIVER&gt;" at the boot prompt for installation.

5\. MD5SUMs

- CD1: 0a8593c25861f4fffd0d6fbcf3b1a9fd
- CD2: 682e8e4dfdb0b7a37f5eef1eba2c3294

| ![](http://support.novell.com/img/h_arrow.gif) | links to download packages |
|---|---|
|  |
| - [SUSE Linux Enterprise Server 8 for x86 (i386) (most recent package)](http://download.novell.com/Download?buildid=3E5CBzM8w0A%7E) |