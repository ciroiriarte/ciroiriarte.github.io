---
title: "Ejecutando SCO Openserver 5.0.7 en VirtualBox"
description: "Guía técnica para virtualizar SCO OpenServer 5.0.7 en VirtualBox, con la configuración de la VM, el procedimiento de instalación, la configuración de red y una solución para el Guru Meditation."
date: 2009-10-08 16:38:22 -0400
permalink: /es/index.php/2009/10/08/running-sco-openserver-5-0-7-in-virtualbox/
lang: es
categories:
  - virtualization
tags:
  - virtualbox
  - sco
---

**Actualización:** *A partir de VirtualBox 3.0.10, Openserver 5.0.7 no debería requerir soluciones alternativas para instalarse, solo falta el soporte SCSI… (revisa los reportes de bugs listados).*

Un cliente necesitaba reemplazar un antiguo servidor SCO<!--more--> que ejecutaba Foxplus; dado que es poco probable que Openserver 5 funcione con hardware nuevo, la única vía disponible en este caso era virtualizar el servidor Openserver. A la fecha, iBCS o ABI o como se llame la última encarnación, no funcionó para nosotros.

Usamos SLES10SP2@x86\_64 como host, pero cualquier host que ejecute VirtualBox debería servir. La instalación original se hizo en 3.0.4, pero estos pasos fueron probados en 3.0.8 para este artículo. La única funcionalidad faltante es la GUI.

**Configuración de la VM**

*General*

- Operating System: Other
- Version: Other

*System*

- Base Memory: 512M
- Enable ACPI
- Processor: 1
- Enable VT-x/AMD-V
- Enable Nested Paging (mostró mejora en las pruebas de creación de archivos)

*Hard Disks*

- IDE Controller: 1 disco (6GB, dinámico). Ninguno de los drivers SCSI oficiales detecta los adaptadores SCSI virtualizados de VirtualBox

*CD/DVD Drive*

- Image mounted: OpenServer-5.0.7Hw-10Jun05\_1800.iso

*Network*:

- Intel PRO/1000 MT Desktop

**Procedimiento de instalación** (solo listaré los cambios relevantes en cada paso)

- *Preparing your disk and choosing software* -> *Optional Software*: En "Graphical Environment" debemos deseleccionar "X Server and Graphics Drivers", ya que Video Configuration Manager provoca "Guru Meditation".

- *Configuring optional software* -> *Network card*: Diferido (no funcionará antes de instalar MP5)

**Post instalación**

*Instalar MP5*

- Monta osr507suppcd5.iso. Ejecuta "custom" y selecciona "Software" -> "Install New" -> "From <your_vm_name>" -> "Media Device" = CD-ROM Drive 0

Selecciona e instala**:**

- SCO Openserver Release 5.0.7 Maintenance Pack 5
- SCO Openserver Release 5.0.7 Graphics and NIC Drivers

Reinicia

*Configuración de red*

- Ejecuta scoadmin –&gt; Networks –&gt; Network Configuration Manager –&gt; Hardware –&gt; Add new LAN Adapter. Debería detectar la NIC Intel.

**Corregir el Guru Meditation al apagar**

Los eventos de apagado para reiniciar o apagar también disparan “Guru Meditation”. Por ahora encontré una solución para el apagado, pero el reinicio sigue roto.

Edita /etc/conf/pack.d/uapm/space.c, busca la función "uapm_offstates" de tipo "ulong_t" y modifica los eventos 0 y 3 para que disparen "APMPWR_OFF".

Aquí tienes un parche:

```diff
--- space.c.orig 2009-10-08 16:38:00.000000000 -0400
+++ space.c 2009-10-08 16:38:00.000000000 -0400
@@ -76,10 +76,10 @@
 */

 ulong_t uapm_offstates[] = {
-  APMPWR_READY, /* 0 AD_HALT No auto reboot */
+  APMPWR_OFF, /* 0 AD_HALT No auto reboot */
   APMPWR_READY, /* 1 AD_BOOT Auto reboot */
   APMPWR_READY, /* 2 AD_IBOOT (same as AD_BOOT) */
-  APMPWR_SUSPEND, /* 3 AD_PWRDOWN Turn off power */
+  APMPWR_OFF, /* 3 AD_PWRDOWN Turn off power */
   APMPWR_STANDBY, /* 4 AD_PWRNAP Turn off if no A/C */
   APMPWR_SUSPEND, /* (anything else) (essentially AD_HALT) */
 };
```

Reenlaza el kernel y reinicia:

{% highlight shell %}
cd /etc/conf/cf.d
./link_unix
{% endhighlight %}

**Reportes de bugs pendientes**:

- http://www.virtualbox.org/ticket/3953
- http://www.virtualbox.org/ticket/5096
- http://www.virtualbox.org/ticket/5164

Eso es todo, espero que los muchachos de Sun puedan arreglar estos problemas en futuras versiones…
