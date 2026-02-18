---
id: 120
title: 'InstantClient RPMs'
date: '2011-01-03T00:59:38-03:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=120'
permalink: /index.php/2011/01/03/instantclient-rpms/
description: 'Sharing an enhanced Oracle InstantClient RPM spec file based on Remi Collet work, with added ORACLE_HOME, tnsnames.ora support, and other improvements for openSUSE Build Service.'
categories:
    - Linux
    - openSUSE
tags:
    - oracle
    - instantclient
    - rpm
    - opensuse
---

Well, a few years back I came across the Oracle InstantClient SPEC file prepared by Remi Collet, it was great to find it because the original RPMs made by Oracle don't help to build other packages depending on them.

<!-- more -->

I created a set of packages for a project using the original file from Remi. Some days later I enhanced them to make the use of the package by end users really smooth (ORACLE\_HOME environment variable, PATHs, etc). Also added other tweaks like a script to help building Perl-DBD-Oracle (not made by me) and was really happy with the results. Here’s where everything went downhill. There was a policy of only allowing software with source code on the openSUSE Build Service and the guys in charge just deleted the package from my repo project and I lost all the work done.

I had the recreation of the package on my ToDo list, but never had time to do it… A few days before, facing a new project involving Oracle, I went to Remi’s blog to look for the original SPEC file and luckily a month or so earlier [he modified it](http://blog.famillecollet.com/post/2010/11/12/RPM-Oracle-Instant-Client-11.2-en) to support the latest version of the client (to this date, 10.2.0.2).

I made some changes to it (them, as they were split in two) and I’m sharing the result here. As a final touch I’ll be addind tnsping to the packages, which is only included on the “thick” Oracle installation and maybe I’ll merge the “precomp\*” sub-package to “devel”.

**Files:**

[oracle-instantclient.spec](http://track.itsolutions.com.py/pub/oracle/oracle-instantclient.spec)  
[oracle-instantclient-11.2.0.2.0-37.1.nosrc.rpm](http://track.itsolutions.com.py/pub/oracle/oracle-instantclient.spec)

**My changes to Remi’s SPEC files:**

`<br></br>* Sun Jan 2 2011 Ciro Iriarte  11.2.0.2.0<br></br>- Added ORACLE_HOME definition<br></br>- Added tnsnames.ora example and required directory structure`

* Sat Jan 1 2011 Ciro Iriarte 11.2.0.2.0
- merge i386/x86_64 SPECs again
- fixed RPM Groups
- added Jean-Christophe Duberga's config script to help building Perl-DBD-Oracle
 (this wasn't documented on my first change in 2007, and was lost in OBS)
- skip RPATH and BYTECODE verifications in OBS builds
- renamed oracle-instantclient-basic to oracle-instantclient
- added unzip to BuildRequires
- general cleanup to make openSUSE 11.3 sanity checks happy
 o ToDo: Verify rpmlint filters
- add precomp and precomp-devel sub-packages

**Ref:**

 [Request allowing OIC in Build Service](https://features.opensuse.org/308967)