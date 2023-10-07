---
title: Deprecrecated GPG Key in OpenBuild Service
description: Quick fix to force key replacement
layout: post
author: ciroiriarte
categories:
- HomeLab
tags:
- OpenBuildService
- openSuSE
- Ubuntu
---

# OpenBuild Service

The openSuSE guys built a nice selfservice Linux package construction solution, which I believe was originally named openSuSE Build Service (OBS). Later it was renamed to OpenBuild Service to reflect the capability of building packages for more distros than just openSuSE.

More info: [Wikipedia](https://en.wikipedia.org/wiki/Open_Build_Service)

# GPG Signature

To protect the each Linux distribution community, the creators of each package management solution thought about signing the repository contents and packages with GPG keys. It was very inteligent and very useful as a basic hygienic measure.

Such GPG signature functionality is included in OBS.

# DSA-1024 key deprecation

As many other software packaging communities, Ubuntu deprecated DSA-1024 based GPG keys around 2016 which means apt doesn't accept those keys anymore.

# The issue

In my case, I created a sub-project for Ubuntu 22.04 packages. Given I already had a parent project with a DSA-1024 key that was inherited by the new sub-project, all the packages were signed by it and later the package manager would complain about the key without too much feedback regarding why.

{% highlight shell %}
Err:8 http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease
  The following signatures were invalid: 8FE63E73E027DE951D5EAFDBA6F3579ABB33D482
Reading package lists... Done
W: GPG error: http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease: The following signatures were invalid: 8FE63E73E027DE951D5EAFDBA6F3579ABB33D482
E: The repository 'http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease' is not signed.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
{% endhighlight %}

Usually you would see a message stating missing key, or not accepted cipher suite, or something along the lines. In this case, it was a generic "The following signatures were invalid" message.

Taking a look at the installed public keys, I spotted my repository was using a dsa1024 key, while all the rest used rsa4096.

{% highlight shell mark_lines="18" %}
admin@apstra-os-03:~$ sudo apt-key list
[sudo] password for admin:
Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d
instead (see apt-key(8)).
/etc/apt/trusted.gpg
--------------------
pub   rsa1024 2009-01-26 [SC]
      3AE6 3EC8 2014 45CB 55E6  B1EE DCCB 2270 E771 6B13
uid           [ unknown] Launchpad PPA for Stéphane Graber

pub   rsa4096 2017-02-22 [SCEA]
      9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid           [ unknown] Docker Release (CE deb) <docker@docker.com>
sub   rsa4096 2017-02-22 [S]

/etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg
---------------------------------------------------------
pub   dsa1024 2008-01-22 [SC] [expires: 2025-12-13]
      8FE6 3E73 E027 DE95 1D5E  AFDB A6F3 579A BB33 D482
uid           [ unknown] home:ciriarte OBS Project
<home:ciriarte@build.opensuse.org>

/etc/apt/trusted.gpg.d/ubuntu-keyring-2012-cdimage.gpg
------------------------------------------------------
pub   rsa4096 2012-05-11 [SC]
      8439 38DF 228D 22F7 B374  2BC0 D94A A3F0 EFE2 1092
uid           [ unknown] Ubuntu CD Image Automatic Signing Key (2012)
<cdimage@ubuntu.com>

/etc/apt/trusted.gpg.d/ubuntu-keyring-2018-archive.gpg
------------------------------------------------------
pub   rsa4096 2018-09-17 [SC]
      F6EC B376 2474 EDA9 D21B  7022 8719 20D1 991B C93C
uid           [ unknown] Ubuntu Archive Automatic Signing Key (2018)
<ftpmaster@ubuntu.com>
{% endhighlight %}

# The fix

In the end, the one to blame was the old deprecated key type (my home project was created a long time ago). I couln't find a way to create a new GPG key in the [web UI](https://build.opensuse.org), either it's not there or I'm just blind.

We'll be using the OBS CLI client/tool: osc. From the man page I spotted:

>        signkey
>              Manage Project Signing Key
>
>              osc signkey [--create|--delete|--extend] <PROJECT> osc signkey [--notraverse] <PROJECT>
>
>              This command is for managing gpg keys. It shows the public key by default. There is no way to download or upload the private  part  of  a
>              key by design.
>
>              However you can create a new own key. You may want to consider to sign the public key with your own existing key.
>
>              If  a  project  has  no  key,  the  key  from upper level project will be used (e.g. when dropping "KDE:KDE4:Community" key, the one from
>              "KDE:KDE4" will be used).
>
>              WARNING: THE OLD KEY CANNOT BE RESTORED AFTER USING DELETE OR CREATE
>
>              Usage:
>                  osc signkey [ARGS...]
>
>              Options:
>                  -h, --help  show this help message and exit
>                  --sslcert   fetch SSL certificate instead of GPG key
>                  --notraverse
>                              don't traverse projects upwards to find key
>                  --delete    delete the gpg signing key in this project
>                  --extend    extend expiration date of the gpg public key for this
>                              project
>                  --create    create new gpg signing key for this project

{% highlight shell %}
# First execution will ask for OBS credentials
osc

# We query the current key for the repository
osc signkey home:ciriarte:apstra-4.2.0-fix

# We create a new key for the repository
osc signkey --create home:ciriarte:apstra-4.2.0-fix

# We query the new key for the repository (should be different if the creation worked)
osc signkey home:ciriarte:apstra-4.2.0-fix

# We wipe all the binaries to force recreation and resign of the packages with the new key
osc wipebinaries --all home:ciriarte:apstra-4.2.0-fix freeipa
{% endhighlight %}


On the client, after reimporting the public key, you should see it's not a dsa1024 anymore.

{% highlight shell mark_lines="16" %}
root@apstra-os-03:~# apt-key list
Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead (see apt-key(8)).
/etc/apt/trusted.gpg
--------------------
pub   rsa1024 2009-01-26 [SC]
      3AE6 3EC8 2014 45CB 55E6  B1EE DCCB 2270 E771 6B13
uid           [ unknown] Launchpad PPA for Stéphane Graber

pub   rsa4096 2017-02-22 [SCEA]
      9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid           [ unknown] Docker Release (CE deb) <docker@docker.com>
sub   rsa4096 2017-02-22 [S]

/etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg
---------------------------------------------------------
pub   rsa4096 2023-10-07 [SC] [expires: 2025-12-15]
      37C6 811B 46C8 134C 5705  8A45 33E6 7F5C 0370 8C89
uid           [ unknown] home:ciriarte:apstra-4.2.0-fix OBS Project <home:ciriarte:apstra-4.2.0-fix@build.opensuse.org>

/etc/apt/trusted.gpg.d/ubuntu-keyring-2012-cdimage.gpg
------------------------------------------------------
pub   rsa4096 2012-05-11 [SC]
{% endhighlight %}