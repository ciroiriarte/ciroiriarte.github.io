---
title: Setting up JunOS devices for Juniper Support Insights
description: Walkthrough NE setup to allos vLWC to connect and extract information.
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

Going back to the "supported" track, after deploying vLWC you need to prepare the devices being monitored. The requirements are straightfoward conceptually, but it was hard to gather the details:

1. NETCONF-SSH
2. Process user account dedicated to JSI/vLWC.

An overview of how data collection works can be found in this [flyer](https://www.juniper.net/content/dam/www/assets/flyers/us/en/juniper-support-insights-security-and-privacy-overview.pdf)


<figure>
  <a href="/assets/img/2023-12-27_datacollection_overview.png">
  <img src="/assets/img/2023-12-27_datacollection_overview.png" alt="Flow Overview"/>
  </a>
  <figcaption><i>Image 1 - Data collection overview "</i></figcaption>
</figure>

# Pre-requirements

## SSH key pair

We need a pair of public/private SSH keys for the user. You can create it on any Linux machine. 

**Notes:** Down in the process I found that JunOS won't accept DSA keys but RSA only.

{% highlight shell %}
ciro.iriarte@jhost01:~> ssh-keygen -t rsa -C "JSI process user" -f ~/.ssh/id_rsa-jsi
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): <-- make sure you input a passphrase
Enter same passphrase again: 
Your identification has been saved in /home/ciro.iriarte/.ssh/id_rsa-jsi
Your public key has been saved in /home/ciro.iriarte/.ssh/id_rsa-jsi.pub
The key fingerprint is:
SHA256:vMRG09Sd7BR1Q5P7B+9RakR2thSR3Md3bBOtYmm+VVc JSI process user
The key's randomart image is:
+---[RSA 3072]----+
|          .. o+&@|
|         o  . B*E|
|        o .  *.=O|
|       + .  = =o+|
|        S  + o =+|
|       o .  . +.+|
|        .    + .o|
|            .   .|
|                 |
+----[SHA256]-----+
{% endhighlight %}

You'll use:
- the contents of *~/.ssh/id_rsa-jsi.pub* to setup access in the switches
- the contents of *~/.ssh/id_rsa-jsi* + *the passphrase will* be used in the JSI portal to define the access credentials.

## Actual commands that are to be allowed

The overview flyer briefly mentions what's needed, but doesn't provide in details what permissions are needed for the process user. Our Juniper support team hinted about the used config from a previous deployment (thanks Alejandro for the guidance, once more). 

Unofficially, this should be enough for JSI to work:

```
show system uptime
show chassis alarms
show interfaces descriptions
show system commit
show chassis routing-engine
show chassis hardware extensive
show interfaces terse
show version
show system core-dumps
```

# Apstra managed switches

## NETCONF
NETCONF is already an Apstra requirement, so you should have that already covered. To quickly validate, you can verify the default port is listening for connection requests:

{% highlight shell %}
ciro.iriarte@jhost01:~> nmap -p 830 ipf01-lf01.<TLD>
Starting Nmap 7.92 ( https://nmap.org ) at 2023-12-27 14:12 EST
Nmap scan report for ipf01-lf01.<TLD> (x.y.z.w)
Host is up (0.0012s latency).

PORT    STATE SERVICE
830/tcp open  netconf-ssh

Nmap done: 1 IP address (1 host up) scanned in 6.58 seconds
{% endhighlight %}

## Process user

In this environment we don't have TACACS+ (it's 2023 Juniper team, can we please get LDAP already?). For practical purposes, we'll use Apstra configlets to create a process users from Apstra.

### Configlet creation

1. Reach the configlet creation page.
<figure>
  <a href="/assets/img/2023-12-27_configlet00.png">
  <img src="/assets/img/2023-12-27_configlet00.png" alt="Apstra screenshot"/>
  </a>
  <figcaption><i>Image 2 - Design --> Configlets "</i></figcaption>
</figure>
<figure>
  <a href="/assets/img/2023-12-27_configlet01.png">
  <img src="/assets/img/2023-12-27_configlet01.png" alt="Apstra screenshot"/>
  </a>
  <figcaption><i>Image 3 - Create configlet button "</i></figcaption>
