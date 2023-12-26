---
title: Deploying Juniper vLWC on PVE
description: Walkthrough of analysis and deployment of a Juniper Virtual Lightweight Collector for "call home" functionality 
layout: post
author: ciroiriarte
categories:
- Datacenter
- Networking
tags:
- Juniper
- QFX
- EX
- JunOS
---

# Intro

As with any critical infrastructure, technology vendors provide a "call-home" feature for their products. For more than a decade (at least to my knowledge), storage vendors like Hitachi or EMC would provide a solution that would allow the vendor to connect to systems you own for support/assistance departments to directly work on them instead of telling you on the phone what to do. Other expected functionality includes opening a proactive ticket on hardware failure, extract/upload logs or inventory installed base.

This call-home functionality is usually delivered as a piece of software running on a dedicated/physical appliance, as a software to be installed on a general purpose Operating System instance (Windows Server, SLES/RHEL/OEL/Debian) or, these days, a pre-packaged virtual appliance.

Implementing such functionality, is always a good thing to do as it allows the vendor support team to provide quicker response when there are failures.

# The need

We were approached by the Juniper Support team, pitching for a WLC appliance which would provide call-home capabilities, and oversee our installed base. This appliance is part of their Juniper Support Insights (JSI) initiative.

One of such physical appliances is en route to one of our sites. Meanwhile, I'm overseeing a lab deployment that could benefit from the quick support and inventory capabilities. Further reviewing this topic, the Juniper team mentioned there's a virtual version of the appliance that was resently released.

