---
title: Autenticazione LDAP con apache2
description: "Guida alla configurazione dell'autenticazione LDAP su Apache2 con mod_auth_ldap su SLES9, inclusa la configurazione del certificato SSL e di .htaccess."
date: 2008-02-29 08:59:34 -0300
permalink: /it/index.php/2008/02/29/ldap-authentication-with-apache2/
lang: it
categories:
  - linux
  - security
tags:
  - apache
  - ldap
  - ssl
  - sles
---

Bene, mi serviva configurare l'autenticazione con mod_auth_ldap, ecco la procedura.

<!--more-->

Prima di tutto dobbiamo assicurarci che i moduli necessari vengano caricati all'avvio di apache2; in SLES9 dobbiamo modificare **/etc/sysconfig/apache2** aggiungendo *"ldap"* e *"auth_ldap"* alla variabile **APACHE_MODULES**. Questi moduli sono integrati in apache2, quindi non serve installarli.

Dato che usiamo SSL, ci serve il certificato della CA che firma il certificato del server LDAP, e vanno impostate anche due variabili: **LDAPTrustedCAType**, che specifica il tipo di certificato (“BASE64\_FILE” va bene nella maggior parte dei casi; l'altra opzione sarebbe “DER\_FILE”) e **LDAPTrustedCA**, che punta al file del certificato.

Ho creato un file chiamato *“ldapcert.conf”* in **/etc/apache2/conf.d/** dove le imposto; questo è il contenuto:

LDAPTrustedCAType BASE64\_FILE  
LDAPTrustedCA /etc/ssl/certs/infra.ldap.pem

Ora dobbiamo configurare il requisito di autenticazione per le pagine desiderate; di solito questo va in un file **.htaccess**, questo è il contenuto:

AuthName “My WebApp Auth”  
AuthType Basic  
AuthLDAPURL “ldaps://server1 server2/ou=people,dc=my,dc=comain,dc=com?uid”  
require valid-user

Nel nostro caso abbiamo due directory server per ridondanza; vanno messi tra “ldaps://” e “/” separati da spazi; se ne usi uno solo, sarebbe qualcosa tipo “ldaps://server1/ou=people,dc=my,dc=comain,dc=com?uid”.

Nel caso tu usi utente/password per il bind alla directory, dovresti usare *“AuthLDAPBindDN”* e *“AuthLDAPBindPassword”*; non ho potuto provarlo, quindi è solo una nota informativa.

Bene, ci siamo quasi, ora dobbiamo riavviare apache; in sles: **“rcapache2 restart”** .

Nei log dovremmo trovare queste righe:

LDAP: Built with OpenLDAP LDAP SDK <— *ldap modules loaded succesfully*
LDAP: SSL support available <— *CA cert found and read succesfully*

Questo è tutto…
