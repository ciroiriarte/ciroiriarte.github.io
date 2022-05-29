---
id: 153
title: 'Automatizando Snapshots en Symmetrix VMAX con Powershell'
date: '2011-07-07T10:26:25-04:00'
author: ciroiriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=153'
permalink: /index.php/2011/07/07/symsnaponpowershell/
categories:
    - Uncategorized
---

Hace poco me tocó automatizar el backup de una aplicación no soportada por NetBackup, puntualmente MS SQL Server Analysis Services. La idea es básicamente realizar un backup en frío sin dejar a la aplicacion fuera de servicio por mucho tiempo.

A modo ilustrativo, el equipo productivo tiene presentada una Meta de un VMax y el snapshot de esta Meta debe ser montado en un equipo secundario para copiar los datos a cinta. El script corre en el equipo secundario donde necesitamos PSExec y Solutions Enabler debe estar instalado en ambos equipos. Además se asume que el pool para snapshots y el grupo necesario ya están preparados.

El script es ejecutado desde el equipo auxiliar/secundario por un usuario del dominio (Windows) con privilegios administrativos en el equipo productivo, de esta forma PSExec no requiere contraseña.

**Procedimiento**

1. Parar Servicio en equipo productivo
2. Vaciar el cache de FS, enviando todas las escrituras a disco
3. Crear snapshot
4. Iniciar Servicio en equipo productivo
5. Montar snapshot en equipo secundario
6. Enviar los datos a cinta
7. Destruir snapshot

Decidí darle una ojeada rápida a PowerShell y armando un collage con info de internet esto es lo que salió.

> ```
>  
> ##
> # Clonado de BD SQL Analisis Services
> ##
> # Changelog
> # ---------
> # v0.1 - Ciro Iriarte
> # - Initial release
> 
> param($accion)
> 
> $Global:HOST_ORIGEN="produccion1"
> #$Global:USER="usuario"
> #$Global:PASS="blah"
> $Global:DRIVE_ORIGEN="E:"
> $Global:DRIVE_DESTINO="W:"
> $Global:SERVICIO_ORIGEN="MSSQLServerOLAPService"
> 
> $Global:GRUPO_SNAP="SNAP_SSAS"
> $Global:SID="612"
> $Global:SYMDEV_DESTINO="0473"
> 
> function crear ()
> {
> 	write-host "Deteniendo el servicio SSAS en " $HOST_ORIGEN
> 	#psexec \\$HOST_ORIGEN -u $USER -p $PASS net stop $SERVICIO_ORIGEN
> 	psexec \\$HOST_ORIGEN net stop $SERVICIO_ORIGEN
> 
> 	#psexec \\$HOST_ORIGEN -u $USER -p $PASS symntctl flush -drive $DRIVE_ORIGEN
> 	psexec \\$HOST_ORIGEN symntctl flush -drive $DRIVE_ORIGEN
> 
> 	sleep 60
> 
> 	write-host "Creando snapshot"
> 	symsnap -g $GRUPO_SNAP create -nop
> 	symsnap -g $GRUPO_SNAP activate -consistent -nop
> 
> 	write-host "Montando snapshot"
> 	symntctl rescan
> 	symntctl mount -drive $DRIVE_DESTINO -sid $SID -symdev $SYMDEV_DESTINO
> 
> 	write-host "Levantando el servicios SSAS en " $HOST_ORIGEN
> 	#psexec \\$HOST_ORIGEN -u $USER -p $PASS net start $SERVICIO_ORIGEN
> 	psexec \\$HOST_ORIGEN net start $SERVICIO_ORIGEN
> }
> 
> function destruir ()
> {
> 	write-host "Eliminando snapshot"
> 	symntctl umount -drive $DRIVE_DESTINO -sid $SID -symdev $SYMDEV_DESTINO
> 	symsnap -g $GRUPO_SNAP terminate -nop
> 	symntctl rescan
> }
> 
> function consulta ()
> {
> 	symsnap -g $GRUPO_SNAP query
> }
> 
> ## MAIN
> 
> switch($accion)
> {
> 	"start" { crear }
> 	"stop" { destruir }
> 	"status" { consulta }
> 	default { write-host "Sintaxis:" $myinvocation.mycommand.name "start|stop|status" }
> }
> ```