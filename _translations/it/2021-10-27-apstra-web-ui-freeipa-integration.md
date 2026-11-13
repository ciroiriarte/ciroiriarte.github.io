---
title: Integrazione dell'interfaccia web di Apstra con FreeIPA
description: "Far autorizzare gli utenti FreeIPA ai provider LDAP di Apstra 4.0: la ricerca dei gruppi che fallisce e il workaround con posixGroup che funziona."
date: 2021-10-27 12:42:05 -0300
permalink: /it/index.php/2021/10/27/apstra-web-ui-freeipa-integration/
lang: it
categories:
  - networking
  - security
tags:
  - apstra
  - freeipa
  - ldap
---

## Primo tentativo (quello corretto?) {#first-attempt-the-correct-one}

Cercando di dare a più utenti un accesso sensato ad Apstra 4.0.0, ho scoperto che supporta le directory basate su LDAP sotto forma di “Providers” nella sezione “External Systems”:

[Documentazione di Apstra](https://www.juniper.net/documentation/us/en/software/apstra/apstra4.0.0/providers.html#creating-ldap-provider)

Ho adattato con entusiasmo la configurazione di default per farla corrispondere allo schema di FreeIPA (testato con FreeIPA 4.6.8): sono riuscito ad autenticare gli utenti, ma l'autorizzazione è fallita, qualunque parametro cambiassi per modificare la funzione di ricerca dei gruppi.

| Parametro | Valore |
|---|---|
| Groups Search DN | cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Users Search DN | cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Bind DN | uid=sys.apstra,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Password | you.wish |
| Encryption | STARTTLS |

*Tabella 1 - “Provider-specific Parameters” testati – Non funziona*


| **Parametro** | **Valore** | **Default di Apstra?** |
|---|---|---|
| Username Attribute Name | uid | Sì |
| User Search Attribute Name | uid | Sì |
| User First Name Attribute Name | givenName | Sì |
| User Last Name Attribute Name | sn | Sì |
| User Email Attribute Name | mail | Sì |
| User Object Class Attribute Name | inetOrgPerson\* | Sì |
| User Member Attribute Name | memberOf | Sì |
| Group Name Attribute Name | cn | Sì |
| Group DN Attribute Name | entryDN | Sì |
| Group Search Attribute Name | cn | Sì |
| Group Member Attribute Name | entryDN | Sì |
| Group Member Mapping Attribute Name | member | No |
| Group Object Class Attribute Name | groupofnames\* | No |

*Tabella 2 - “Advanced configuration” testata – Non funziona*


Tieni presente che “Group Object Class Attribute Name” può assumere “groupofnames” oppure “ipausergroup” per questo caso d'uso.

Guardando i log, l'attributo per la ricerca dell'appartenenza degli utenti sembra essere fisso su UID, quindi la ricerca è:


> SRCH base="cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com" scope=2 filter="(member=john.doe)" attrs="cn"

Mentre dovrebbe essere come:

> SRCH base="cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com" scope=2 filter="(member=uid=john.doe,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com)" attrs="cn"

## Il workaround {#the-workaround}

Il modo corretto di risolvere sarebbe accettare un parametro con l'attributo utente da usare per la ricerca dell'appartenenza ai gruppi (DN invece di UID in questo caso).

Come workaround, ho scoperto che la [vista “compat”](https://www.freeipa.org/page/V4/chained_compat_tree) di FreeIPA può essere usata per fornire un'altra vista più in linea con quello che presenterebbe, per esempio, openLDAP.

Il problema, per me, è che la vista compat:

- viene generata al volo, non è indicizzata: probabilmente non scala se hai a che fare con migliaia di utenti.
- richiede che il gruppo sia della classe “posixGroup”: dato che i gruppi di Apstra devono essere gruppi solo per l'applicazione, riempirà di gruppi irrilevanti la vista dei sysadmin Unix/Linux.

Nella speranza di una soluzione adeguata da parte di [Juniper ](https://www.juniper.net/us/en.html)(ora proprietari di Apstra), e dato che questo è un ambiente limitato (in termini di scalabilità), il workaround sembra abbastanza buono.

Dato che fallisce solo la ricerca dei gruppi, useremo la vista compat solo per i gruppi.


| **Parametro** | **Valore** |
|---|---|
| Groups Search DN | cn=groups,cn=**compat**,dc=ipa,dc=mydomain,dc=com |
| Users Search DN | cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Bind DN | uid=sys.apstra,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Password | you.wish |
| Encryption | STARTTLS |

*Tabella 3 - “Provider-specific Parameters” testati – Workaround funzionante*



| **Parametro** | **Valore** | Default di Apstra? |
|---|---|---|
| Username Attribute Name | uid | Sì |
| User Search Attribute Name | uid | Sì |
| User First Name Attribute Name | givenName | Sì |
| User Last Name Attribute Name | sn | Sì |
| User Email Attribute Name | mail | Sì |
| User Object Class Attribute Name | inetOrgPerson | Sì |
| User Member Attribute Name | memberOf | Sì |
| Group Name Attribute Name | cn | Sì |
| Group DN Attribute Name | entryDN | Sì |
| Group Search Attribute Name | cn | Sì |
| Group Member Attribute Name | entryDN | Sì |
| Group Member Mapping Attribute Name | **memberUid** | **Sì** |
| Group Object Class Attribute Name | **posixGroup** | **Sì** |

*Tabella 4 - “Advanced configuration” testata – Workaround funzionante*


Non dimenticare di configurare la sezione “Provider Role Mapping” per far funzionare l'autorizzazione.


| **AOS Role** | **Gruppo del provider** |
|---|---|
| administrator | gapstra-administrator | 
| device\_ztp | gapstra-device\_ztp |
| user | gapstra-user |
| viewer | gapstra-viewer |

*Tabella 5 - Configurazione del mapping dei ruoli*

## Nota a margine {#side-note}

Anche se ottengo autenticazione e autorizzazione corrette, l'attributo utente “role” nel profilo mostra solo un riquadro grigio per l'utente gestito da LDAP. Potrebbe essere un bug di presentazione, per il resto l'autorizzazione funziona come previsto

{% include image.html url="/assets/img/2021-10-27-apstra-ldap-user-profile.png" description="Immagine 1 - Profilo di un utente gestito da LDAP." alt="Campo Roles del profilo di un utente gestito da LDAP in Apstra: un riquadro grigio vuoto" width=279 height=66 %}

{% include image.html url="/assets/img/2021-10-27-apstra-admin-user-profile.png" description="Immagine 2 - Profilo dell'utente admin interno." alt="Campo Roles del profilo dell'utente admin interno in Apstra: administrator" width=346 height=76 %}
