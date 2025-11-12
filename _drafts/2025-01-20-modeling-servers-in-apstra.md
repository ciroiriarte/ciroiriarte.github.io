---
title: Modeling Servers in Apstra
description: Walkthrough to properly create servers connected to your IP Fabric.
layout: post
author_profile: true
author: Ciro Iriarte
categories:
- Datacenter
- Networking
tags:
- Juniper
- QFX
- Apstra
- JunOS
---



# Rationale

I found Apstra quite intersting for a Datacenter environment where you would like to have an overall view of the environment you're working on. 

Sadly, more often than not I see network engineers focusing on the switch side and wanting to know next to nothing about what's connected on the other side of the cable.

Trying to troubleshoot cabled connections last week for a project I'm working on, was presented with something like this:

<figure>
  <a href="/assets/img/2025-01-20-apstra-server-without-interface-label.png">
  <img src="/assets/img/2025-01-20-apstra-server-without-interface-label.png" alt="Server representation"/>
  </a>
  <figcaption><i>Image 1 - Server representation without port labels</i></figcaption>
</figure>

Can you tell what are the server ports involved?. The lack of port names (labels) forces me to crosscheck 3 spreadsheets, LLDP data or MAC addresses tables in at least 3 nodes when simple documentation could be more than enough.

I'll show you how a server can be properly modeled to show a label for each port.

<!--more-->

# Process summary

The process could be a little convoluted for newcomers, but with some patience you can get it right. This was tested on Apstra 5.0 which supports modeling modular systems.

Basically you need to define:

- Chassis profile
- Linecard profile  
- Device profile
- Logical profile
- Interface map

# Next steps

For me, next step would be to figure out how to achieve the same thing with Apstra's [Terraform Provider](https://github.com/Juniper/terraform-provider-apstra) and OpenTofu.

Wish me luck!.