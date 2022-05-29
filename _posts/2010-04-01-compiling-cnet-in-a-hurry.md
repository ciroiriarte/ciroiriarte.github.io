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

```

<blockquote>
ciro@mainwks:~/tmp> tar xf cnet-3.2.1.tgz
ciro@mainwks:~/tmp> cd cnet-3.2.1/
ciro@mainwks:~/tmp/cnet-3.2.1></blockquote>
```

- Make a backup of original Makefile. Adjust the target directories in the included Makefile to point to your HOME.

> ```
> ciro@mainwks:~/tmp/cnet-3.2.1> cp Makefile Makefile.orig
> ciro@mainwks:~/tmp/cnet-3.2.1> vi Makefile
> ```

**Here’s a diff**:

```

<blockquote>
<div id="_mcePaste">--- Makefile.orig       2010-04-01 13:43:33.000000000 -0400</div>
<div id="_mcePaste">+++ Makefile    2010-04-01 13:47:42.000000000 -0400</div>
<div id="_mcePaste">@@ -6,18 +6,19 @@</div>
<div id="_mcePaste"># Change the following 4 constants to suit your system:</div>
<div id="_mcePaste">#</div>
<div id="_mcePaste"># PREFIX defines the directory below which cnet will be installed.</div>
<div id="_mcePaste">-PREFIX         = /usr/local</div>
<div id="_mcePaste">-#PREFIX                = $(HOME)</div>
<div id="_mcePaste">+#PREFIX                = /usr/local</div>
<div id="_mcePaste">+PREFIX         = $(HOME)/cnet</div>
<div id="_mcePaste">#</div>
<div id="_mcePaste"># BINDIR defines the directory where the cnet binary will be installed.</div>
<div id="_mcePaste">BINDIR         = $(PREFIX)/bin</div>
<div id="_mcePaste">#</div>
<div id="_mcePaste"># CNETDIR defines the directory where cnet's support files will be installed.</div>
<div id="_mcePaste">-LIBDIR         = $(PREFIX)/lib/cnet</div>
<div id="_mcePaste">+#LIBDIR                = $(PREFIX)/lib/cnet</div>
<div id="_mcePaste">+LIBDIR         = $(PREFIX)/lib</div>
<div id="_mcePaste">#</div>
<div id="_mcePaste"># WWWDIR defines the directory to hold cnet's web-based documentation</div>
<div id="_mcePaste">-WWWDIR         = /home/httpd/html/cnet</div>
<div id="_mcePaste">-#WWWDIR                = $(HOME)/WWW/cnet</div>
<div id="_mcePaste">+#WWWDIR                = /home/httpd/html/cnet</div>
<div id="_mcePaste">+WWWDIR         = $(PREFIX)/www</div>
<div id="_mcePaste">#</div>
<div id="_mcePaste"># ---------------------------------------------------------------------</div>
<div id="_mcePaste">#</div></blockquote>
```

<div>- Install TCL and TK, from the documentation, version 8.4 is required as a minimum. The procedure depends on the distribution used, here’s the case of OpenSUSE 11.2 (which includes tk &amp; tcl 8.5), also install libelf-devel. Make sure you already have installed make and gcc.

</div>> <div>```
> mainwks:/usr/src/packages/SPECS # zypper in tcl-devel tk-devel libelf-devel
> ```
> 
> </div>

<div>- Going back to your working directory, build cnet binaries and web based documentation.

</div>```

<blockquote>
<div>ciro@mainwks:~/tmp/cnet-3.2.1> make</div>
<div>ciro@mainwks:~/tmp/cnet-3.2.1> make install</div>
<div>ciro@mainwks:~/tmp/cnet-3.2.1> make www</div></blockquote>
```

- Now, it should be installed in ~/cnet. We must define some variables, so we don’t need to specify the full path to the binary and it can find its libraries for compilation. Edit ~/.profile and add the following lines at the end of the file:

```

<blockquote>
export CNETPATH=~/cnet/lib
export PATH=$PATH:~/cnet/bin</blockquote>
```

- To enable the new variables without starting a new session:

> ```
> ciro@mainwks:~> . ~/.profile
> ```

That’s it…