---
id: 75
title: 'Compiling cnet in a hurry'
date: '2010-04-01T16:06:23-03:00'
author: ciroiriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=75'
permalink: /index.php/2010/04/01/compiling-cnet-in-a-hurry/
categories:
    - Linux
    - openSUSE
    - Projects
---

Well, we have an assignment for college, the idea is to simulate a network and the tool chosen is [cnet](http://www.csse.uwa.edu.au/cnet/ "CNET Simulator"). Ideally I would build a package for it in the OpenSUSE Build Service, but the process is kind of slow and we’re in a hurry. Here’s the process to install it in your home. Building the package is on my TODO list….

Go [here](http://www.csse.uwa.edu.au/cnet/) and download the latest version (3.2.1 as of today)

- Extract it in your working directory (~/tmp in my case)

{% highlight shell %}
ciro@mainwks:~/tmp> tar xf cnet-3.2.1.tgz
ciro@mainwks:~/tmp> cd cnet-3.2.1/
ciro@mainwks:~/tmp/cnet-3.2.1>
{% endhighlight %}

- Make a backup of original Makefile. Adjust the target directories in the included Makefile to point to your HOME.

{% highlight shell %}
ciro@mainwks:~/tmp/cnet-3.2.1> cp Makefile Makefile.orig
ciro@mainwks:~/tmp/cnet-3.2.1> vi Makefile
{% endhighlight %}

**Here’s a diff**:

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

- Install TCL and TK, from the documentation, version 8.4 is required as a minimum. The procedure depends on the distribution used, here’s the case of OpenSUSE 11.2 (which includes tk &amp; tcl 8.5), also install libelf-devel. Make sure you already have installed make and gcc.

{% highlight shell %}
mainwks:/usr/src/packages/SPECS # zypper in tcl-devel tk-devel libelf-devel
{% endhighlight %}

- Going back to your working directory, build cnet binaries and web based documentation.


{% highlight shell %}
ciro@mainwks:~/tmp/cnet-3.2.1> make
ciro@mainwks:~/tmp/cnet-3.2.1> make install
ciro@mainwks:~/tmp/cnet-3.2.1> make www
{% endhighlight %}

- Now, it should be installed in ~/cnet. We must define some variables, so we don’t need to specify the full path to the binary and it can find its libraries for compilation. Edit ~/.profile and add the following lines at the end of the file:

{% highlight shell %}
export CNETPATH=~/cnet/lib
export PATH=$PATH:~/cnet/bin</blockquote>
{% endhighlight %}

- To enable the new variables without starting a new session:

{% highlight shell %}
ciro@mainwks:~> . ~/.profile
{% endhighlight %}

That’s it…