</figure>

{:start="2"}
2. Fill in the basic configlet data

<figure>
  <a href="/assets/img/2023-12-27_configlet02.png">
  <img src="/assets/img/2023-12-27_configlet02.png" alt="Apstra screenshot"/>
  </a>
  <figcaption><i>Image 4 - Actual configlet create "</i></figcaption>
</figure>

{:start="3"}
3. Paste the following content in the body, and click "Create"
```
system {
    login {
        class jsi-class {
            permissions view-configuration;
            allow-commands "(show system uptime)|(show chassis alarms)|(show interfaces descriptions)|(show system commit)|(show chassis routing-engine)|(show chassis hardware extensive)|(show interfaces terse)|(show version)|(show system core-dumps)";
            deny-commands "(clear)|(file)|(file show)|(help)|(load)|(monitor)|(op)|(request)|(save)|(set)|(start)|(test)";
            deny-configuration all;
        }
        user svcjsi {
            full-name "JSI process user";
            uid 2007;
            class jsi-class;
            authentication {
                ssh-rsa "full content of your private key file";
            }
        }
    }
}
```

**Note:** Make sure UID is unique in your environment. I saw random documentation referencing UID 2000, I was super clever changing that 2001 so I would avoid clashing with config everybody else could be copying/pasting, it turns out whoever implemented Apstra had the same thought.

### Importing Configlet to blueprint

To actually apply the previously created configlet to your network elements, you must:

1. Import configlet to the blueprint, assigning it to the devices of interest. In my case, that would be all the spines and leaf switches.

<figure>
  <a href="/assets/img/2023-12-27_import-configlet00.png">
  <img src="/assets/img/2023-12-27_import-configlet00.png" alt="Apstra screenshot"/>
  </a>
  <figcaption><i>Image 5 - Reach the import section "</i></figcaption>
</figure>

<figure>
  <a href="/assets/img/2023-12-27_import-configlet01.png">
  <img src="/assets/img/2023-12-27_import-configlet01.png" alt="Apstra screenshot"/>
  </a>
  <figcaption><i>Image 6 - Select configlet and assign to devices of interest "</i></figcaption>
</figure>

{:start="2"}
2. Commit the configuration to be pushed to the devices.

<figure>
  <a href="/assets/img/2023-12-27_commit00.png">
  <img src="/assets/img/2023-12-27_commit00.png" alt="Apstra screenshot"/>
  </a>
  <figcaption><i>Image 7 - Request to push changes to the NEs "</i></figcaption>
</figure>

<figure>
  <a href="/assets/img/2023-12-27_commit01.png">
  <img src="/assets/img/2023-12-27_commit01.png" alt="Apstra screenshot"/>
  </a>
  <figcaption><i>Image 8 - Fill-in the changelog "</i></figcaption>
</figure>

# Standalone switches

These switches aren't managed by Apstra or any other manager, also there's no TACACS+ or similar authentication  or RBAC services (did I mention I would love to have LDAP available to reuse already existing authentication services?). Given they are only 2, manual & local setup should not be a problem.

Connect to the switch with an admin user, in edit mode.

## NETCONF

1. We enable the service. Cool automation kids recommend the last 3 commands for interoperability, but given vLWC is a closed tool by Juniper for JunOS it might expect the less standard non compliant default configuration. Something to monitor and validate after adding switches to JSI.
   
```
set system services netconf ssh
set system services netconf rfc-compliant
set system services netconf yang-compliant 
set system services netconf hello-message yang-module-capabilities advertise-standard-yang-modules
```

## Process user

1. We create the user class with the required access level
```
set system login class jsi-class permissions view-configuration
set system login class jsi-class allow-commands "(show system uptime)|(show chassis alarms)|(show interfaces descriptions)|(show system commit)|(show chassis routing-engine)|(show chassis hardware extensive)|(show interfaces terse)|(show version)|(show system core-dumps)"
set system login class jsi-class deny-commands "(clear)|(file)|(file show)|(help)|(load)|(monitor)|(op)|(request)|(save)|(set)|(start)|(test)"
set system login class jsi-class deny-configuration all
```

