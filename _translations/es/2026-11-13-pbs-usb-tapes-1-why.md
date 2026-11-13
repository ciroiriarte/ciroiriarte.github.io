---
title: "Discos USB como cintas para Proxmox Backup Server (1/3): por qué y qué hay de nuevo"
description: "Por qué podrías querer jobs de cinta de PBS sobre discos USB comunes, qué incorporó mhVTL para lograrlo (cartuchos en disco crudo, bahías hot-plug, cifrado real en la unidad) y hacia dónde va."
date: 2026-11-13 10:00:00 -0300
permalink: /es/datacenter/2026/11/13/pbs-usb-tapes-1-why.html
lang: es
categories:
  - storage-backup
tags:
  - proxmox
  - pbs
  - tape
  - mhvtl
series: pbs-usb-tapes
series_part: 1
series_title: "Por qué y qué hay de nuevo"
---

Un datastore de Proxmox Backup Server es almacenamiento en línea. Es rápido, deduplicado y está siempre disponible. Ese es el problema: quien consiga root en el host PBS, o un token con suficientes privilegios, también puede llegar a él. La copia que tiene que sobrevivir a un ransomware, a un `rm` tecleado con los dedos gordos o a un incendio debería estar en un estante, desconectada, idealmente en otro edificio.

La respuesta clásica es la cinta, y PBS tiene muy buen soporte para cintas. Pero una unidad LTO cuesta más de lo que muchos sitios pequeños gastan en todo el servidor de backup. Un puñado de discos USB casi no cuesta nada, y alguien puede llevárselos a casa el viernes.

Así que la idea de esta serie es simple: **hacer que los discos USB se comporten como cintas**, y dejar que PBS haga con las cintas lo que ya hace bien.

<!--more-->

Esta es la parte 1 de una serie de tres:

1. **Por qué y qué hay de nuevo** (este post): el razonamiento, y lo nuevo en mhVTL que lo hace posible.
2. [El procedimiento por CLI](/es/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html): mhVTL y PBS desde la shell, para copiar y pegar.
3. [El procedimiento con point & click](/es/datacenter/2026/11/13/pbs-usb-tapes-3-gui.html): lo mismo, desde el dashboard de mhVTL Control y la interfaz web de PBS.

## Lo que PBS ya ofrece {#what-pbs-already-offers}

Antes de construir nada, vale la pena revisar qué ofrece ya PBS.

