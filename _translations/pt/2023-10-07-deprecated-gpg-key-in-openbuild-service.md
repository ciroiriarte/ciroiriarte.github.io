---
title: Chave GPG obsoleta no OpenBuild Service
description: Correção rápida para forçar a substituição da chave
date: 2023-10-07 00:00:00 -0300
permalink: /pt/homelab/2023/10/07/deprecated-gpg-key-in-openbuild-service.html
lang: pt
categories:
  - linux
tags:
  - open-build-service
  - opensuse
  - ubuntu
---

## OpenBuild Service {#openbuild-service}

O pessoal do openSuSE montou uma boa solução de autoatendimento para construção de pacotes Linux, que acredito que originalmente se chamava openSuSE Build Service (OBS). Mais tarde foi renomeada para OpenBuild Service para refletir a capacidade de construir pacotes para mais distros além do openSuSE.

Mais informações: [Wikipedia](https://en.wikipedia.org/wiki/Open_Build_Service)

## Assinatura GPG {#gpg-signature}

Para proteger a comunidade de cada distribuição Linux, os criadores de cada solução de gerenciamento de pacotes pensaram em assinar o conteúdo dos repositórios e os pacotes com chaves GPG. Foi uma ideia muito inteligente e muito útil como medida básica de higiene/segurança.

Essa funcionalidade de assinatura GPG está incluída no OBS.

## Descontinuação da chave DSA-1024 {#dsa-1024-key-deprecation}

Como muitas outras comunidades de empacotamento de software, o Ubuntu descontinuou as chaves GPG baseadas em DSA-1024 por volta de 2016, o que significa que o apt não aceita mais essas chaves.

## O problema {#the-issue}

No meu caso, criei um subprojeto para pacotes do Ubuntu 22.04. Como eu já tinha um projeto pai com uma chave DSA-1024 que foi herdada pelo novo subprojeto, todos os pacotes foram assinados com ela e depois o gerenciador de pacotes reclamava da chave sem dar muita informação sobre o motivo.

{% highlight shell %}
Err:8 http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease
  The following signatures were invalid: 8FE63E73E027DE951D5EAFDBA6F3579ABB33D482
Reading package lists... Done
W: GPG error: http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease: The following signatures were invalid: 8FE63E73E027DE951D5EAFDBA6F3579ABB33D482
E: The repository 'http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease' is not signed.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
{% endhighlight %}

Normalmente você veria uma mensagem dizendo que a chave está faltando, ou que o conjunto de cifras não é aceito, ou algo nesse sentido. Neste caso, foi uma mensagem genérica "The following signatures were invalid".

Olhando as chaves públicas instaladas, notei que o meu repositório usava uma chave dsa1024, enquanto todas as outras usavam rsa4096.

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

## A solução {#the-fix}

No fim das contas, o culpado era o velho tipo de chave obsoleto (meu projeto home foi criado há muito tempo). Não consegui achar um jeito de criar uma nova chave GPG na [web UI](https://build.opensuse.org); ou não está lá, ou eu estou cego.

Vamos usar o cliente/ferramenta CLI do OBS: osc.

Na man page do osc podemos encontrar:

{% highlight text %}
       signkey
             Manage Project Signing Key

             osc signkey [--create|--delete|--extend] <PROJECT> osc signkey [--notraverse] <PROJECT>

             This command is for managing gpg keys. It shows the public key by default. There is no way to download or upload the private  part  of  a
             key by design.

             However you can create a new own key. You may want to consider to sign the public key with your own existing key.

             If  a  project  has  no  key,  the  key  from upper level project will be used (e.g. when dropping "KDE:KDE4:Community" key, the one from
             "KDE:KDE4" will be used).

             WARNING: THE OLD KEY CANNOT BE RESTORED AFTER USING DELETE OR CREATE

             Usage:
                 osc signkey [ARGS...]

             Options:
                 -h, --help  show this help message and exit
                 --sslcert   fetch SSL certificate instead of GPG key
                 --notraverse
                             don't traverse projects upwards to find key
                 --delete    delete the gpg signing key in this project
                 --extend    extend expiration date of the gpg public key for this
                             project
                 --create    create new gpg signing key for this project
{% endhighlight %}


Em uma máquina Linux, você precisa seguir este procedimento:


{% highlight shell %}

# Install the tool via your favorite package manager
sudo zypper in -y osc

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


No cliente, depois de reimportar a chave pública, você deve ver que ela não é mais dsa1024.

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
