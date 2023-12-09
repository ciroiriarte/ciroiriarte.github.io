---
title: Intermittent connection with Zerotier in Site-2-Site
description: Found an odd behaviour with Zerotier while using OPNSense as L3 peering nodes for site 2 site integration.
layout: post
author: ciroiriarte
categories:
- SDN
- Networking
tags:
- OPNsense
- Zerotier
---

# Starting point

I've been evaluating an idea to connect several sites using "just Internet", versus traditional MPLS services. Out of the several options I have in mind, one of them is having a OPNSense as peering point for each LAN. All of them should be connected using Zerotier SDN in L3 with "managed routes".

I've identified a 128 routes limit in the "managed routes" option, so probably will need to run a BGP route reflector in the final setup, but for the initial PoC managed routes would do.

## Basic layout of the PoC

This is a basic diagram of what was tested. Each OPNSense endpoint would run the zerotier client and provide forwarding. Route information would be pushed by the controller.

<figure>
  <a href="/assets/img/2023-12-09-zerotier-s2s-poc.png">
  <img src="/assets/img/2023-12-09-zerotier-s2s-poc.png" alt="network layout"/>
  </a>
  <figcaption><i>Image 1 - PoC network layout </i></figcaption>
</figure>


Routes as defined in the controller:

> 10.1.0.0/24 via 172.16.1.10
> 10.2.0.0/24 via 172.16.1.20

# The issue

During my tests, I've seen that the connection between sites (LAN on side A vs LAN on side B) is very intermittent, with 30-60% of packet lost.

# Analysis of the issue

I've created a small script for OPNsense to continuosly check peer status.

For your refence, file created as:

{% highlight shell %}
mkdir ~/bin
touch ~/bin/check-peer.csh
chmod +x ~/bin/check-peer.csh
vi ~/bin/check-peer.csh
{% endhighlight %}

Content to be inserted:

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

Execution example:

{% highlight shell %}
root@opnsense-A:~/bin # check-peer.sh 0f02bd4XXX
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   252      413      <public IP>/25545
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      <public IP>/25545
{% endhighlight %}

What I found was that when the client had no response for the ICMP echo request (ping command), the output shows a change in IP for the peer to the internal LAN IP.

{% highlight shell mark_lines="4 5 6 7" %}
root@opnsense-B:~/bin # check-peer.sh 0f02bd4XXX
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   252      413      <public IP>/25545
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      <public IP>/25545
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      10.2.0.1/25645 
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      10.2.0.1/25645
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      10.2.0.1/25645
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      10.2.0.1/25645
0f02bd4XXX 1.12.2 LEAF       0 DIRECT   347      265      <public IP>/25545
{% endhighlight %}

In the past, I've seen through firewall logs and tcpdump captures that Zerotier is very promiscuous/aggressive and tries to reach peers using ANY available interface. I understand this is part of the "just works" experience they envisioned but it's odd it's trying to reach an underlay peer through the overlay network (by means of L3 to a remote network in this case).

I would expect that Zerotier avoids using zt* interfaces by default.

# Similar reports

## Andy Liebman

Andy Liebman reported the same scenario in the [forum](https://discuss.zerotier.com/t/troubleshooting-intermittent-connection-with-site-to-site/15435), but unluckily nobody provided feedback and by the time I reached the post, it was closed and no further comments were possible.

## u/legacyproblems at Reddit

Not necesarrily the same scenario, but it's similar. This person blocked the unwanted flows through firewall rules:

> I ran into a similar issue a while back where I have some devices acting as gateways onto my ZeroTier LAN and > devices on the real LANs these gateways were connected to would tunnel through the same ZeroTier LAN via the > gateways...
> 
> Ended up adding a rule to block 9993 UDP on my ZeroTier LAN via the ZeroTier network rules engine.

[reference](https://www.reddit.com/r/zerotier/comments/15zw33a/how_to_make_zerotier_not_use_other_tunnels/)

## Blacklists

I recall seeing similar reports which got addressed through the use of [blacklists](https://docs.zerotier.com/config/#local-configuration-options), but can't seem to find those posts right now to add links.

I preffer not going that route because with firewalls, adding new interfaces is kind of frequent and I will most probably forget about blacklisting thew new interfaces that are not supposed to be used for underlay traffic. 

For my usecase whitelisting would make much more sense, telling Zerotier "use WAN1 & WAN2 interfaces and nothing more", but unluckily, that doesn't seem to be supported.

# The fix

I've found that using the new [multipath](https://docs.zerotier.com/multipath/) implementation seems to mimic the whitelist logic I'm after. I found this by accident, the private IP for the peer was only seen in the site that doesn't have multipath configured.

Site A has two WAN interfaces. In the past, I've seen really weird browsing behaviour in OPNSense when having an active/active gateway group, that let me to fallback to failover groups. In this case, I would think Zerotier could actually work wonders in active/active scenarios but for the sake of simplicity, I kept the setup active/standby for Zerotier too.

local.conf would look like this:

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


Site B has one WAN interface, multipath conceptually doesn't make sense in this scenario but still solves my "trying to reach the remote LAN through a peer in the remote LAN" issue. 

local.conf would look like this:

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


I still see an sporadic entry for the LAN IP of the peer during my tests, but clients are reporting 0% of lost packets for a site to site ICMP test (ping?/pong!).

Will update the post if anything changes.