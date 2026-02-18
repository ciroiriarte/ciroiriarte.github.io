---
id: 18
title: 'LDAP authentication with apache2'
date: '2008-02-29T08:59:34-03:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=16'
permalink: /index.php/2008/02/29/ldap-authentication-with-apache2/
description: 'Guide for setting up LDAP authentication on Apache2 with mod_auth_ldap on SLES9, including SSL certificate setup and .htaccess configuration.'
categories:
    - apache
    - Linux
    - SLES
tags:
    - apache2
    - ldap
    - mod_auth_ldap
    - sles
    - ssl
---

Well, needed to setup authentication using mod_auth_ldap, here's the procedure.

<!-- more -->

First we need to make sure the required modules are loaded on apache2 startup, in SLES9 we should modify **/etc/sysconfig/apache2** adding *"ldap"* and *"auth_ldap"* to the **APACHE_MODULES** variable. This modules are builtin in apache2, so we don't need to install them.

As we are using SSL, we’ll need the certificate of the CA that signs the LDAP server certificate, also two variables need to be setup, **LDAPTrustedCAType** specifies the certificate type, “BASE64\_FILE” would be fine most of the time (the other option would be “DER\_FILE”) and **LDAPTrustedCA** that points to the certificate file.

I created a file named *“ldapcert.conf”* in **/etc/apache2/conf.d/** setting them up, this is the content:

LDAPTrustedCAType BASE64\_FILE  
LDAPTrustedCA /etc/ssl/certs/infra.ldap.pem

Now, we should setup the authentication requirement for the desired pages, usually this would go in a **.htaccess** file, this is the content:

AuthName “My WebApp Auth”  
AuthType Basic  
AuthLDAPURL “ldaps://server1 server2/ou=people,dc=my,dc=comain,dc=com?uid”  
require valid-user

In our case, we have two directory servers for redundancy, the should go between “ldaps://” and “/” using spaces, if you use only one, it would look something like “ldaps://server1/ou=people,dc=my,dc=comain,dc=com?uid”.

In case you use user/passwd to bind to the directory, you should use *“AuthLDAPBindDN”* and *“AuthLDAPBindPassword”*, couldn’t test this, so it’s just an informative note.

Well, we are almost there, we need to restart apache now, in sles: **“rcapache2 restart”** .

In the logs we should find this lines:

LDAP: Built with OpenLDAP LDAP SDK <— *ldap modules loaded succesfully*
LDAP: SSL support available <— *CA cert found and read succesfully*

That’s all…