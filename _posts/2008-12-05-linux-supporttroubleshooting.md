---
title: Linux support/troubleshooting
description: "Overview of Novell's supportconfig bash script for collecting system data from SLES/Linux systems for remote troubleshooting."
date: 2008-12-05 19:41:24 -0300
author: Ciro Iriarte
permalink: /index.php/2008/12/05/linux-supporttroubleshooting/
lang: en
categories:
  - linux
tags:
  - sles
  - troubleshooting
---

Dealing with Novell Linux support found about their supportconfig script, it’s really useful while troubleshooting systems remotely (or on-site :D).

It’s basically a bash script that collects data about a linux system (it was made for SLES, but should work with any linux). The result is a nice tarball that you can take with you to analyze the system offsite.

The software: http://www.novell.com/communities/node/2332/supportconfig-linux  
Basic health check guide: http://www.novell.com/communities/node/4097/basic-server-health-check-supportconfig
