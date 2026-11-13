---
title: Integración del sistema operativo de los appliances de Apstra con FreeIPA
description: "Instalación del cliente IPA en appliances basados en Ubuntu para Apstra 4.2.0"
date: 2023-10-07 00:00:00 -0300
permalink: /es/homelab/sdn/2023/10/07/Integrating-Apstra-Appliances-OS-to-FreeIPA.html
lang: es
categories:
  - networking
  - security
tags:
  - apstra
  - freeipa
  - ubuntu
---

## Intención {#intent}

Si trabajas en cualquier entorno sensato con servidores Unix/Linux, seguro tienes implementado algún esquema centralizado de autenticación/autorización para el acceso al sistema operativo. Hoy en día eso significa LDAP o LDAP+Kerberos.

En mi caso, uso FreeIPA para el ecosistema Linux.

## Appliances de Apstra {#apstra-appliances}

Apstra es una herramienta de gestión de configuración y monitoreo para redes de Datacenter. No creo que sea un controlador SDN propiamente dicho (al menos en el concepto original del término) porque se parece más a herramientas de gestión de configuración como Puppet o Ansible. Sin embargo, es parte del ecosistema de herramientas SDN. 

Los appliances de Apstra están basados en Ubuntu LTS y, por suerte, tenemos el FreeIPA oficial disponible. Lo más probable es que tu representante de Juniper te diga que instalar paquetes oficiales de Ubuntu no está soportado.

Ya había implementado esto con Apstra 4.1.0, 4.1.1 y 4.1.2, pero la 4.2.0 necesita un ajuste esta vez. Funciona y, en mi experiencia, no interfiere con su funcionalidad; de todos modos, se recomienda probarlo en un laboratorio antes de pasar a producción. Procede bajo tu propio riesgo.

## Supuestos {#assumptions}
1. Tienes correctamente desplegados los appliances del ecosistema de Apstra (AOS, ZTP, workers)
2. La zona horaria correcta ya está configurada
3. La configuración del cliente NTP está lista
4. La configuración del cliente DNS está lista

## Configuración del lado del servidor FreeIPA {#freeipa-server-side-configuration}

Asegúrate de que el cliente tenga una entrada DNS.

{% highlight shell %}
ipa dnsrecord-add <your domain> <client shortname> --a-rec <IPv4 for the client>
ipa dnsrecord-add <your domain> <client shortname> --aaaa-rec <IPv6 for the client>
{% endhighlight %}

## Librerías de Python y AOS {#python-libraries-and-aos}

Bueno, este es un caso especial con Apstra 4.2.0. Hay módulos de Python instalados con *pip* por fuera de lo que proveen los paquetes basados en apt; aparentemente son necesarios para la plataforma Apstra pero rompen otras herramientas como ipa-client-install en el appliance AOS (no pasa con el appliance ZTP).

Appliance ZTP:

{% highlight shell %}
admin@apstra-ztp-03:~$ pip show cryptography
Name: cryptography
Version: 3.4.8
Summary: cryptography is a package which provides cryptographic recipes and primitives to Python developers.
Home-page: https://github.com/pyca/cryptography
Author: The Python Cryptographic Authority and individual contributors
Author-email: cryptography-dev@python.org
License: BSD or Apache License, Version 2.0
Location: /usr/lib/python3/dist-packages
Requires: 
Required-by: ansible-core, paramiko
{% endhighlight %}

Appliance AOS:

{% highlight shell %}
admin@apstra-os-03:~$ pip show cryptography
Name: cryptography
Version: 38.0.0
Summary: cryptography is a package which provides cryptographic recipes and primitives to Python developers.
Home-page: https://github.com/pyca/cryptography
Author: The Python Cryptographic Authority and individual contributors
Author-email: cryptography-dev@python.org
License: BSD-3-Clause OR Apache-2.0
Location: /usr/local/lib/python3.10/dist-packages
Requires: cffi
Required-by: paramiko
{% endhighlight %}

Nota que la versión de AOS es más nueva y que los módulos residen en /usr/local/lib en lugar de /usr/lib.

Una aplicación basada en contenedores como Apstra debería tener todo lo que necesita dentro del contenedor y no debería requerir ni alterar las librerías a nivel del host.

### Cómo afecta a ipa-client-install {#how-it-affects-ipa-client-install}
La herramienta de configuración de IPA falla con este error:

