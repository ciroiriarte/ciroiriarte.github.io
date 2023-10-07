---
title: Integrating Apstra Appliances Operating System to FreeIPA
description: IPA client installation on Ubuntu based appliances for Apstra 4.2.0
layout: post
author: ciroiriarte
categories:
- HomeLab
- SDN
tags:
- Apstra
- FreeIPA
- Ubuntu
---

# Intent

If you're working in any sane environment involving Unix/Linux servers, for sure you should have in place some kind of centralized authentication/authorization schema for operating system access. These days it's LDAP or LDAP+Kerberos.

In my case, I'm using FreeIPA for the Linux ecosystem.

# Apstra appliances

Apstra is configuration management & monitoring tool for Datacenter Networks, I don't think of it being a proper SDN controller (at least in the original term conception) because it's more related to configuration management tools like Puppet or Ansible. Nonetheless, it's part of the SDN tooling ecosystem. 

Apstra appliances are based on Ubuntu LTS, gladly, we have the official FreeIPA accessible. Most probably, your Juniper representative will tell you that installing official Ubuntu packages is not supported.

I've implemented this with Apstra 4.1.0, 4.1.1 and 4.1.2 before, but 4.2.0 needs a tweak this time. It works and doesn't interfere with its functionality in my experience, nonetheless, testing in a lab environment is recommended before moving to production. Proceed at your own risk.

# Assumptions
1. You have a properly deployed Apstra related ecosystems appliances (AOS, ZTP, workers)
2. Correct Timezone is already setup
3. NTP client configuration is in place
4. DNS client configutarion is in place

# FreeIPA server side configuration

Make sure the client has a DNS entry.

{% highlight shell %}
ipa dnsrecord-add <your domain> <client shortname> --a-rec <IPv4 for the client>
ipa dnsrecord-add <your domain> <client shortname> --aaaa-rec <IPv6 for the client>
{% endhighlight %}

# Python libraries and AOS

