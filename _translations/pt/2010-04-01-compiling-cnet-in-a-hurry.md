---
title: "Compilando o cnet com pressa"
description: "Como compilar e instalar o simulador de redes cnet no diretório home de um usuário no openSUSE, com modificações no Makefile para uma instalação local."
date: 2010-04-01 16:06:23 -0300
permalink: /pt/index.php/2010/04/01/compiling-cnet-in-a-hurry/
lang: pt
categories:
  - linux
  - networking
tags:
  - opensuse
  - simulation
---

Bom, temos um trabalho da faculdade, a ideia é simular uma rede e a ferramenta escolhida é o [cnet](http://www.csse.uwa.edu.au/cnet/ "CNET Simulator"). O ideal seria construir um pacote no OpenSUSE Build Service, mas o processo é meio lento e estamos com pressa. Aqui está o processo para instalá-lo na sua home. Construir o pacote está na minha lista de pendências….

<!--more-->

Vá [aqui](http://www.csse.uwa.edu.au/cnet/) e baixe a última versão (3.2.1 até hoje)

- Extraia no seu diretório de trabalho (~/tmp no meu caso)

{% highlight shell %}
ciro@mainwks:~/tmp> tar xf cnet-3.2.1.tgz
ciro@mainwks:~/tmp> cd cnet-3.2.1/
ciro@mainwks:~/tmp/cnet-3.2.1>
{% endhighlight %}

- Faça um backup do Makefile original. Ajuste os diretórios de destino no Makefile incluído para apontarem para a sua HOME.

{% highlight shell %}
ciro@mainwks:~/tmp/cnet-3.2.1> cp Makefile Makefile.orig
ciro@mainwks:~/tmp/cnet-3.2.1> vi Makefile
{% endhighlight %}

**Aqui vai um diff**:

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

- Instale o TCL e o TK; segundo a documentação, a versão 8.4 é o mínimo exigido. O procedimento depende da distribuição usada, aqui está o caso do OpenSUSE 11.2 (que inclui tk & tcl 8.5); instale também o libelf-devel. Certifique-se de já ter o make e o gcc instalados.

{% highlight shell %}
mainwks:/usr/src/packages/SPECS # zypper in tcl-devel tk-devel libelf-devel
{% endhighlight %}

- Voltando ao seu diretório de trabalho, compile os binários do cnet e a documentação web.


{% highlight shell %}
ciro@mainwks:~/tmp/cnet-3.2.1> make
ciro@mainwks:~/tmp/cnet-3.2.1> make install
ciro@mainwks:~/tmp/cnet-3.2.1> make www
{% endhighlight %}

- Agora ele deve estar instalado em ~/cnet. Precisamos definir algumas variáveis, para não ter que especificar o caminho completo do binário e para que ele encontre suas bibliotecas na compilação. Edite o ~/.profile e adicione as seguintes linhas no final do arquivo:

{% highlight shell %}
export CNETPATH=~/cnet/lib
export PATH=$PATH:~/cnet/bin</blockquote>
{% endhighlight %}

- Para habilitar as novas variáveis sem iniciar uma nova sessão:

{% highlight shell %}
ciro@mainwks:~> . ~/.profile
{% endhighlight %}

É isso…