{% highlight shell %}
admin@apstra-os-03:~$ ipa-client-install 
Traceback (most recent call last):
  File "/usr/sbin/ipa-client-install", line 22, in <module>
    from ipaclient.install import ipa_client_install
  File "/usr/lib/python3/dist-packages/ipaclient/install/ipa_client_install.py", line 7, in <module>
    from ipaclient.install import client
  File "/usr/lib/python3/dist-packages/ipaclient/install/client.py", line 37, in <module>
    from ipalib import api, errors, x509
  File "/usr/lib/python3/dist-packages/ipalib/__init__.py", line 921, in <module>
    from ipalib.frontend import Command, LocalOrRemote, Updater
  File "/usr/lib/python3/dist-packages/ipalib/frontend.py", line 31, in <module>
    from ipalib.parameters import create_param, Param, Str, Flag
  File "/usr/lib/python3/dist-packages/ipalib/parameters.py", line 125, in <module>
    from ipalib.x509 import (
  File "/usr/lib/python3/dist-packages/ipalib/x509.py", line 91, in <module>
    @crypto_utils.register_interface(crypto_x509.Certificate)
**AttributeError: module 'cryptography.utils' has no attribute 'register_interface'. Did you mean: 'verify_interface'?**
{% endhighlight %}

Parece que FreeIPA usaba una función que no estaba pensada para usarse fuera de la implementación de capy/cryptography. El equipo de este último proyecto [decidió deprecar la función](https://github.com/pyca/cryptography/pull/7234) en la 38.0; instalar la librería más nueva por fuera de lo que provee la distro rompe el cliente de FreeIPA provisto por ella.

El proyecto FreeIPA [se está adaptando al cambio upstream](https://github.com/freeipa/freeipa/pull/6455), y debería estar incluido en la 4.11+

### La forma correcta de manejar esto {#the-correct-way-of-dealing-with-this}

#### Regla de oro {#golden-rule}

No se tocan las librerías provistas por la distribución Linux. Nunca.

#### Herramientas a disposición de quienes empaquetan software {#tools-at-hand-for-software-packagers}

Los contenedores son una solución actual de entrega de software que podría resolver esto. De hecho, Juniper usa contenedores docker. Estoy un poco perdido sobre por qué esto es un problema hoy con el appliance AOS de Apstra, pero empaquetar todas las dependencias dentro de los contenedores debería ser el curso de acción correcto.


### Workaround para clientes de Juniper {#workaround-for-juniper-customers}

Todo lo que podemos hacer hasta que Juniper empaquete Apstra correctamente como un conjunto de imágenes de contenedores es elegir el camino menos feo. En este caso, reconstruí un paquete de Ubuntu 23.04, que está basado en el código fuente de FreeIPA 4.9.11, para Ubuntu 22.04 (en el que se basa el appliance de Apstra).

Agregaremos el repositorio solo para AOS; el appliance ZTP puede usar los paquetes estándar. 

{% highlight shell %}
sudo sh -c 'echo "deb http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04/ /" | sudo tee /etc/apt/sources.list.d/home:ciriarte:apstra-4.2.0-fix.list'
sudo sh -c 'curl -fsSL https://download.opensuse.org/repositories/home:ciriarte:apstra-4.2.0-fix/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg > /dev/null'
sudo chmod a+r /etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg
sudo chmod a+r /etc/apt/sources.list.d/home:ciriarte:apstra-4.2.0-fix.list
sudo apt update
{% endhighlight %}

Después de agregar el repositorio, solo sigue el procedimiento de abajo.


## Configuración de los clientes {#clients-configuration}

Para cada cliente en cuestión, appliance ZTP, appliance AOS principal o workers, tendrás que ejecutar estos pasos.

### Validación de DNS {#dns-validation}
El DNS es crítico en este entorno, asegúrate de que los clientes realmente puedan ubicar tus servidores IP.

1. Prueba que el cliente esté realmente configurado
{% highlight shell %}
dig _ldap._tcp.<your domain> SRV
{% endhighlight %}

{:start="2"}
1. Prueba que todos los servidores esperados realmente respondan. Hay escenarios raros donde algunos servidores responden y otros no.
{% highlight shell %}
dig @<recursor/resolver 1 IP>  _ldap._tcp.<your domain> SRV
dig @<recursor/resolver 2 IP>  _ldap._tcp.<your domain> SRV
{% endhighlight %}

### Instalación y configuración del cliente {#client-installation--configuration}

El cliente FreeIPA es parte de los repositorios por defecto, simplemente instálalo con el gestor de paquetes:

{% highlight shell %}
sudo apt install -y freeipa-client
sudo ipa-client-install --mkhomedir --enable-dns-updates \
 --domain=<IPA domain in lowercase> --realm=<IPA domain in uppercase>
{% endhighlight %}

### Limitar el acceso SSH {#limit-ssh-access}

Es buena práctica limitar el acceso por SSH a los usuarios que realmente necesitan acceso al nodo. 

Pensándolo bien, esto debería hacerse con el módulo HBAC de FreeIPA + pam_sss.so. No recuerdo por qué en este entorno estamos fijando el grupo a nivel de sshd, lo mantendré por consistencia. **A revisar**

{% highlight shell %}
sudo sh -c 'echo "AllowGroups ssh-allow gapstra-administrator" >> /etc/ssh/sshd_config'
sudo systemctl restart sshd
{% endhighlight %}
