---
title: Conexión intermitente con Zerotier en Site-2-Site
description: Encontré un comportamiento extraño con Zerotier al usar OPNSense como nodos de peering L3 para integración site 2 site.
date: 2023-12-09 00:00:00 -0300
permalink: /es/sdn/networking/2023/12/09/intermittent-connection-with-zerotier-in-site-2-site.html
lang: es
categories:
  - networking
tags:
  - zerotier
  - opnsense
---

## Punto de partida {#starting-point}

He estado evaluando una idea para conectar varios sitios usando "solo Internet", en lugar de los servicios MPLS tradicionales. De las varias opciones que tengo en mente, una es tener un OPNSense como punto de peering para cada LAN. Todos estarían conectados usando Zerotier SDN en L3 con "managed routes".

Identifiqué un límite de 128 rutas en la opción "managed routes", así que probablemente necesitaré correr un route reflector BGP en la configuración final, pero para la PoC inicial las managed routes sirven.

<!--more-->

### Esquema básico de la PoC {#basic-layout-of-the-poc}

Este es un diagrama básico de lo que se probó. Cada endpoint OPNSense correría el cliente zerotier y haría el forwarding. La información de rutas la enviaría el controller.

{% include image.html url="/assets/img/2023-12-09-zerotier-s2s-poc.png" description="Imagen 1 - Esquema de red de la PoC" alt="esquema de red" width=1046 height=591 %}


Rutas tal como se definieron en el controller:

{% highlight text %}
10.1.0.0/24 via 172.16.1.10

10.2.0.0/24 via 172.16.1.20
{% endhighlight %}

## El problema {#the-issue}

Durante mis pruebas vi que la conexión entre sitios (LAN del lado A vs LAN del lado B) es muy intermitente, con 30-60% de pérdida de paquetes.

## Análisis del problema {#analysis-of-the-issue}

Creé un pequeño script para OPNsense que revisa continuamente el estado del peer.

Para tu referencia, el archivo se crea así:

{% highlight shell %}
mkdir ~/bin
touch ~/bin/check-peer.csh
chmod +x ~/bin/check-peer.csh
vi ~/bin/check-peer.csh
{% endhighlight %}

Contenido a insertar:

{% highlight shell %}
#!/bin/csh

# * Sat Dec  9 16:02:33 -03 2023 - ciro.iriarte (at) gmail.com
# - Basic script to review peer underlay IP

if  ($# != "1") then
        echo "usage:"
        echo "  $0 <peer id>"
        exit
endif

while ( 1 )
  zerotier-cli peers | grep $1
  sleep 3
end
{% endhighlight %}

Ejemplo de ejecución:

{% highlight shell %}
root@opnsense-A:~/bin # check-peer.sh 0f02bd4XXX
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   252      413      <public IP>/25545
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      <public IP>/25545
{% endhighlight %}

Lo que encontré fue que cuando el cliente no tenía respuesta al ICMP echo request (el comando ping), la salida mostraba un cambio en la IP del peer a la IP interna de la LAN.

{% highlight shell mark_lines="4 5 6 7" %}
root@opnsense-B:~/bin # check-peer.sh 0f02bd4XXX
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   252      413      <public IP>/25545
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      <public IP>/25545
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      10.1.0.1/25645 
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      10.1.0.1/25645
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      10.1.0.1/25645
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      10.1.0.1/25645
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      <public IP>/25545
{% endhighlight %}

En el pasado vi, a través de logs del firewall y capturas de tcpdump, que Zerotier es muy promiscuo/agresivo e intenta llegar a los peers usando CUALQUIER interfaz disponible. Entiendo que esto es parte de la experiencia "just works" que idearon, pero es raro que intente llegar a un peer del underlay a través de la red overlay (por medio de L3 hacia una red remota en este caso).

Esperaría que Zerotier evite usar las interfaces zt* por defecto.

## Reportes similares {#similar-reports}

### Andy Liebman {#andy-liebman}

Andy Liebman reportó el mismo escenario en el [foro](https://discuss.zerotier.com/t/troubleshooting-intermittent-connection-with-site-to-site/15435), pero lamentablemente nadie respondió y para cuando llegué al post ya estaba cerrado y no se podían agregar más comentarios.

### u/legacyproblems en Reddit {#ulegacyproblems-at-reddit}

No necesariamente el mismo escenario, pero es similar. Esta persona bloqueó los flujos no deseados con reglas de firewall:

> I ran into a similar issue a while back where I have some devices acting as gateways onto my ZeroTier LAN and > devices on the real LANs these gateways were connected to would tunnel through the same ZeroTier LAN via the > gateways...
> 
> Ended up adding a rule to block 9993 UDP on my ZeroTier LAN via the ZeroTier network rules engine.

[referencia](https://www.reddit.com/r/zerotier/comments/15zw33a/how_to_make_zerotier_not_use_other_tunnels/)

### Blacklists {#blacklists}

Recuerdo haber visto reportes similares que se resolvieron usando [blacklists](https://docs.zerotier.com/config/#local-configuration-options), pero ahora no logro encontrar esos posts para agregar los enlaces.

Prefiero no ir por ese camino porque en los firewalls agregar interfaces nuevas es bastante frecuente y lo más probable es que me olvide de poner en la blacklist las interfaces nuevas que no deberían usarse para tráfico del underlay. 

Para mi caso de uso un whitelist tendría mucho más sentido, decirle a Zerotier "usa las interfaces WAN1 y WAN2 y nada más", pero lamentablemente eso no parece estar soportado.

## La solución {#the-fix}

Descubrí que usar la nueva implementación de [multipath](https://docs.zerotier.com/multipath/) parece imitar la lógica de whitelist que busco. Lo encontré por accidente: la IP privada del peer solo se veía en el sitio que no tiene multipath configurado.

El sitio A tiene dos interfaces WAN. En el pasado vi un comportamiento de navegación realmente raro en OPNSense con un grupo de gateways activo/activo, lo que me llevó a volver a grupos de failover. En este caso, pensaría que Zerotier podría hacer maravillas en escenarios activo/activo, pero por simplicidad mantuve la configuración activo/standby también para Zerotier.

local.conf se vería así:

{% highlight json %}
{
  "settings": {
    "defaultBondingPolicy": "rapid-active-backup",
    "policies": {
      "rapid-active-backup": {
        "basePolicy": "active-backup",
        "failoverInterval": 1000,
        "links":
        {
          "ix0":
          {
            "ipvPref": 46,
            "failoverTo": "ix1"
          },
          "ix1":
          {
            "ipvPref": 46,
            "failoverTo": "ix0"
          }
        }
      }
    }
  }
}
{% endhighlight %}


El sitio B tiene una sola interfaz WAN; conceptualmente multipath no tiene sentido en este escenario, pero igual resuelve mi problema de "intentar llegar a la LAN remota a través de un peer en la LAN remota". 

local.conf se vería así:

{% highlight json %}
{
  "settings": {
    "defaultBondingPolicy": "rapid-active-backup",
    "policies": {
      "rapid-active-backup": {
        "basePolicy": "active-backup",
        "failoverInterval": 1000,
        "links":
        {
          "igb1":
          {
            "ipvPref": 46
          }
        }
      }
    }
  }
}
{% endhighlight %}


Todavía veo una entrada esporádica con la IP de LAN del peer durante mis pruebas, pero los clientes reportan 0% de paquetes perdidos en una prueba ICMP de site a site (¿ping?/¡pong!).

Actualizaré el post si algo cambia.
