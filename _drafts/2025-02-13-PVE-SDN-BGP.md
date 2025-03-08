---
title: North/South BGP Peering for Proxmox SDN
description: How to integrate PVE SDN with other network elements
layout: post
author: ciroiriarte
categories:
- HomeLab
tags:
- Proxmox
- SDN
---

# Reference documentation
https://pve.proxmox.com/pve-docs/chapter-pvesdn.html#_multiple_evpn_exit_nodes

# VRF to IF

Get VRF list from "ip vrf", take note of the VRF of interest. As of today, it's vrf_${ZONENAME}.

{% highlight shell %}
cat <<EOF >> /etc/network/interfaces
auto vlan2028
iface vlan2028 inet static
        address 192.168.203.196/28
        mtu 1500
        vlan-raw-device vmbr1
        vrf vrf_SDCVPN01
#BGP Peering SDC overlay

auto vlan2029
iface vlan2029 inet static
        address 192.168.203.212/28
        mtu 1500
        vlan-raw-device vmbr1
        vrf vrf_L01VPN01
#BGP Peering LAB01 overlay
EOF
{% endhighlight %}


# File creation

{% highlight shell %}
cat <<EOF >> /etc/pve/sdn/frr.conf.local
# Override of the bgp controller to add North/South communication towards the firewall
# v0.1 - 20250211 - ciro.iriarte@millicom.com
# * First release
# v0.2 - 20250212 - ciro.iriarte@millicom.com
# * added support 

ip prefix-list PFL_SDC_OUT seq 10 deny 192.168.203.192/28
# https://github.com/FRRouting/frr/issues/16161
ip prefix-list PFL_SDC_OUT seq 20 permit 0.0.0.0/0 le 31
!

ip prefix-list PFL_L01_OUT seq 10 deny 192.168.203.208/28
ip prefix-list PFL_L01_OUT seq 20 permit 0.0.0.0/0 le 31
!


router bgp 4000000002 vrf vrf_SDCVPN01
 neighbor LABFWSDC peer-group
 neighbor LABFWSDC remote-as external
 neighbor LABFWSDC remote-as 4000000001
 neighbor LABFWSDC bfd
 neighbor 192.168.203.194 peer-group LABFWSDC
 neighbor 192.168.203.195 peer-group LABFWSDC
!
 address-family ipv4 unicast
  neighbor LABFWSDC activate
  neighbor LABFWSDC soft-reconfiguration inbound
  neighbor LABFWSDC prefix-list PFL_SDC_OUT out
#  import vrf vrf_SDCVPN01
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor LABFWSDC activate
  neighbor LABFWSDC soft-reconfiguration inbound
#  import vrf vrf_SDCVPN01
 exit-address-family
 !
exit
!

router bgp 4000000002 vrf vrf_L01VPN01
 neighbor LABFWL01 peer-group
 neighbor LABFWL01 remote-as external
 neighbor LABFWL01 remote-as 4000000001
 neighbor LABFWL01 bfd
 neighbor 192.168.203.210 peer-group LABFWL01
 neighbor 192.168.203.211 peer-group LABFWL01
!
 address-family ipv4 unicast
  neighbor LABFWL01 activate
  neighbor LABFWL01 soft-reconfiguration inbound
  neighbor LABFWL01 prefix-list PFL_L01_OUT out
#  import vrf vrf_L01VPN01
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor LABFWL01 activate
  neighbor LABFWL01 soft-reconfiguration inbound
#  import vrf vrf_L01VPN01
 exit-address-family
 !
exit
!

EOF
{% endhighlight %}

# Link
ln -s /etc/pve/sdn/frr.conf.local /etc/frr/

# For multiple exit nodes, reverse path filtering needs to be disabled
cat<<EOF >> /etc/sysctl.d/z-ecmp.conf
##
# Disable RP filtering for ECMP to work
# https://pve.proxmox.com/pve-docs/chapter-pvesdn.html#_multiple_evpn_exit_nodes
##
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.all.rp_filter=0
EOF

sysctl -p
