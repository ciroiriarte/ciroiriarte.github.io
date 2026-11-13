---
title: Automating Snapshots on Symmetrix VMAX with PowerShell
description: "PowerShell script to automate snapshots on an EMC Symmetrix VMAX for backing up MS SQL Server Analysis Services, using PSExec and Solutions Enabler."
date: 2011-07-07 10:26:25 -0400
permalink: /en/index.php/2011/07/07/symsnaponpowershell/
lang: en
categories:
  - storage-backup
tags:
  - emc
  - powershell
  - windows
---

I recently had to automate the backup of an application that NetBackup doesn't support, specifically MS SQL Server Analysis Services. The idea is basically to take a cold backup without leaving the application out of service for too long.

<!--more-->

For illustration, the production server has a VMax Meta presented to it, and the snapshot of that Meta must be mounted on a secondary server to copy the data to tape. The script runs on the secondary server, where we need PSExec, and Solutions Enabler must be installed on both servers. It is also assumed that the snapshot pool and the required group are already prepared.

The script is run from the auxiliary/secondary server by a (Windows) domain user with administrative privileges on the production server, so PSExec doesn't require a password.

**Procedure**

1. Stop the service on the production server
2. Flush the FS cache, sending all writes to disk
3. Create the snapshot
4. Start the service on the production server
5. Mount the snapshot on the secondary server
6. Send the data to tape
7. Destroy the snapshot

I decided to take a quick look at PowerShell and, putting together a collage of info from the internet, this is what came out.

{% highlight powershell %}
##
# Clonado de BD SQL Analisis Services
##
# Changelog
# ---------
# v0.1 - Ciro Iriarte
# - Initial release

param($accion)

$Global:HOST_ORIGEN="produccion1"
#$Global:USER="usuario"
#$Global:PASS="blah"
$Global:DRIVE_ORIGEN="E:"
$Global:DRIVE_DESTINO="W:"
$Global:SERVICIO_ORIGEN="MSSQLServerOLAPService"

$Global:GRUPO_SNAP="SNAP_SSAS"
$Global:SID="612"
$Global:SYMDEV_DESTINO="0473"

function crear ()
{
	write-host "Deteniendo el servicio SSAS en " $HOST_ORIGEN
	#psexec \\$HOST_ORIGEN -u $USER -p $PASS net stop $SERVICIO_ORIGEN
	psexec \\$HOST_ORIGEN net stop $SERVICIO_ORIGEN

	#psexec \\$HOST_ORIGEN -u $USER -p $PASS symntctl flush -drive $DRIVE_ORIGEN
	psexec \\$HOST_ORIGEN symntctl flush -drive $DRIVE_ORIGEN

	sleep 60

	write-host "Creando snapshot"
	symsnap -g $GRUPO_SNAP create -nop
	symsnap -g $GRUPO_SNAP activate -consistent -nop

	write-host "Montando snapshot"
	symntctl rescan
	symntctl mount -drive $DRIVE_DESTINO -sid $SID -symdev $SYMDEV_DESTINO

	write-host "Levantando el servicios SSAS en " $HOST_ORIGEN
	#psexec \\$HOST_ORIGEN -u $USER -p $PASS net start $SERVICIO_ORIGEN
	psexec \\$HOST_ORIGEN net start $SERVICIO_ORIGEN
}

function destruir ()
{
	write-host "Eliminando snapshot"
	symntctl umount -drive $DRIVE_DESTINO -sid $SID -symdev $SYMDEV_DESTINO
	symsnap -g $GRUPO_SNAP terminate -nop
	symntctl rescan
}

function consulta ()
{
	symsnap -g $GRUPO_SNAP query
}

## MAIN

switch($accion)
{
	"start" { crear }
	"stop" { destruir }
	"status" { consulta }
	default { write-host "Sintaxis:" $myinvocation.mycommand.name "start|stop|status" }
}
{% endhighlight %}