The formal [documentation](https://www.juniper.net/documentation/us/en/software/jsi/vlwc-deploy/topics/topic-map/install-verify-vlwc.html) for vSphere environments is pretty straightforward and you can just follow that if you're working on a supported environment. In my case, the support sidecart environment for the lab doesn't sport VMware vSphere, but Proxmox VE.

I'll deploy vLWC on Proxmox VE to oversee QFX switches managed by Apstra & EX switches which comprise the OOBM network for the QFX switches too.

# Here be dragons.

<figure>
  <a href="https://education.nationalgeographic.org/resource/here-be-dragons/">
  <img src="/assets/img/2023-12-25_1570-theatrum-orbis-terrarum-map-monsters.jpg" alt="1570 Theatrum Orbis Terrarum Map Monsters"/>
  </a>
  <figcaption><i>Image 1 - 1570 Theatrum Orbis Terrarum Map Monsters</i></figcaption>
</figure>

As a word of warning, I should highlight the setup I'm about to execute and share with you is not supported by Juniper and your Service Manager will either frown on you, yell at you or just plainly ignore you (depending on the kind of relationship you have) if you ever request help deploying vLWC on KVM. I sincerilly expect this to change at some point in time.

Also remember, "not supported" doesn't mean it's not technically possible. It just means you're on your own.

Yes, I'll get support via a "not supported" appliance. Does it qualify as oximoron?

# Network architecture
## Lab sidecart environment
In the lab, we have an environment with the usual set of vendors & technology we work with. That setup includes a EVPN/VXLAN IP Fabric network with several clients being served. That network and the client platforms are expected to be reinstalled or rearranged at any point in time.

To provide some stable essential services, we've built a small parallel environment with some switches and PVE servers to run elements that must be available at all times:

- Remote access platform
- Authentication Services
- Security related tools
- Monitoring tools
- Firmware & Hardware related solutions

With this "sidecart" environment, no matter what is needed to adjust in the main environment, we'll never lose administration capabilities.

For the scope of our discussion, the logical environment looks something like this:

<figure>
  <a href="/assets/img/2023-12-25_lab-environment.svg">
  <img src="/assets/img/2023-12-25_lab-environment.svg" alt="Lab networks overview"/>
  </a>
  <figcaption><i>Image 2 - Related management network environment</i></figcaption>
</figure>

Physically, the sidecart is just a pair of Cisco Nexus switches in stack to provide redudant L2 1GbE/10GbE services, and the OOBM network is a pair of Juniper EX switches providing 1GbE connectivity to switches and IPMI server boards.

Logically, the setup is quite involved and provides things like access control and network segmentation via OPNSense providing L3 & Filtering capabilities. We need users to authenticate via username/password + OTP, then we hit the Jump hosts using Guacamole:

<figure>
  <a href="/assets/img/2023-12-25_lab-environment-flows.svg">
  <img src="/assets/img/2023-12-25_lab-environment-flows.svg" alt="Remote access"/>
  </a>
  <figcaption><i>Image 3 - Remote access flow</i></figcaption>
</figure>

My natural expectation was to deploy the call-home appliance next to other supporting appliances like Apstra or LibreNMS.

<figure>
  <a href="/assets/img/2023-12-25_lab-environment-plus-vlwc.svg">
  <img src="/assets/img/2023-12-25_lab-environment-plus-vlwc.svg" alt="vLWC in the picture"/>
  </a>
  <figcaption><i>Image 4 - Adding vLWC to the picture</i></figcaption>
</figure>

This is relevant for the next section.

## Required network topology

Reviewing the [deployment guide](https://www.juniper.net/documentation/us/en/software/jsi/vlwc-deploy/topics/concept/system-requirements.html), it mandates 3 networks interfaces:

Interface|Supported IP Address|Role
---|---|---
Internal|IPv4 or IPv6 address|Used for connection to the switches to be monitored. Default route is also here.
External|IPv4 address only|Used to connect to Death Star (actual call-home)
Management|IPv4 address only|Used for captive portal access (web portal presented by appliance showing status)

We could try to comply, and shoe-horn the appliance requirements to our environment.

It doesn't make me confortable, VMs connected to different segments that should only interact through the firewall was not an option in our case.

## Trial & error

I did several runs of the deployment on KVM in a vacuum to validate what's going on with the network setup and analyze what's required to deploy it with a single interface.

I'll spare you on the details, but the summary of the findings is:

- **First run:** 3 networks with DHCP (internal + external + management):  
*"int"* keeps the default route  
*"ext"* has static routes to reach Death Star (JNI)  
*"cap"* is used for captive portal (appliance status page)

The mentioned static routes (in case you're curious, those segments are owned by AWS & DigitalOcean):

```
35.71.174.221 via <ext segment gateway> dev ext 
35.83.44.146 via <ext segment gateway> dev ext 
52.223.32.79 via <ext segment gateway> dev ext 
54.149.98.110 via <ext segment gateway> dev ext 
54.149.222.60 via <ext segment gateway> dev ext 
68.183.248.21 via <ext segment gateway> dev ext 
138.197.235.241 via <ext segment gateway> dev ext 
```
**First takeaway:** We might need to massage the appliance to avoid installing the static routes, unless the static routes installation silently fails due to missing EXT interface.

The SSHD & Captive Portal services binding is not limited to listen to any interface in particular. 

{% highlight shell %}
root@ggc-lnx:~# lsof -n -sTCP:LISTEN -i :443
COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
docker-pr 20982 root    4u  IPv4 106963      0t0  TCP *:https (LISTEN)
docker-pr 20994 root    4u  IPv6 107636      0t0  TCP *:https (LISTEN)
root@ggc-lnx:~# lsof -n -sTCP:LISTEN -i :22 
COMMAND PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
sshd    543 root    3u  IPv4  17619      0t0  TCP *:ssh (LISTEN)
sshd    543 root    4u  IPv6  17621      0t0  TCP *:ssh (LISTEN)
{% endhighlight %}

**Second Takeaway:** we don't need to fiddle with service binding configuration, all services listen on all interfaces.

{% include note.html content="This is my sample note." %}

So the "don't answer on EXT" behaviour should most probably come from firewall rules, except it doesn't (no firewall rule exists to limit ingress SSH requests to a given inteface), the behaviour was a construction of my imagination and there's not mention of it in the docs. 

My ssh test was conducted from a client in the same subnet hosting the EXT interface. My wild guess is that any other remote client connection attempts coming from Internet should fail due to default gateway being installed on INT. 

Anyhow kids, don't place the appliance directly connected to Internet without incoming filters if you can avoid it.

**Third Takeaway:** we don't need to mess with firewall configuration.

- **Second run:** 2 networks setup with DHCP (internal + external)  
*"int"* keeps the default route, provides access to captive portal (appliance status page).  
*"ext"* has static routes to reach Death Star (JNI), same as above.

- **Third run:** 1 network setup with DHCP (internal)
*"int"* keeps the default route, provides access to captive portal (appliance status page)  
*"ext"* status is reported as failed  



# The appliance
## First administrative steps.

You have to request two things to your Juniper support team:
- Access to Juniper Support Insights to request the appliance
- Proper permissions to be setup to manage/use the appliance. We have a myriad of support accounts and something was not setup properly for my account in JSI.

## How to request it
## Supported deployment & automated setup process

# Deployment
# Create the VM
# Adjust generic appliance image
# Import disk to created VM

# Wishlist for the PLM

In case a Juniper vLWC appliance Product Owner passes by :), I would recommend the following to be included in the backlog:

## 1- Support for a single interface setup

I totally get the 3 interfaces setup for a physical appliance that's colocated with a lone MX960 on a remote site forgotten by God. You get:
- A "trusted" port that is either connected to a OOBM network serving several NEs or directly connected to the OOBM port on a lone router.
- An "outside" port that gives you access to Internet, probably comming from a NE in the ISP side of the house and shouln't be trusted (no services like SSH listening).
- A "management" port that whould give access to an on-site engineer to the appliance, probably directly connected to his/her laptop.

My uneducated guess is the virtual appliance basically followed a "shoehorn-in-a-vm whatever we had in the [physical appliance](https://www.juniper.net/documentation/us/en/hardware/lwc-hardware-guide/lwc/topics/concept/lwc-description.html) version" approach.

A virtual machine most probably will be deployed at a cozy TIER-something datacenter in a proper virtualization cluster with a very elaborated logical setup for management & monitoring, with L3 integrations to whatever destinations are required and services like filtering/segmentation outside of the appliance.

The ask would be: please support/allow a "single interface" setup as an alternative to the 3-port setup.

## 2- Newer Linux distribution

As of vLWC-2.3.26, the appliance is based in Ubuntu 18.04.6 LTS which is already [out of Standard Support after June 2023](https://wiki.ubuntu.com/Releases). Only Ubuntu Pro support subscribers will get minimal patch releases, and after quick verification I can tell that's not available on the deployed appliance (maybe even sporting a buggy openssl version?):

{% highlight shell %}
root@ggc-lnx:~# pro status
Failed to access URL: https://contracts.canonical.com/v1/resources?architecture=amd64&kernel=4.15.0-212-generic&series=bionic&virt=kvm
Cannot verify certificate of server
Please check your openssl configuration.
{% endhighlight %}

Old Linux distributions instances and the security implications for a given environment is a threshed topic. I would just summarize the ask as: an OS refresh is due and Ubuntu 22.04.3 LTS is at your disposal. No, "we'll eventually deploy a new version and you should re-deploy" is not acceptable

## 3- Support for PVE/KVM

Not all the Juniper shops run VMware vSphere on the compute side, and if they do, not always be the choice for each and every deployment. Even though I welcome the work done on the [OVF](https://www.dmtf.org/standards/ovf) file preparation to automate the initial setup, I strongly recommend your team invests some time implementing support for [cloud-init](https://cloudinit.readthedocs.io/en/latest/) in the initial setup script, which is the de facto standard to deploy virtual appliance in cloud environments (KVM on prem, vSphere, AWS, Azure, etc).

Some low hanging fruits at your disposal:
- VirtIO network interface drivers are already available in the appliance (recommended for KVM/QEMU, not limited to VMXNET3). Used in this deployment.
- QEMU agent can easily be installed from Ubuntu repos pre-setup in the appliance (nice to have, covers some functionality of VMware Tools for KVM/QEMU). Used in this deployment.
- cloud-init agent can be easily installed from Ubuntu repos pre-setup in the appliance.