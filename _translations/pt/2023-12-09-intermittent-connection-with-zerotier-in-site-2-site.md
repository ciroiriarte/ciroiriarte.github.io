---
title: Conexão intermitente com Zerotier em Site-2-Site
description: Encontrei um comportamento estranho com o Zerotier ao usar OPNSense como nós de peering L3 para integração site 2 site.
date: 2023-12-09 00:00:00 -0300
permalink: /pt/sdn/networking/2023/12/09/intermittent-connection-with-zerotier-in-site-2-site.html
lang: pt
categories:
  - networking
tags:
  - zerotier
  - opnsense
---

## Ponto de partida {#starting-point}

Venho avaliando uma ideia para conectar vários sites usando "só Internet", em vez dos serviços MPLS tradicionais. Das várias opções que tenho em mente, uma é ter um OPNSense como ponto de peering para cada LAN. Todos seriam conectados usando Zerotier SDN em L3 com "managed routes".

Identifiquei um limite de 128 rotas na opção "managed routes", então provavelmente vou precisar rodar um route reflector BGP na configuração final, mas para a PoC inicial as managed routes servem.

<!--more-->

### Esquema básico da PoC {#basic-layout-of-the-poc}

Este é um diagrama básico do que foi testado. Cada endpoint OPNSense rodaria o cliente zerotier e faria o forwarding. A informação de rotas seria enviada pelo controller.

{% include image.html url="/assets/img/2023-12-09-zerotier-s2s-poc.png" description="Imagem 1 - Esquema de rede da PoC" alt="esquema de rede" width=1046 height=591 %}


Rotas conforme definidas no controller:

{% highlight text %}
10.1.0.0/24 via 172.16.1.10

10.2.0.0/24 via 172.16.1.20
{% endhighlight %}

## O problema {#the-issue}

Durante meus testes, vi que a conexão entre os sites (LAN do lado A vs LAN do lado B) é muito intermitente, com 30-60% de perda de pacotes.

## Análise do problema {#analysis-of-the-issue}

Criei um pequeno script para o OPNsense que verifica continuamente o estado do peer.

Para sua referência, o arquivo é criado assim:

{% highlight shell %}
mkdir ~/bin
touch ~/bin/check-peer.csh
chmod +x ~/bin/check-peer.csh
vi ~/bin/check-peer.csh
{% endhighlight %}

Conteúdo a inserir:

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

Exemplo de execução:

{% highlight shell %}
root@opnsense-A:~/bin # check-peer.sh 0f02bd4XXX
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   252      413      <public IP>/25545
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      <public IP>/25545
{% endhighlight %}

O que descobri foi que, quando o cliente ficava sem resposta ao ICMP echo request (o comando ping), a saída mostrava uma mudança no IP do peer para o IP interno da LAN.

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

No passado, vi pelos logs do firewall e capturas de tcpdump que o Zerotier é muito promíscuo/agressivo e tenta alcançar os peers usando QUALQUER interface disponível. Entendo que isso faz parte da experiência "just works" que eles idealizaram, mas é estranho ele tentar alcançar um peer do underlay através da rede overlay (por meio de L3 para uma rede remota, neste caso).

Eu esperaria que o Zerotier evitasse usar as interfaces zt* por padrão.

## Relatos semelhantes {#similar-reports}

### Andy Liebman {#andy-liebman}

Andy Liebman relatou o mesmo cenário no [fórum](https://discuss.zerotier.com/t/troubleshooting-intermittent-connection-with-site-to-site/15435), mas infelizmente ninguém respondeu e, quando cheguei ao post, ele já estava fechado e não era possível adicionar mais comentários.

### u/legacyproblems no Reddit {#ulegacyproblems-at-reddit}

Não necessariamente o mesmo cenário, mas é parecido. Essa pessoa bloqueou os fluxos indesejados com regras de firewall:

> I ran into a similar issue a while back where I have some devices acting as gateways onto my ZeroTier LAN and > devices on the real LANs these gateways were connected to would tunnel through the same ZeroTier LAN via the > gateways...
> 
> Ended up adding a rule to block 9993 UDP on my ZeroTier LAN via the ZeroTier network rules engine.

[referência](https://www.reddit.com/r/zerotier/comments/15zw33a/how_to_make_zerotier_not_use_other_tunnels/)

### Blacklists {#blacklists}

Lembro de ter visto relatos parecidos que foram resolvidos com o uso de [blacklists](https://docs.zerotier.com/config/#local-configuration-options), mas não consigo achar esses posts agora para adicionar os links.

Prefiro não seguir por esse caminho porque em firewalls adicionar novas interfaces é bem frequente e muito provavelmente vou esquecer de colocar na blacklist as novas interfaces que não deveriam ser usadas para tráfego de underlay. 

Para o meu caso de uso, uma whitelist faria muito mais sentido, dizendo ao Zerotier "use as interfaces WAN1 e WAN2 e mais nada", mas infelizmente isso não parece ser suportado.

## A solução {#the-fix}

Descobri que usar a nova implementação de [multipath](https://docs.zerotier.com/multipath/) parece imitar a lógica de whitelist que eu procuro. Descobri isso por acidente: o IP privado do peer só era visto no site que não tem multipath configurado.

O site A tem duas interfaces WAN. No passado, vi um comportamento de navegação realmente estranho no OPNSense com um grupo de gateways ativo/ativo, o que me fez voltar para grupos de failover. Neste caso, eu acharia que o Zerotier poderia fazer maravilhas em cenários ativo/ativo, mas, por simplicidade, mantive a configuração ativo/standby também para o Zerotier.

O local.conf ficaria assim:

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


O site B tem uma interface WAN; conceitualmente multipath não faz sentido neste cenário, mas ainda assim resolve o meu problema de "tentar alcançar a LAN remota através de um peer na LAN remota". 

O local.conf ficaria assim:

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


Ainda vejo uma entrada esporádica com o IP de LAN do peer durante meus testes, mas os clientes reportam 0% de pacotes perdidos em um teste ICMP de site a site (ping?/pong!).

Vou atualizar o post se algo mudar.
