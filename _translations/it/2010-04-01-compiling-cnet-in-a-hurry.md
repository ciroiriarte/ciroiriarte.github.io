---
title: "Compilare cnet di fretta"
description: "Come compilare e installare il simulatore di reti cnet nella home di un utente su openSUSE, con le modifiche al Makefile per un'installazione locale."
date: 2010-04-01 16:06:23 -0300
permalink: /it/index.php/2010/04/01/compiling-cnet-in-a-hurry/
lang: it
categories:
  - linux
  - networking
tags:
  - opensuse
  - simulation
---

Bene, abbiamo un compito per l'università, l'idea è simulare una rete e lo strumento scelto è [cnet](http://www.csse.uwa.edu.au/cnet/ "CNET Simulator"). L'ideale sarebbe costruire un pacchetto nell'OpenSUSE Build Service, ma il processo è piuttosto lento e abbiamo fretta. Ecco il procedimento per installarlo nella tua home. Costruire il pacchetto è nella mia lista di cose da fare….

<!--more-->

Vai [qui](http://www.csse.uwa.edu.au/cnet/) e scarica l'ultima versione (3.2.1 alla data di oggi)

- Estraila nella tua directory di lavoro (~/tmp nel mio caso)

{% highlight shell %}
ciro@mainwks:~/tmp> tar xf cnet-3.2.1.tgz
ciro@mainwks:~/tmp> cd cnet-3.2.1/
ciro@mainwks:~/tmp/cnet-3.2.1>
{% endhighlight %}

- Fai un backup del Makefile originale. Modifica le directory di destinazione nel Makefile incluso in modo che puntino alla tua HOME.

{% highlight shell %}
ciro@mainwks:~/tmp/cnet-3.2.1> cp Makefile Makefile.orig
ciro@mainwks:~/tmp/cnet-3.2.1> vi Makefile
{% endhighlight %}

**Ecco un diff**:

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

- Installa TCL e TK; secondo la documentazione serve almeno la versione 8.4. La procedura dipende dalla distribuzione usata, ecco il caso di OpenSUSE 11.2 (che include tk & tcl 8.5); installa anche libelf-devel. Assicurati di avere già installati make e gcc.

{% highlight shell %}
mainwks:/usr/src/packages/SPECS # zypper in tcl-devel tk-devel libelf-devel
{% endhighlight %}

- Tornando alla tua directory di lavoro, compila i binari di cnet e la documentazione web.


{% highlight shell %}
ciro@mainwks:~/tmp/cnet-3.2.1> make
ciro@mainwks:~/tmp/cnet-3.2.1> make install
ciro@mainwks:~/tmp/cnet-3.2.1> make www
{% endhighlight %}

- Ora dovrebbe essere installato in ~/cnet. Dobbiamo definire alcune variabili, così non serve specificare il percorso completo del binario e può trovare le sue librerie per la compilazione. Modifica ~/.profile e aggiungi le seguenti righe alla fine del file:

{% highlight shell %}
export CNETPATH=~/cnet/lib
export PATH=$PATH:~/cnet/bin</blockquote>
{% endhighlight %}

- Per abilitare le nuove variabili senza avviare una nuova sessione:

{% highlight shell %}
ciro@mainwks:~> . ~/.profile
{% endhighlight %}

Tutto qui…
