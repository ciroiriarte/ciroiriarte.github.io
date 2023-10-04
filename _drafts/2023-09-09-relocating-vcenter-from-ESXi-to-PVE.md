---
title: Relocating vCenter from ESXi to PVE
description: Export/Import vcsa virtual appliance to improve performance
layout: post
author: ciroiriarte
categories:
- HomeLab
tags:
- ESXi
- Proxmox
- Nested
- Virtualization
- vSAN
---

# Starting point & the need
# Target
# Export

## Tooling
We'll be using GoVC to export the vCenter in OVF+VMDK formats (definition & data). For your reference, the description of the project states:

govc is a vSphere CLI built on top of govmomi.

The CLI is designed to be a user friendly CLI alternative to the GUI and well suited for automation tasks. It also acts as a test harness for the govmomi APIs and provides working examples of how to use the APIs.

## Installation

Installation is as easy as downloading a self contained executable binary to our PVE node:

{% highlight shell %}
curl -L -o - "https://github.com/vmware/govmomi/releases/latest/download/govc_$(uname -s)_$(uname -m).tar.gz" | tar -C /usr/local/bin -xvzf - govc
{% endhighlight %}

## Usage

We need to define some environment variables for GoVC to be able to communicate to vCenter APIs. Connection can be validated with the "about" command:

{% highlight shell %}
root@bigiron:~# 
export GOVC_URL=https://vcsa01.lab
root@bigiron:~# export GOVC_USERNAME=Administrator@vsphere.local
root@bigiron:~# export GOVC_PASSWORD="VMware1!"
root@bigiron:~# export GOVC_INSECURE=1


root@bigiron:~# govc about
FullName:     VMware vCenter Server 8.0.1 build-22088981
Name:         VMware vCenter Server
Vendor:       VMware, Inc.
Version:      8.0.1
Build:        22088981
OS type:      linux-x64
API type:     VirtualCenter
API version:  8.0.1.0
Product ID:   vpx
UUID:         9aa6dc36-e6cd-42b3-a6cd-e8ef5d67bfe2
{% endhighlight %}

mkdir vcsa-export 
govc export.ovf -vm vcsa01 -sha=0 vcsa-export


# Import