Well, this is a special with Apstra 4.2.0. There are python modules installed with *pip* outside of what apt based packages provide, they apparently are needed for the Apstra platform but break other tools like ipa-client-install for the AOS appliance (doesn't happen with the ZTP appliance).

ZTP appliance:

{% highlight shell %}
admin@apstra-ztp-03:~$ pip show cryptography
Name: cryptography
Version: 3.4.8
Summary: cryptography is a package which provides cryptographic recipes and primitives to Python developers.
Home-page: https://github.com/pyca/cryptography
Author: The Python Cryptographic Authority and individual contributors
Author-email: cryptography-dev@python.org
License: BSD or Apache License, Version 2.0
Location: /usr/lib/python3/dist-packages
Requires: 
Required-by: ansible-core, paramiko
{% endhighlight %}

AOS appliance:

{% highlight shell %}
admin@apstra-os-03:~$ pip show cryptography
Name: cryptography
Version: 38.0.0
Summary: cryptography is a package which provides cryptographic recipes and primitives to Python developers.
Home-page: https://github.com/pyca/cryptography
Author: The Python Cryptographic Authority and individual contributors
Author-email: cryptography-dev@python.org
License: BSD-3-Clause OR Apache-2.0
Location: /usr/local/lib/python3.10/dist-packages
Requires: cffi
Required-by: paramiko
{% endhighlight %}

Note that the version for AOS is newer, and modules reside in /usr/local/lib instead of /usr/lib.

A container based application like Apstra should have everything needed for the application inside the container and should not require or mess host level libraries.

## How it affects ipa-client-install
The IPA configuration tool fails with this error:

{% highlight shell %}
admin@apstra-os-03:~$ ipa-client-install 
Traceback (most recent call last):
  File "/usr/sbin/ipa-client-install", line 22, in <module>
    from ipaclient.install import ipa_client_install
  File "/usr/lib/python3/dist-packages/ipaclient/install/ipa_client_install.py", line 7, in <module>
    from ipaclient.install import client
  File "/usr/lib/python3/dist-packages/ipaclient/install/client.py", line 37, in <module>
    from ipalib import api, errors, x509
  File "/usr/lib/python3/dist-packages/ipalib/__init__.py", line 921, in <module>
    from ipalib.frontend import Command, LocalOrRemote, Updater
  File "/usr/lib/python3/dist-packages/ipalib/frontend.py", line 31, in <module>
    from ipalib.parameters import create_param, Param, Str, Flag
  File "/usr/lib/python3/dist-packages/ipalib/parameters.py", line 125, in <module>
    from ipalib.x509 import (
  File "/usr/lib/python3/dist-packages/ipalib/x509.py", line 91, in <module>
    @crypto_utils.register_interface(crypto_x509.Certificate)
**AttributeError: module 'cryptography.utils' has no attribute 'register_interface'. Did you mean: 'verify_interface'?**
{% endhighlight %}

It seems FreeIPA was using a function that was not expected to be used outside of the capy/cryptography implementation. The latter project team [decided to deprecate the function](https://github.com/pyca/cryptography/pull/7234) in 38.0, installing the newer library outside of what the distro provides, breaks the FreeIPA client provided by it.

FreeIPA project is [complying with the upstream change](https://github.com/freeipa/freeipa/pull/6455), and should be included in 4.11+

## The correct way of dealing with this

### Golden rule

You don't mess with Linux Distribution provided libraries. Ever.

### Tools at hand for software packagers

Containers is one current software delivery solution that could address this. In fact, Juniper is using docker containers. I'm a little lost about why this is a problem today with the Apstra AOS appliance, but packaging all the dependancies within the containers should be the correct course of action.


## Workaround for Juniper customers

All we can do until Juniper properly packages Apstra as a set of container images is to choose the less ugly route. In this case, I've rebuilt a package from Ubuntu Ubuntu 23.04, which is based on FreeIPA 4.9.11 source code, for Ubuntu 22.04 (in which the Apstra appliance is based).

We'll add the repository just for AOS, ZTP appliance can use the stock packages. 

{% highlight shell %}
sudo sh -c 'echo "deb http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04/ /" | sudo tee /etc/apt/sources.list.d/home:ciriarte:apstra-4.2.0-fix.list'
sudo sh -c 'curl -fsSL https://download.opensuse.org/repositories/home:ciriarte:apstra-4.2.0-fix/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg > /dev/null'
sudo chmod a+r /etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg
sudo chmod a+r /etc/apt/sources.list.d/home:ciriarte:apstra-4.2.0-fix.list
sudo apt update
{% endhighlight %}

After adding the repository, just follow the below procedure.


# Clients configuration

For each client in question, ZTP appliance, main AOS appliance or workers you would need to execute these steps.

## DNS validation
DNS is critical in this environment, make sure the clients can actually locate your IP servers.

1. Test the the client is actually configured
{% highlight shell %}
dig _ldap._tcp.<your domain> SRV
{% endhighlight %}

{:start="2"}
1. Test that all expected servers are actually answering. There are some funky scenarios were some servers answer and others dont.
{% highlight shell %}
dig @<recursor/resolver 1 IP>  _ldap._tcp.<your domain> SRV
dig @<recursor/resolver 2 IP>  _ldap._tcp.<your domain> SRV
{% endhighlight %}

## Client installation & configuration

The FreeIPA client is part of the default repositories, just install it with the package manager:

{% highlight shell %}
sudo apt install -y freeipa-client
sudo ipa-client-install --mkhomedir --enable-dns-updates \
 --domain=<IPA domain in lowercase> --realm=<IPA domain in uppercase>
{% endhighlight %}

## Limit SSH access

It's good practice to limit access via SSH to users that really need access to the node. 

Thinking about this, it should be done with FreeIPA's HBAC module + pam_sss.so. I can't recall why in this environment we're hardcoding the group at the sshd level, will keep it for consistency. **To be revisited**

{% highlight shell %}
sudo sh -c 'echo "AllowGroups ssh-allow gapstra-administrator" >> /etc/ssh/sshd_config'
sudo systemctl restart sshd
{% endhighlight %}