---
title: "Compilando cnet a las apuradas"
description: "Cómo compilar e instalar el simulador de redes cnet en el directorio home de un usuario en openSUSE, con modificaciones al Makefile para una instalación local."
date: 2010-04-01 16:06:23 -0300
permalink: /es/index.php/2010/04/01/compiling-cnet-in-a-hurry/
lang: es
categories:
  - linux
  - networking
tags:
  - opensuse
  - simulation
---

Bueno, tenemos una tarea para la universidad, la idea es simular una red y la herramienta elegida es [cnet](http://www.csse.uwa.edu.au/cnet/ "CNET Simulator"). Lo ideal sería construir un paquete en el OpenSUSE Build Service, pero el proceso es algo lento y estamos apurados. Este es el proceso para instalarlo en tu home. Construir el paquete está en mi lista de pendientes….

<!--more-->

Ve [aquí](http://www.csse.uwa.edu.au/cnet/) y descarga la última versión (3.2.1 a la fecha de hoy)

- Extráela en tu directorio de trabajo (~/tmp en mi caso)

{% highlight shell %}
ciro@mainwks:~/tmp> tar xf cnet-3.2.1.tgz
ciro@mainwks:~/tmp> cd cnet-3.2.1/
ciro@mainwks:~/tmp/cnet-3.2.1>
{% endhighlight %}

- Haz un respaldo del Makefile original. Ajusta los directorios de destino del Makefile incluido para que apunten a tu HOME.

{% highlight shell %}
ciro@mainwks:~/tmp/cnet-3.2.1> cp Makefile Makefile.orig
ciro@mainwks:~/tmp/cnet-3.2.1> vi Makefile
{% endhighlight %}

**Aquí hay un diff**:

{% highlight shell %}
--- Makefile.orig       2010-04-01 13:43:33.000000000 -0400
+++ Makefile    2010-04-01 13:47:42.000000000 -0400
@@ -6,18 +6,19 @@
# Change the following 4 constants to suit your system:
#
# PREFIX defines the directory below which cnet will be installed.
-PREFIX         = /usr/local
-#PREFIX                = $(HOME)
+#PREFIX                = /usr/local
+PREFIX         = $(HOME)/cnet
#
# BINDIR defines the directory where the cnet binary will be installed.
BINDIR         = $(PREFIX)/bin
#
# CNETDIR defines the directory where cnet's support files will be installed.
-LIBDIR         = $(PREFIX)/lib/cnet
+#LIBDIR                = $(PREFIX)/lib/cnet
+LIBDIR         = $(PREFIX)/lib
#
# WWWDIR defines the directory to hold cnet's web-based documentation
-WWWDIR         = /home/httpd/html/cnet
-#WWWDIR                = $(HOME)/WWW/cnet
+#WWWDIR                = /home/httpd/html/cnet
+WWWDIR         = $(PREFIX)/www
#
# ---------------------------------------------------------------------
#
{% endhighlight %}

- Instala TCL y TK, según la documentación se requiere como mínimo la versión 8.4. El procedimiento depende de la distribución usada, aquí el caso de OpenSUSE 11.2 (que incluye tk & tcl 8.5), instala también libelf-devel. Asegúrate de tener ya instalados make y gcc.

{% highlight shell %}
mainwks:/usr/src/packages/SPECS # zypper in tcl-devel tk-devel libelf-devel
{% endhighlight %}

- Volviendo a tu directorio de trabajo, compila los binarios de cnet y la documentación web.


{% highlight shell %}
ciro@mainwks:~/tmp/cnet-3.2.1> make
ciro@mainwks:~/tmp/cnet-3.2.1> make install
ciro@mainwks:~/tmp/cnet-3.2.1> make www
{% endhighlight %}

- Ahora debería estar instalado en ~/cnet. Debemos definir algunas variables, para no tener que especificar la ruta completa al binario y para que encuentre sus bibliotecas al compilar. Edita ~/.profile y agrega las siguientes líneas al final del archivo:

{% highlight shell %}
export CNETPATH=~/cnet/lib
export PATH=$PATH:~/cnet/bin</blockquote>
{% endhighlight %}

- Para habilitar las nuevas variables sin iniciar una nueva sesión:

{% highlight shell %}
ciro@mainwks:~> . ~/.profile
{% endhighlight %}

Eso es todo…
