---
title: Automatizzare gli snapshot su Symmetrix VMAX con PowerShell
description: "Script PowerShell per automatizzare gli snapshot su un EMC Symmetrix VMAX per il backup di MS SQL Server Analysis Services, usando PSExec e Solutions Enabler."
date: 2011-07-07 10:26:25 -0400
permalink: /it/index.php/2011/07/07/symsnaponpowershell/
lang: it
categories:
  - storage-backup
tags:
  - emc
  - powershell
  - windows
---

Di recente ho dovuto automatizzare il backup di un'applicazione non supportata da NetBackup, in particolare MS SQL Server Analysis Services. L'idea è sostanzialmente di fare un backup a freddo senza lasciare l'applicazione fuori servizio troppo a lungo.

<!--more-->

A titolo illustrativo, il server di produzione ha una Meta di un VMax presentata, e lo snapshot di questa Meta deve essere montato su un server secondario per copiare i dati su nastro. Lo script gira sul server secondario, dove ci serve PSExec, e Solutions Enabler deve essere installato su entrambi i server. Si presume inoltre che il pool per gli snapshot e il gruppo necessario siano già pronti.

Lo script viene eseguito dal server ausiliario/secondario da un utente di dominio (Windows) con privilegi amministrativi sul server di produzione, in modo che PSExec non richieda la password.

**Procedura**

1. Fermare il servizio sul server di produzione
2. Svuotare la cache del FS, inviando tutte le scritture su disco
3. Creare lo snapshot
4. Avviare il servizio sul server di produzione
5. Montare lo snapshot sul server secondario
6. Inviare i dati su nastro
7. Distruggere lo snapshot

Ho deciso di dare una rapida occhiata a PowerShell e, mettendo insieme un collage di informazioni trovate in rete, questo è quello che è uscito.

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
