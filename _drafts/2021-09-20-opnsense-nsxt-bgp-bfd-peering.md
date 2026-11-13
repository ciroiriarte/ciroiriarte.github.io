---
title: "BGP + BFD peering between OPNsense and NSX-T"
description: Peering an NSX-T Tier-0 gateway with OPNsense over a dedicated VLAN, using FRR (os-frr) for BGP and BFD.
date: 2021-09-20 10:00:00 -0300
layout: post
author: Ciro Iriarte
lang: en
categories:
  - networking
  - virtualization
tags:
  - opnsense
  - vmware
  - sdn
---

<!--
  Rebuilt on 2026-11-13 from nine screenshots left in the old WordPress
  uploads tree (2021/09 and 2021/10). The original text was never published: the
  Wayback Machine has no such post. The outline follows the screenshots'
  numbered steps; the prose still has to be written.
-->

Intro: why OPNsense as the upstream router for an NSX-T lab, and what BGP + BFD gives over static routes (dynamic advertisement of NSX segments, sub-second failure detection).

<!--more-->

## Lab layout

- OPNsense VM, uplink `vtnet0`, peering VLAN 4088 ("BGP Peering A"), `172.16.10.2/24`.
- NSX-T Tier-0 gateway with an uplink in the same VLAN.
- OPNsense AS `4200000002` (private 32-bit ASN). <!-- NSX-T side ASN and Tier-0 uplink IP: fill in. -->

<!-- Diagram of the peering would help here. -->

## OPNsense: peering interface

1. Create VLAN 4088 on `vtnet0` (Interfaces → Other Types → VLAN).

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-01-vlan.png" description="Create VLAN 4088 on vtnet0 for the BGP peering" alt="OPNsense Interface VLAN Edit: parent vtnet0, VLAN tag 4088, description BGP Peering A" width=958 height=476 %}

2. Assign it as a new interface, `NSXTPeeringA` (Interfaces → Assignments).

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-02-assign-interface.png" description="Assign the VLAN as interface NSXTPeeringA" alt="OPNsense interface assignments: new interface vlan 4088 on vtnet0 with description NSXTPeeringA, plus and Save buttons marked" width=946 height=240 %}

3. Enable it, static IPv4, SLAAC for IPv6.

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-03-interface-config.png" description="Enable the interface; IPv4 static, IPv6 SLAAC" alt="OPNsense NSXTPeeringA interface settings: Enable Interface checked, IPv4 Configuration Type Static IPv4, IPv6 Configuration Type SLAAC" width=1016 height=738 %}

4. Address `172.16.10.2/24`, no upstream gateway.

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-04-interface-ipv4.png" description="Static IPv4 address for the peering interface" alt="OPNsense static IPv4 configuration: 172.16.10.2 with prefix 24, upstream gateway auto-detect" width=1020 height=445 %}

5. Apply changes.

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-05-apply.png" description="Apply the interface changes" alt="OPNsense banner: NSXTPeeringA configuration has been changed, Apply changes button" width=1019 height=225 %}

<!-- Firewall rules on NSXTPeeringA for TCP 179 (BGP) and UDP 3784/3785 (BFD): add if needed. -->

## OPNsense: FRR routing

Install the `os-frr` plugin. <!-- Version used: fill in. -->

6. Routing → General: advanced mode, enable, **Datacenter** profile (more aggressive FRR timers), no CARP failover, SNMP AgentX on.

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-06-routing-general.png" description="FRR general settings with the datacenter profile" alt="OPNsense Routing General: advanced mode, Enable checked, Profile Datacenter, CARP failover unchecked, SNMP AgentX checked, logging enabled" width=1256 height=861 %}

7. Routing → BGP: enable, AS `4200000002`, graceful restart, redistribute connected, kernel and static routes.

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-07-bgp.png" description="BGP general settings" alt="OPNsense Routing BGP General: enable checked, BGP AS Number 4200000002, Graceful Restart checked, Route Redistribution with connected, kernel and static routes selected" width=1051 height=951 %}

<!-- Neighbors tab: the NSX-T Tier-0 uplink as neighbor, remote AS, BFD checkbox. No screenshot survived; write from memory or recreate. -->

8. Routing → BFD: enable.

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-08-bfd.png" description="Enable the BFD service" alt="OPNsense Routing BFD General tab: Enable checked, Save" width=776 height=408 %}

<!-- BFD Neighbors tab: add the Tier-0 uplink address. -->

## NSX-T: Tier-0 side

9. Networking → Global Networking Config: set L3 forwarding mode to IPv4 and IPv6.

{% include image.html url="/assets/img/2021-09-opnsense-nsxt-09-nsxt-l3-mode.png" description="NSX-T global L3 forwarding mode" alt="NSX-T Global Networking Config: Global Gateway Configuration in edit mode, L3 Forwarding Mode IPv4 and IPv6, Save" width=953 height=1098 %}

<!-- Tier-0: uplink segment on VLAN 4088, interface IP, BGP local AS, neighbor 172.16.10.2 remote AS 4200000002, BFD enabled, route redistribution (Tier-1 connected/NAT). Fill in. -->

## Verification

<!-- `vtysh -c "show bgp summary"`, `show bfd peers`, routes learned on both sides. Fill in. -->

## Conclusion
