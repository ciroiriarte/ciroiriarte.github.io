---
title: Connessione intermittente con Zerotier in Site-2-Site
description: Ho trovato uno strano comportamento di Zerotier usando OPNSense come nodi di peering L3 per l'integrazione site 2 site.
date: 2023-12-09 00:00:00 -0300
permalink: /it/sdn/networking/2023/12/09/intermittent-connection-with-zerotier-in-site-2-site.html
lang: it
categories:
  - networking
tags:
  - zerotier
  - opnsense
---

## Punto di partenza {#starting-point}

Sto valutando un'idea per collegare più sedi usando "solo Internet", al posto dei tradizionali servizi MPLS. Tra le varie opzioni che ho in mente, una prevede un OPNSense come punto di peering per ogni LAN. Tutti sarebbero collegati con Zerotier SDN in L3 con le "managed routes".

Ho individuato un limite di 128 route nell'opzione "managed routes", quindi probabilmente nel setup finale dovrò usare un route reflector BGP, ma per la PoC iniziale le managed routes vanno bene.

<!--more-->

### Schema base della PoC {#basic-layout-of-the-poc}

Questo è un diagramma di base di quanto è stato testato. Ogni endpoint OPNSense eseguirebbe il client zerotier e farebbe il forwarding. Le informazioni di routing verrebbero distribuite dal controller.

{% include image.html url="/assets/img/2023-12-09-zerotier-s2s-poc.png" description="Immagine 1 - Schema di rete della PoC" alt="schema di rete" width=1046 height=591 %}


Route come definite nel controller:

> 10.1.0.0/24 via 172.16.1.10
> 
> 10.2.0.0/24 via 172.16.1.20

## Il problema {#the-issue}

Durante i test ho visto che la connessione tra le sedi (LAN del lato A vs LAN del lato B) è molto intermittente, con una perdita di pacchetti tra il 30 e il 60%.

## Analisi del problema {#analysis-of-the-issue}

Ho creato un piccolo script per OPNsense che controlla continuamente lo stato del peer.

Per tua referenza, il file è creato così:

{% highlight shell %}
mkdir ~/bin
touch ~/bin/check-peer.csh
chmod +x ~/bin/check-peer.csh
vi ~/bin/check-peer.csh
{% endhighlight %}

Contenuto da inserire:

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

Esempio di esecuzione:

{% highlight shell %}
root@opnsense-A:~/bin # check-peer.sh 0f02bd4XXX
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   252      413      <public IP>/25545
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      <public IP>/25545
{% endhighlight %}

Ho scoperto che quando il client non riceveva risposta all'ICMP echo request (il comando ping), l'output mostrava un cambio dell'IP del peer verso l'IP interno della LAN.

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

In passato ho visto dai log del firewall e dalle catture tcpdump che Zerotier è molto promiscuo/aggressivo e cerca di raggiungere i peer usando QUALSIASI interfaccia disponibile. Capisco che faccia parte dell'esperienza "just works" che avevano in mente, ma è strano che provi a raggiungere un peer dell'underlay attraverso la rete overlay (tramite L3 verso una rete remota, in questo caso).

Mi aspetterei che Zerotier evitasse di usare le interfacce zt* di default.

## Segnalazioni simili {#similar-reports}

### Andy Liebman {#andy-liebman}

Andy Liebman ha segnalato lo stesso scenario nel [forum](https://discuss.zerotier.com/t/troubleshooting-intermittent-connection-with-site-to-site/15435), ma purtroppo nessuno ha risposto e quando sono arrivato al post era già chiuso e non era possibile aggiungere altri commenti.

### u/legacyproblems su Reddit {#ulegacyproblems-at-reddit}

Non necessariamente lo stesso scenario, ma simile. Questa persona ha bloccato i flussi indesiderati con regole firewall:

> I ran into a similar issue a while back where I have some devices acting as gateways onto my ZeroTier LAN and > devices on the real LANs these gateways were connected to would tunnel through the same ZeroTier LAN via the > gateways...
> 
> Ended up adding a rule to block 9993 UDP on my ZeroTier LAN via the ZeroTier network rules engine.

[riferimento](https://www.reddit.com/r/zerotier/comments/15zw33a/how_to_make_zerotier_not_use_other_tunnels/)

### Blacklist {#blacklists}

Ricordo di aver visto segnalazioni simili risolte con l'uso di [blacklist](https://docs.zerotier.com/config/#local-configuration-options), ma al momento non riesco a ritrovare quei post per aggiungere i link.

Preferisco non seguire quella strada perché sui firewall aggiungere nuove interfacce è abbastanza frequente e con ogni probabilità mi dimenticherei di mettere in blacklist le nuove interfacce che non dovrebbero essere usate per il traffico di underlay. 

Per il mio caso d'uso una whitelist avrebbe molto più senso, dicendo a Zerotier "usa le interfacce WAN1 e WAN2 e nient'altro", ma purtroppo non sembra essere supportato.

## La soluzione {#the-fix}

Ho scoperto che usare la nuova implementazione [multipath](https://docs.zerotier.com/multipath/) sembra imitare la logica di whitelist che cerco. L'ho scoperto per caso: l'IP privato del peer si vedeva solo nella sede che non ha multipath configurato.

La sede A ha due interfacce WAN. In passato ho visto un comportamento di navigazione davvero strano in OPNSense con un gateway group active/active, che mi ha portato a tornare ai failover group. In questo caso penserei che Zerotier potrebbe fare miracoli negli scenari active/active, ma per semplicità ho tenuto il setup active/standby anche per Zerotier.

local.conf sarebbe così:

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


La sede B ha una sola interfaccia WAN; concettualmente multipath non ha senso in questo scenario, ma risolve comunque il mio problema del "provare a raggiungere la LAN remota attraverso un peer nella LAN remota". 

local.conf sarebbe così:

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


Durante i test vedo ancora una voce sporadica con l'IP LAN del peer, ma i client riportano 0% di pacchetti persi in un test ICMP site to site (ping?/pong!).

Aggiornerò il post se cambia qualcosa.