**Los clientes nunca escriben directamente a cinta.** PVE y `proxmox-backup-client` siempre respaldan a un datastore. Luego un job de backup a cinta copia snapshots del datastore a un *media pool* ([documentación de PBS, Tape Backup](https://pbs.proxmox.com/docs/tape-backup.html)). Eso encaja con el plan: el datastore sigue siendo la primera copia rápida, y los discos pasan a ser la segunda copia, fuera de línea.

Para sacar una copia del datastore, PBS tiene tres opciones:

- Los **sync jobs** copian snapshots entre datastores, localmente o hacia un PBS remoto (pull, y push desde PBS 3.3).
- Los **removable datastores** (desde [PBS 3.3](https://www.proxmox.com/en/about/company-details/press-releases/proxmox-backup-server-3-3)) ponen un datastore completo en un disco USB formateado con ext4 o XFS. Lo conectas, sincronizas hacia él y lo desmontas ([documentación de PBS, Removable Datastores](https://pbs.proxmox.com/docs/storage.html)).
- Los **tape backup jobs** escriben snapshots en *media sets*, con políticas de asignación y retención, un catálogo de lo que hay en cada cinta, y cifrado en la unidad.

Para uno o dos discos, un removable datastore es más simple, y probablemente la mejor respuesta. La semántica de cinta empieza a rendir cuando rotas varios discos y quieres que PBS lleve la cuenta:

| | Removable datastore | Job de cinta sobre un disco crudo de mhVTL |
|---|---|---|
| Software adicional | Ninguno | mhVTL (módulo del kernel y daemons) |
| Formato en disco | ext4/XFS con un chunk store | Sin filesystem, una imagen secuencial de cinta |
| Copia | Incremental: un sync copia solo los chunks nuevos | Copia completa por media set (con `--allocation always`) |
| Más grande que un disco | No | Un media set puede abarcar varios discos |
| Al retirar el disco | Desmontaje limpio, o el datastore queda en modo mantenimiento | Cartucho exportado al mail slot, datos ya volcados a disco |
| Rotación de N discos | A mano | Media pool con políticas de asignación y retención |
| ¿Qué hay en el disco del cajón? | Conéctalo y mira | PBS mantiene un catálogo de medios fuera de línea |
| Cifrado | Del lado del cliente | Del lado del cliente, o la clave del pool ([AES-256-GCM en la unidad](#real-encryption)) |
| Restauración | Navegar y restaurar directamente | Primero restaurar el media set a un datastore |
| Otro software de backup | Solo PBS | Cualquiera que hable con una librería de cintas |
| Pasar a LTO real más adelante | Empezar de cero | Mismos pools y jobs, cambias el hardware |

Dos pequeños bonus del disco crudo: ningún componente de escritorio intenta montarlo automáticamente, y un disco retirado en el momento equivocado no tiene filesystem al que hacerle `fsck`.

## Qué cambió en mhVTL {#what-changed-in-mhvtl}

[mhVTL](https://github.com/markh794/mhvtl) es una librería de cintas virtual para Linux. Emula unidades de cinta SCSI y cambiadores robóticos lo bastante bien como para que las aplicaciones de backup no noten la diferencia. Tradicionalmente, cada cartucho virtual es un directorio de archivos bajo `/opt/mhvtl`. Eso sirve para pruebas, pero un cartucho atrapado dentro de un filesystem en el servidor de backup no le sirve a nadie cuando el edificio se incendia.

En las últimas semanas entró a upstream un conjunto de cambios que permite que los cartuchos vivan en discos removibles. Los escribí yo; Mark Harvey, el mantenedor de mhVTL, los revisó y los integró.

### Cartuchos en disco crudo {#raw-disk-cartridges}

Ahora un dispositivo de bloques completo puede ser un cartucho ([#214](https://github.com/markh794/mhvtl/pull/214)). Un disco es una cinta. Sin tabla de particiones ni filesystem.

El primer megabyte se deja vacío, para que nada en el host piense que el disco vale la pena montarlo. Después vienen un superbloque (más una copia espejo) con el código de barras y el layout, la memoria del cartucho (MAM) y el flujo de datos.

`mhvtl-raw-format` inicializa un disco y, desde [#293](https://github.com/markh794/mhvtl/pull/293), también escribe una MAM correcta, así que la unidad conoce la capacidad desde la primera escritura.

Cuando una aplicación de backup escribe un filemark o descarga la cinta, mhVTL vuelca el disco (`fdatasync`) antes de responder. En un entorno de pruebas, los discos sacados del mail slot y vueltos a conectar se leyeron intactos todas las veces.

### Bahías hot-plug {#hot-plug-bays}

`mhvtl-bay-monitor` vigila udev y asocia un puerto USB físico (su nombre estable en `/dev/disk/by-path`, nunca `/dev/sdX`) con los mail slots de una librería. Los mail slots son la estación de importación/exportación de una librería: mhVTL los llama MAP, PBS los llama slots I/E.

Conectas un disco formateado al dock y su cartucho aparece en un mail slot. Lo desconectas y el cartucho desaparece de la librería. Varios cambios posteriores cubren los casos límite:

- un disco formateado en el lugar ([#294](https://github.com/markh794/mhvtl/pull/294))
- un monitor reiniciado con un disco en el dock ([#296](https://github.com/markh794/mhvtl/pull/296))
- varios docks en una misma librería ([#298](https://github.com/markh794/mhvtl/pull/298))

Para PBS esto se ve exactamente como un operador que se acerca a una librería real y deja una cinta en el mail slot.

### Cifrado real {#real-encryption}

Hasta hace poco, el cifrado de unidad de mhVTL era *simulado*. La unidad aceptaba la clave y escribía los datos en texto plano, con la clave en el encabezado de cada bloque. Bien para probar una aplicación, pero inútil para discos que salen del edificio.

Desde [#328](https://github.com/markh794/mhvtl/pull/328), la unidad cifra cada bloque con AES-256-GCM. La clave se deriva de lo que envía la aplicación más una sal aleatoria guardada en la memoria del cartucho, y nunca se escribe en el disco.

Ese es el comportamiento por defecto en las unidades que soportan cifrado, así que un media pool de PBS con clave de cifrado ahora te da un disco cifrado. En un entorno de pruebas, busqué en el disco crudo muestras de un archivo aleatorio que había respaldado: estaban todas en el datastore de PBS, y ninguna en el disco cifrado.

### Compresión más rápida {#faster-compression}

LZ4 y Zstandard se sumaron a los viejos zlib y LZO. No importa mucho para PBS, cuyos chunks ya vienen comprimidos, y mhVTL guarda un bloque tal cual cuando la compresión no lo reduce.

### Un dashboard {#a-dashboard}

[mhVTL Control](https://github.com/ciroiriarte/mhvtl-control) es un proyecto aparte mío: una API REST y un dashboard web para mhVTL. Muestra las librerías en vivo, edita la configuración con un paso de verificación antes de aplicarla, y formatea discos crudos. La parte 3 lo usa para la versión point & click.

## Hacia dónde va esto {#where-this-is-going}

En esta serie, el dock USB cuelga del propio host PBS. El siguiente paso es mover los discos a una caja aparte.

mhVTL ahora puede exportar sus librerías por **iSCSI**: `mhvtl-fabrics` ([#337](https://github.com/markh794/mhvtl/pull/337)) aprovisiona los targets sobre el backend TCMU, que todavía es experimental. El soporte de target **Fibre Channel** también está en camino. Con cualquiera de los dos, una caja aparte con bahías hot-swap pasa a ser "la librería de cintas", y el host PBS ve una librería de cintas común en la red. Sin mhVTL en el servidor de backup, sin cable USB hacia él, y con los discos rotados en la caja que los contiene.

Eso merece su propio post cuando haya pasado por un entorno de pruebas. Por ahora, la [parte 2](/es/datacenter/2026/11/13/pbs-usb-tapes-2-cli.html) construye la versión local desde la shell.

---

{% include series-nav.html %}
