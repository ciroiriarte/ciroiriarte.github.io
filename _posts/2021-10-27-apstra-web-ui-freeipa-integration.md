---
title: Apstra Web UI + FreeIPA integration
id: 319
date: '2021-10-27T12:42:05-03:00'
author: Ciro Iriarte
layout: post
guid: https://iriarte.it/?p=319
permalink: "/index.php/2021/10/27/apstra-web-ui-freeipa-integration/"
categories:
- Uncategorized
tags:
- Apstra
- FreeIPA
- LDAP
---

## First Attempt (the correct one?)

Looking to provide multiple users sane access to Apstra 4.0.0, I found it supports LDAP based directories in the form of “Providers” in the “External Systems” section:

[Apstra Documentation](https://www.juniper.net/documentation/us/en/software/apstra/apstra4.0.0/providers.html#creating-ldap-provider)

I happily adapted the default configuration to match the FreeIPA schema (tested with FreeIPA 4.6.8), I could authenticate users succesfully but authorization failed, not matter what parameter I change to modify the group lookup function.

| Parameter | Value |
|---|---|
| Groups Search DN | cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Users Search DN | cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Bind DN | uid=sys.apstra,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Password | you.wish |
| Encryption | STARTTLS |

<figure>
<figcaption><i>Table 1 - Tested “Provider-specific Parameters” – Not working</i></figcaption>
</figure>


| **Parameter** | **Value** | **Apstra default?** |
|---|---|---|
| Username Attribute Name | uid | Yes |
| User Search Attribute Name | uid | Yes |
| User First Name Attribute Name | givenName | Yes |
| User Last Name Attribute Name | sn | Yes |
| User Email Attribute Name | mail | Yes |
| User Object Class Attribute Name | inetOrgPerson\* | Yes |
| User Member Attribute Name | memberOf | Yes |
| Group Name Attribute Name | cn | Yes |
| Group DN Attribute Name | entryDN | Yes |
| Group Search Attribute Name | cn | Yes |
| Group Member Attribute Name | entryDN | Yes |
| Group Member Mapping Attribute Name | member | No |
| Group Object Class Attribute Name | groupofnames\* | No |

<figure>
<figcaption><i>Table 2 - Tested “Advanced configuration” – Not working</i></figcaption>
</figure>


Take into account that “Group Object Class Attribute Name” can take “groupofnames” or “ipausergroup” for this usecase.

Looking at the logs, the attribute for user membership lookup seems to be hardcoded to UID, hence the lookup is:


> SRCH base="cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com" scope=2 filter="(member=john.doe)" attrs="cn"

When it should be like:

> SRCH base="cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com" scope=2 filter="(member=uid=john.doe,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com)" attrs="cn"

## The workaround

The correct way to fix this would be to accept a parameter for the user attribute we should use for group membership lookup (DN instead of UID in this case).

As a workaround, I found the [“compat” view](https://www.freeipa.org/page/V4/chained_compat_tree) from FreeIPA could be used to provide another view that’s more inline to what openLDAP would present for example.

The culprit for me is that the compat view:

- is generated on the fly, it’s not indexed: probably won’t scale if you’re dealing with thousands of users.
- requires the group to be of class “posixGroup”: because the Apstra groups are expected to be an application only group, it will clutter the view of Unix/Linux sysadmins with irrelevant groups.

In the hope of waiting for a proper fix from [Juniper ](https://www.juniper.net/us/en.html)(now owners of Apstra), and given this is a limited environment (in terms of scalability), the workaround seems to be good enough.

As only the group lookup fails, we’ll use the compat view only for the groups.


| **Parameter** | **Value** |
|---|---|
| Groups Search DN | cn=groups,cn=**compat**,dc=ipa,dc=mydomain,dc=com |
| Users Search DN | cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Bind DN | uid=sys.apstra,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Password | you.wish |
| Encryption | STARTTLS |

<figure>
<figcaption><i>Table 3 - Tested “Provider-specific Parameters” – Working workaround</i></figcaption>
</figure>



| **Parameter** | **Value** | Apstra default? |
|---|---|---|
| Username Attribute Name | uid | Yes |
| User Search Attribute Name | uid | Yes |
| User First Name Attribute Name | givenName | Yes |
| User Last Name Attribute Name | sn | Yes |
| User Email Attribute Name | mail | Yes |
| User Object Class Attribute Name | inetOrgPerson | Yes |
| User Member Attribute Name | memberOf | Yes |
| Group Name Attribute Name | cn | Yes |
| Group DN Attribute Name | entryDN | Yes |
| Group Search Attribute Name | cn | Yes |
| Group Member Attribute Name | entryDN | Yes |
| Group Member Mapping Attribute Name | **memberUid** | **Yes** |
| Group Object Class Attribute Name | **posixGroup** | **Yes** |

<figure>
<figcaption><i>Table 4 - Tested “Advanced configuration” – Working workaround</i></figcaption>
</figure>


Don’t forget to setup the “Provider Role Mapping” section to get authorization working.


| **AOS Role** | **Provide Group** |
|---|---|
| administrator | gapstra-administrator | 
| device\_ztp | gapstra-device\_ztp |
| user | gapstra-user |
| viewer | gapstra-viewer |

<figure>
<figcaption><i>Table 5 - Role Mapping setup</i></figcaption>
	</figure>

## Side note

Even though I can get proper authentication &amp; authorization, the “role” user attribute in the profile just shows a gray box for the LDAP backed user. Might be a presentation bug, otherwise the authorization works as expected

<!--
|  ![Profile for LDAP backed user](https://iriarte.it/wp-content/uploads/2021/10/image-3.png) |
|:--:| 
| *Profile for LDAP backed user* |
-->

<figure>
  <img src="/wp-content/uploads/2021/10/image-3.png" alt="my alt text"/>
  <figcaption><i>Image 1 - Profile for LDAP backed user.</i></figcaption>
</figure>


<!--
![Profile for internal admin user](https://iriarte.it/wp-content/uploads/2021/10/image-4.png)
-->

<figure>
  <img src="/wp-content/uploads/2021/10/image-4.png" alt="my alt text"/>
  <figcaption><i>Image 2 - Profile for internal admin user.</i></figcaption>
</figure>
