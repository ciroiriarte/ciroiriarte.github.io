---
title: Configurar dispositivos JunOS para Juniper Support Insights
description: Guía de configuración de los elementos de red para que vLWC pueda conectarse y extraer información.
date: 2023-12-27 00:00:00 -0300
permalink: /es/datacenter/networking/2023/12/27/setting-up-junos-devices-for-jsi.html
lang: es
categories:
  - networking
tags:
  - juniper
  - junos
---

## Intro {#intro}

Volviendo al camino "soportado", después de desplegar vLWC hay que preparar los dispositivos a monitorear. No encuentro una guía concisa para configurar correctamente los elementos de red para JSI, así que comparto mis notas después de un largo ejercicio de prueba y error.

<!--more-->

Tras leer el [JSI FAQ](https://www.juniper.net/documentation/us/en/software/jsi/jsi-on-jsp-faqs/topics/concept/jsi-faq-list.html), mi interpretación es que necesitamos lo siguiente en cada elemento de red:

1. NETCONF-SSH habilitado
2. SFTP habilitado
3. Una cuenta de usuario de proceso dedicada a JSI/vLWC con los permisos suficientes (principio de mínimo privilegio)

Una descripción general de cómo funciona la recolección de datos se encuentra en este [folleto](https://www.juniper.net/content/dam/www/assets/flyers/us/en/juniper-support-insights-security-and-privacy-overview.pdf)


{% include image.html url="/assets/img/2023-12-27_datacollection_overview.png" description="Imagen 1 - Resumen de la recolección de datos" alt="Resumen del flujo" width=1102 height=553 %}

## Prerrequisitos {#pre-requirements}

### Par de llaves SSH {#ssh-key-pair}

Necesitamos un par de llaves SSH pública/privada para el usuario. Puedes crearlo en cualquier máquina Linux. 

**Nota:** En el camino descubrí que JunOS no acepta llaves DSA, solo RSA.

{% highlight shell %}
ciro.iriarte@jhost01:~> ssh-keygen -t rsa -C "JSI process user" -f ~/.ssh/id_rsa-jsi
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): <-- make sure you input a passphrase
Enter same passphrase again: 
Your identification has been saved in /home/ciro.iriarte/.ssh/id_rsa-jsi
Your public key has been saved in /home/ciro.iriarte/.ssh/id_rsa-jsi.pub
The key fingerprint is:
SHA256:vMRG09Sd7BR1Q5P7B+9RakR2thSR3Md3bBOtYmm+VVc JSI process user
The key's randomart image is:
+---[RSA 3072]----+
|          .. o+&@|
|         o  . B*E|
|        o .  *.=O|
|       + .  = =o+|
|        S  + o =+|
|       o .  . +.+|
|        .    + .o|
|            .   .|
|                 |
+----[SHA256]-----+
{% endhighlight %}

Usarás:
- el contenido de *~/.ssh/id_rsa-jsi.pub* para configurar el acceso en los switches
- el contenido de *~/.ssh/id_rsa-jsi* + *la passphrase* se usarán en el portal de JSI para definir las credenciales de acceso.

### Comandos que deben estar permitidos. {#actual-commands-that-should-be-permitted}

Del FAQ mencionado antes obtenemos que los comandos que ejecutará el appliance son:

```
file list detail
show bgp summary
show chassis alarms
show chassis fpc
show chassis hardware extensive
show chassis routing-engine
show interfaces descriptions
show interfaces terse
show isis adjacency
show ospf neighbor
show rsvp neighbor
show system buffers
show system commit
show system core-dumps
show system license
show system uptime
show version
show vrrp detail
request support information
sftp
```

## Switches administrados por Apstra {#apstra-managed-switches}

### NETCONF {#netconf}
NETCONF ya es un requisito de Apstra, así que deberías tenerlo cubierto. Para validarlo rápidamente, puedes verificar que el puerto por defecto esté escuchando solicitudes de conexión:

{% highlight shell %}
ciro.iriarte@jhost01:~> nmap -p 830 ipf01-lf01.<TLD>
Starting Nmap 7.92 ( https://nmap.org ) at 2023-12-27 14:12 EST
Nmap scan report for ipf01-lf01.<TLD> (x.y.z.w)
Host is up (0.0012s latency).

PORT    STATE SERVICE
830/tcp open  netconf-ssh

Nmap done: 1 IP address (1 host up) scanned in 6.58 seconds
{% endhighlight %}

### SFTP {#sftp}
No estoy seguro de si SFTP es un requisito de Apstra, pero descubrí que todos los switches del entorno Apstra ya tenían el subsistema SFTP habilitado. Si no es tu caso, un configlet para habilitarlo es todo lo que necesitas.

### Usuario de proceso {#process-user}

En este entorno no tenemos TACACS+ (estamos en 2023, equipo de Juniper, ¿podemos tener LDAP de una vez?). Para fines prácticos, usaremos configlets de Apstra para crear un usuario de proceso desde Apstra.

#### Creación del configlet {#configlet-creation}

1. Ir a la página de creación de configlets.
{% include image.html url="/assets/img/2023-12-27_configlet00.png" description="Imagen 2 - Design --> Configlets" alt="Captura de pantalla de Apstra" width=259 height=613 %}
{% include image.html url="/assets/img/2023-12-27_configlet01.png" description="Imagen 3 - Botón Create configlet &quot;" alt="Captura de pantalla de Apstra" width=1352 height=262 %}

{:start="2"}
2. Completar los datos básicos del configlet

{% include image.html url="/assets/img/2023-12-27_configlet02.png" description="Imagen 4 - Creación del configlet" alt="Captura de pantalla de Apstra" width=955 height=720 %}

{:start="3"}
3. Pegar el siguiente contenido en el cuerpo y hacer clic en "Create"
```
system {
    login {
        class jsi-class {
            permissions view-configuration;
            allow-commands "(file list detail)|(show bgp summary)|(show chassis alarms)|(show chassis fpc)|(show chassis hardware extensive)|(show chassis routing-engine)|(show interfaces descriptions)|(show interfaces terse)|(show isis adjacency)|(show ospf neighbor)|(show rsvp neighbor)|(show system buffers)|(show system commit)|(show system core-dumps)|(show system license)|(show system uptime)|(show version)|(show vrrp detail)|(request support information)|(sftp)";
            deny-commands "(clear)|(file)|(file show)|(help)|(load)|(monitor)|(op)|(request)|(save)|(set)|(start)|(test)";
            deny-configuration all;
        }
        user svcjsi {
            full-name "JSI process user";
            uid 2007;
            class jsi-class;
            authentication {
                ssh-rsa "ssh-rsa your-key-super-long-string JSI process user";
            }
        }
    }
}
```

**Nota:** Asegúrate de que el UID sea único en tu entorno. Vi posts/notas/documentación al azar que referencian el UID 2000 (para otras implementaciones sin relación), y yo, súper astuto, lo cambié a 2001 para evitar chocar con configuraciones que todo el mundo podría estar copiando y pegando; resulta que quien implementó Apstra tuvo la misma idea.

#### Importar el configlet al blueprint {#importing-configlet-to-blueprint}

Para aplicar realmente el configlet creado a tus elementos de red, debes:

1. Importar el configlet al blueprint, asignándolo a los dispositivos de interés. En mi caso, serían todos los spines y leaf switches.

{% include image.html url="/assets/img/2023-12-27_import-configlet00.png" description="Imagen 5 - Llegar a la sección de importación" alt="Captura de pantalla de Apstra" width=1455 height=437 %}

{% include image.html url="/assets/img/2023-12-27_import-configlet01.png" description="Imagen 6 - Seleccionar el configlet y asignarlo a los dispositivos de interés" alt="Captura de pantalla de Apstra" width=1020 height=777 %}

{:start="2"}
2. Hacer commit de la configuración para que se envíe a los dispositivos.

{% include image.html url="/assets/img/2023-12-27_commit00.png" description="Imagen 7 - Solicitud de envío de los cambios a los NEs" alt="Captura de pantalla de Apstra" width=1337 height=491 %}

{% include image.html url="/assets/img/2023-12-27_commit01.png" description="Imagen 8 - Completar el changelog" alt="Captura de pantalla de Apstra" width=976 height=377 %}

## Switches independientes {#standalone-switches}

Estos switches no están administrados por Apstra ni por ningún otro gestor, y tampoco hay TACACS+ ni servicios similares de autenticación o RBAC (¿mencioné que me encantaría tener LDAP disponible para reutilizar los servicios de autenticación ya existentes?). Dado que son solo 2, la configuración manual y local no debería ser un problema.

Conéctate al switch con un usuario admin, en modo edit.

### NETCONF {#netconf-1}

Habilitamos el servicio. Los chicos cool de la automatización recomiendan los últimos 3 comandos por interoperabilidad, pero dado que vLWC es una herramienta cerrada de Juniper para JunOS, podría esperar la configuración por defecto, menos estándar y no compatible. Algo para monitorear y validar después de agregar switches a JSI.

```
set system services netconf ssh
set system services netconf rfc-compliant
set system services netconf yang-compliant 
set system services netconf hello-message yang-module-capabilities advertise-standard-yang-modules
```

### SFTP {#sftp-1}

El subsistema SFTP debe estar habilitado, parece estar deshabilitado por defecto.

```
set system services ssh sftp-server
```

### Usuario de proceso {#process-user-1}

1. Creamos la clase de usuario con el nivel de acceso requerido
```
set system login class jsi-class permissions view-configuration
set system login class jsi-class allow-commands "(file list detail)|(show bgp summary)|(show chassis alarms)|(show chassis fpc)|(show chassis hardware extensive)|(show chassis routing-engine)|(show interfaces descriptions)|(show interfaces terse)|(show isis adjacency)|(show ospf neighbor)|(show rsvp neighbor)|(show system buffers)|(show system commit)|(show system core-dumps)|(show system license)|(show system uptime)|(show version)|(show vrrp detail)|(request support information)|(sftp)"
set system login class jsi-class deny-commands "(clear)|(file)|(file show)|(help)|(load)|(monitor)|(op)|(request)|(save)|(set)|(start)|(test)"
set system login class jsi-class deny-configuration all
```

2. Creamos el usuario, usando la clase creada previamente. ¡Usa tu llave pública, no la mía!
```
set system login user svcjsi class jsi-class
set system login user svcjsi full-name "JSI process user"
set system login user svcjsi uid 2007
set system login user svcjsi authentication ssh-rsa "ssh-rsa your-key-super-long-string JSI process user"
```

### Commit final {#final-commit}

3. Hacer commit de la configuración (servicio y usuario)
```
commit
```

## Probando NETCONF a mano {#testing-netconf-by-hand}

Antes de pasar por todo el aparato de JSI, mi recomendación es hacer una prueba local básica con el usuario que hemos creado.

Entra a una máquina Linux con acceso a los switches y a la llave privada del usuario que hemos creado, e intenta conectarte al switch usando NETCONF

{% highlight shell %}
# We start the ssh key agent
eval $(ssh-agent)

# We add the key to the agent, the command will prompt for the key passphrase
ssh-add ~/.ssh/id_rsa-jsi

# We try a connection on default port
MYSWITCH=host.tld
ssh svcjsi@$MYSWITCH -p 830 -s netconf
{% endhighlight %}

La respuesta debería ser similar a

{% highlight xml %}
<!-- No zombies were killed during the creation of this user interface -->
<!-- user svcjsi, class j-jsi-class -->
<nc:hello xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">
   <nc:capabilities>
    <nc:capability>urn:ietf:params:netconf:base:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:candidate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:confirmed-commit:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:validate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:url:1.0?scheme=http,ftp,file</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:base:1.0?module=ietf-netconf&amp;revision=2011-06-01</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:candidate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:confirmed-commit:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:validate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:url:1.0?scheme=http,ftp,file</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:yang:ietf-inet-types?module=ietf-inet-types&amp;revision=2013-07-15</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring</nc:capability>
    <nc:capability>http://xml.juniper.net/netconf/junos/1.0</nc:capability>
    <nc:capability>http://xml.juniper.net/dmi/system/1.0</nc:capability>
  </nc:capabilities>
  <nc:session-id>65596</nc:session-id>
</nc:hello>
]]>]]>
{% endhighlight %}

