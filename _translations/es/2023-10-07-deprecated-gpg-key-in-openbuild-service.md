---
title: Clave GPG obsoleta en OpenBuild Service
description: Arreglo rápido para forzar el reemplazo de la clave
date: 2023-10-07 00:00:00 -0300
permalink: /es/homelab/2023/10/07/deprecated-gpg-key-in-openbuild-service.html
lang: es
categories:
  - linux
tags:
  - open-build-service
  - opensuse
  - ubuntu
---

## OpenBuild Service {#openbuild-service}

La gente de openSuSE armó una buena solución de autoservicio para construir paquetes Linux, que creo que originalmente se llamaba openSuSE Build Service (OBS). Más tarde le cambiaron el nombre a OpenBuild Service para reflejar la capacidad de construir paquetes para más distros que solo openSuSE.

Más info: [Wikipedia](https://en.wikipedia.org/wiki/Open_Build_Service)

## Firma GPG {#gpg-signature}

Para proteger a la comunidad de cada distribución Linux, los creadores de cada solución de gestión de paquetes pensaron en firmar el contenido de los repositorios y los paquetes con claves GPG. Fue una idea muy inteligente y muy útil como medida básica de higiene/seguridad.

Esa funcionalidad de firma GPG está incluida en OBS.

## Obsolescencia de la clave DSA-1024 {#dsa-1024-key-deprecation}

Como muchas otras comunidades de empaquetado de software, Ubuntu dejó obsoletas las claves GPG basadas en DSA-1024 alrededor de 2016, lo que significa que apt ya no acepta esas claves.

## El problema {#the-issue}

En mi caso, creé un subproyecto para paquetes de Ubuntu 22.04. Como ya tenía un proyecto padre con una clave DSA-1024 que fue heredada por el nuevo subproyecto, todos los paquetes se firmaron con ella y luego el gestor de paquetes se quejaba de la clave sin dar demasiada información sobre el porqué.

{% highlight shell %}
Err:8 http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease
  The following signatures were invalid: 8FE63E73E027DE951D5EAFDBA6F3579ABB33D482
Reading package lists... Done
W: GPG error: http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease: The following signatures were invalid: 8FE63E73E027DE951D5EAFDBA6F3579ABB33D482
E: The repository 'http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04  InRelease' is not signed.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
{% endhighlight %}

Normalmente verías un mensaje que indica que falta la clave, o que no se acepta el conjunto de cifrado, o algo por el estilo. En este caso fue un mensaje genérico "The following signatures were invalid".

Al revisar las claves públicas instaladas, noté que mi repositorio usaba una clave dsa1024, mientras que todas las demás usaban rsa4096.

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

## La solución {#the-fix}

Al final, el culpable era el viejo tipo de clave obsoleto (mi proyecto home fue creado hace mucho tiempo). No pude encontrar la forma de crear una nueva clave GPG en la [web UI](https://build.opensuse.org); o no está ahí o yo estoy ciego.

Vamos a usar el cliente/herramienta CLI de OBS: osc.

En la man page de osc podemos encontrar:

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


En una máquina Linux, debes seguir este procedimiento:


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


En el cliente, después de reimportar la clave pública, deberías ver que ya no es dsa1024.

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
