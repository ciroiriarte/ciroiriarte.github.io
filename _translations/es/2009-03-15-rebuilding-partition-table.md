---
title: Reconstruyendo la tabla de particiones
description: "Cómo recuperar una tabla de particiones sobrescrita por una instalación de Linux abortada, usando la herramienta TestDisk para restaurar el esquema de particiones original."
date: 2009-03-15 20:00:26 -0400
permalink: /es/index.php/2009/03/15/rebuilding-partition-table/
lang: es
categories:
  - linux
  - storage-backup
tags:
  - testdisk
  - partitioning
  - recovery
---

Bueno, un ex compañero del colegio me trajo hoy su laptop y me dijo que de pronto dejó de funcionar (sí, claro).

Arranqué un disco de rescate de Linux y, tras inspeccionar el disco duro, vi que tenía 3 particiones:

> Disco /dev/sdb: 160.0 GB, 160041885696 bytes  
> 255 heads, 63 sectors/track, 19457 cylinders  
> Units = cilindros of 16065 \* 512 = 8225280 bytes  
> Disk identifier: 0xac23bbdb
> 
> Disposit. Inicio Comienzo Fin Bloques Id Sistema  
> /dev/sdb1 1 18748 150593278+ 83 Linux  
> /dev/sdb2 18749 19457 5695042+ 5 Extendida  
> /dev/sdb5 18749 19457 5695011 82 Linux swap / Solaris

Mmm, una partición Linux... ¿Pero cómo puede ser?, si es un tipo que solo usa Windows… Obviamente alguien la embarró en grande…

Intenté montar la primera partición, pero aparentemente no tenía un sistema de archivos válido. Saqué el disco, lo monté en una caja externa SATA <-> USB y lo conecté a mi laptop.

Lo primero fue revisar qué había en cada partición: la utilidad “file” solo decía “data”, pero “strings” sobre la partición mostraba que los datos de WinXP seguían en el disco. Aparentemente alguien arrancó la laptop con un instalador de Linux y abortó el proceso de instalación, no sin antes arruinar la tabla de particiones.

Primer pensamiento: “bueno, ¡borro las particiones actuales, creo una sola NTFS en todo el disco y los datos van a aparecer solos!”. Una vez creada la partición intenté acceder a los datos y fracasé miserablemente…

Entonces, obviamente, al ser una laptop probablemente tenga esas particiones de utilidades tan habituales hoy en día. ¿Cómo puedo adivinar la tabla de particiones a partir de los bits del disco?!

Después de investigar un rato descubrí [TestDisk](http://www.cgsecurity.org/wiki/TestDisk). Lo descargué, lo instalé, lo ejecuté contra el disco y unos minutos después ¡encontró la tabla de particiones original!!!

Tuve suerte, pero cada caso es distinto…