## ¿Eso es todo? {#is-that-it}

Bueno, debería ser todo para la configuración de los NE. Ahora deberías poder entrar al portal de JSI y dar de alta los dispositivos (muchachos de Juniper, por favor agreguen soporte para FQDN en el formulario además de direcciones IP).

¡A divertirse!

## Más documentos de referencia {#more-reference-documents}

Por si sigues leyendo, estos son algunos documentos y notas que revisé en el proceso.

- [Establish an SSH Connection for a NETCONF Session](https://www.juniper.net/documentation/us/en/software/junos/netconf/topics/topic-map/netconf-ssh-connection.html)  
- [Managing Juniped devices with SSH and NETCONF](https://www.tinfoilcipher.co.uk/2021/07/29/ansible-and-juniper-junos-managing-devices-with-ssh-and-netconf/)
- [Example: Configuring User Permissions with Access Privileges for Operational Mode Commands](https://www.juniper.net/documentation/en_US/junos/topics/example/access-privileges-individual-operational-mode-commands-configuring.html)
- [Connect to the NETCONF Server Using SSH](https://www.juniper.net/documentation/us/en/software/junos/netconf/topics/task/netconf-session-connecting-to-server.html)
- [Technical note on using SSH keys with JunOS](https://supportportal.juniper.net/s/article/Junos-Generating-SSH-RSA-keys-locally-on-devices-running-Junos-OS)

## Errores conocidos {#known-errors}

### JSI reporta credenciales incorrectas {#jsi-reporting-wrong-credentials}

Durante mis pruebas, descubrí que el portal web de JSI no maneja bien las actualizaciones de credenciales. Puedes guardar los cambios, ves la nueva información en el portal web, pero parece que no llega a su backend. Tuve que eliminar y volver a crear las credenciales en el portal web para que funcionaran.

### NETCONF reportado como no configurado {#netconf-reported-as-not-configured}

Durante mis pruebas, pude confirmar manualmente que NETCONF estaba bien configurado, pero JSI seguía reportando:

```
The NETCONF subsystem is not enabled on the devices with the listed IP addresses. Please check and correct these entries
```

El equipo de JSI indicó que había un timer que no dejaba terminar correctamente el diálogo NETCONF. Lo arreglaron de su lado ampliando la configuración de timeout; no sé si es un parámetro global de la plataforma o si debes pedirlo para tus nodos/sitios/cuentas específicos.

Puedes referenciar el Juniper SR # 2023-1228-038580.
