---
title: Automatizando snapshots no Symmetrix VMAX com PowerShell
description: "Script PowerShell para automatizar snapshots em um EMC Symmetrix VMAX para backup do MS SQL Server Analysis Services, usando PSExec e Solutions Enabler."
date: 2011-07-07 10:26:25 -0400
permalink: /pt/index.php/2011/07/07/symsnaponpowershell/
lang: pt
categories:
  - storage-backup
tags:
  - emc
  - powershell
  - windows
---

Recentemente tive que automatizar o backup de uma aplicação que o NetBackup não suporta, especificamente o MS SQL Server Analysis Services. A ideia é basicamente fazer um backup a frio sem deixar a aplicação fora do ar por muito tempo.

<!--more-->

A título ilustrativo, o servidor de produção tem uma Meta de um VMax apresentada, e o snapshot dessa Meta deve ser montado em um servidor secundário para copiar os dados para fita. O script roda no servidor secundário, onde precisamos do PSExec, e o Solutions Enabler deve estar instalado em ambos os servidores. Também se assume que o pool para snapshots e o grupo necessário já estão preparados.

O script é executado a partir do servidor auxiliar/secundário por um usuário de domínio (Windows) com privilégios administrativos no servidor de produção, assim o PSExec não exige senha.

**Procedimento**

1. Parar o serviço no servidor de produção
2. Esvaziar o cache do FS, enviando todas as escritas para o disco
3. Criar o snapshot
4. Iniciar o serviço no servidor de produção
5. Montar o snapshot no servidor secundário
6. Enviar os dados para fita
7. Destruir o snapshot

Decidi dar uma olhada rápida no PowerShell e, montando uma colagem de informações da internet, foi isso que saiu.

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