2. We create the user, using the previously created class.
```
set system login user svcjsi class jsi-class
set system login user svcjsi full-name "JSI process user"
set system login user svcjsi uid 2007
set system login user svcjsi authentication ssh-rsa "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDkPLZNw2Ypc0XAoDXP6sIP92yY3nX/OclflAVqvPHxnxLmzA8XApRxOAIpfIPeR5NHSm3KS0gpGo0kHg14wrhUkcGl+pJT5/DOZccRX+TQ6Z4NGr0aTh8KSMmrosGPW2u/gZ91Z8WjDkjRKsYcnMHdn5iqzkbH39YEeb0B4ls0pMUuWIcvmM/tRvCjSFh+5nBEPepH4yWTywYKQhoRgLXfNML7apYkkc0TkF+Mm/ZsDk9Hv/7nxaPgiKUfVChwMbN6z5KHPELORiM1lctm0pPFX9QeKTf8uppkQI3RWK0zrX6XrRRv/9xTNYTPKEeAjh+WTqzvDFbe+h/OzHedP66/dBcm8cA7BSNVE+Xg/bJTkvnHpMNIO0B11f7eWSMw6OTx2I4llJNANU5G1Ei3Ru+zDhIJIrSWPf3ksxJ25pSLr+E2qYIkg8IyLuzrAuvDmHIjxnPS3px0UvA9LbfHoj0VIKc3jZoeBQ8GTejfgZ0EVQac64UNlLErgs0IzqWcQnU= JSI process user"
```

## Final commit

3. Commit the configuration (both service & user)
```
commit
```

# Testing NETCONF by hand

Before going through the whole JSI apparatus, my recommendation would be to run a basic local test with the user we have created.

Login to a Linux machine with access to the switches and the private key for the user we have created, and try to connect to the switch using NETCONF

{% highlight shell %}
# We start the ssh key agent
eval $(ssh-agent)

# We add the key to the agent, the command will prompt for the key passphrase
ssh-add ~/.ssh/id_rsa-jsi

# We try a connection on default port
MYSWITCH=host.tld
ssh svcjsi@$MYSWITCH -p 830 -s netconf
{% endhighlight %}

Answer should be similar to

{% highlight xml %}
<!-- No zombies were killed during the creation of this user interface -->
<!-- user svcjsi, class j-jsi-class -->
<nc:hello xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">
   <nc:capabilities>
    <nc:capability>urn:ietf:params:netconf:base:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:candidate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:confirmed-commit:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:validate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:url:1.0?scheme=http,ftp,file</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:base:1.0?module=ietf-netconf&amp;revision=2011-06-01</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:candidate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:confirmed-commit:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:validate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:url:1.0?scheme=http,ftp,file</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:yang:ietf-inet-types?module=ietf-inet-types&amp;revision=2013-07-15</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring</nc:capability>
    <nc:capability>http://xml.juniper.net/netconf/junos/1.0</nc:capability>
    <nc:capability>http://xml.juniper.net/dmi/system/1.0</nc:capability>
  </nc:capabilities>
  <nc:session-id>65596</nc:session-id>
</nc:hello>
]]>]]>
{% endhighlight %}

# Is that it?

Well, it should be all for the NE configuration. Now you should be able to login to the JSI portal an onboard devices (Juniper guys, please add support for FQDN in the form besides IP addresses).

Have fun!

# More reference documents

In case you're still reading, these are some documents & notes I've reviewed in the process.

- [Establish an SSH Connection for a NETCONF Session](https://www.juniper.net/documentation/us/en/software/junos/netconf/topics/topic-map/netconf-ssh-connection.html)  
- [Managing Juniped devices with SSH and NETCONF](https://www.tinfoilcipher.co.uk/2021/07/29/ansible-and-juniper-junos-managing-devices-with-ssh-and-netconf/)
- [Example: Configuring User Permissions with Access Privileges for Operational Mode Commands](https://www.juniper.net/documentation/en_US/junos/topics/example/access-privileges-individual-operational-mode-commands-configuring.html)