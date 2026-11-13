---
title: Integración de la interfaz web de Apstra con FreeIPA
description: "Hacer que los proveedores LDAP de Apstra 4.0 autoricen usuarios de FreeIPA: la búsqueda de grupos que falla y el workaround con posixGroup que funciona."
date: 2021-10-27 12:42:05 -0300
permalink: /es/index.php/2021/10/27/apstra-web-ui-freeipa-integration/
lang: es
categories:
  - networking
  - security
tags:
  - apstra
  - freeipa
  - ldap
---

## Primer intento (¿el correcto?) {#first-attempt-the-correct-one}

Buscando dar a varios usuarios un acceso razonable a Apstra 4.0.0, descubrí que soporta directorios basados en LDAP en forma de “Providers” en la sección “External Systems”:

[Documentación de Apstra](https://www.juniper.net/documentation/us/en/software/apstra/apstra4.0.0/providers.html#creating-ldap-provider)

Adapté feliz la configuración por defecto para que coincidiera con el esquema de FreeIPA (probado con FreeIPA 4.6.8), pude autenticar usuarios con éxito pero la autorización falló, sin importar qué parámetro cambiara para modificar la función de búsqueda de grupos.

| Parámetro | Valor |
|---|---|
| Groups Search DN | cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Users Search DN | cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Bind DN | uid=sys.apstra,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Password | you.wish |
| Encryption | STARTTLS |

*Tabla 1 - “Provider-specific Parameters” probados – No funciona*


| **Parámetro** | **Valor** | **¿Valor por defecto de Apstra?** |
|---|---|---|
| Username Attribute Name | uid | Sí |
| User Search Attribute Name | uid | Sí |
| User First Name Attribute Name | givenName | Sí |
| User Last Name Attribute Name | sn | Sí |
| User Email Attribute Name | mail | Sí |
| User Object Class Attribute Name | inetOrgPerson\* | Sí |
| User Member Attribute Name | memberOf | Sí |
| Group Name Attribute Name | cn | Sí |
| Group DN Attribute Name | entryDN | Sí |
| Group Search Attribute Name | cn | Sí |
| Group Member Attribute Name | entryDN | Sí |
| Group Member Mapping Attribute Name | member | No |
| Group Object Class Attribute Name | groupofnames\* | No |

*Tabla 2 - “Advanced configuration” probada – No funciona*


Ten en cuenta que “Group Object Class Attribute Name” puede tomar “groupofnames” o “ipausergroup” para este caso de uso.

Mirando los logs, el atributo para la búsqueda de membresía de usuarios parece estar fijo en UID, por lo que la consulta es:


> SRCH base="cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com" scope=2 filter="(member=john.doe)" attrs="cn"

Cuando debería ser algo como:

> SRCH base="cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com" scope=2 filter="(member=uid=john.doe,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com)" attrs="cn"

## El workaround {#the-workaround}

La forma correcta de arreglar esto sería aceptar un parámetro con el atributo de usuario que debemos usar para la búsqueda de membresía de grupos (DN en lugar de UID en este caso).

Como workaround, descubrí que la [vista “compat”](https://www.freeipa.org/page/V4/chained_compat_tree) de FreeIPA se puede usar para proveer otra vista más parecida a lo que presentaría openLDAP, por ejemplo.

El problema para mí es que la vista compat:

- se genera al vuelo, no está indexada: probablemente no escale si manejas miles de usuarios.
- requiere que el grupo sea de la clase “posixGroup”: como se espera que los grupos de Apstra sean grupos exclusivos de la aplicación, va a llenar de grupos irrelevantes la vista de los sysadmins de Unix/Linux.

A la espera de una solución adecuada de [Juniper ](https://www.juniper.net/us/en.html)(ahora dueños de Apstra), y dado que este es un entorno limitado (en términos de escalabilidad), el workaround parece suficientemente bueno.

Como solo falla la búsqueda de grupos, usaremos la vista compat solamente para los grupos.


| **Parámetro** | **Valor** |
|---|---|
| Groups Search DN | cn=groups,cn=**compat**,dc=ipa,dc=mydomain,dc=com |
| Users Search DN | cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Bind DN | uid=sys.apstra,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Password | you.wish |
| Encryption | STARTTLS |

*Tabla 3 - “Provider-specific Parameters” probados – Workaround que funciona*



| **Parámetro** | **Valor** | ¿Valor por defecto de Apstra? |
|---|---|---|
| Username Attribute Name | uid | Sí |
| User Search Attribute Name | uid | Sí |
| User First Name Attribute Name | givenName | Sí |
| User Last Name Attribute Name | sn | Sí |
| User Email Attribute Name | mail | Sí |
| User Object Class Attribute Name | inetOrgPerson | Sí |
| User Member Attribute Name | memberOf | Sí |
| Group Name Attribute Name | cn | Sí |
| Group DN Attribute Name | entryDN | Sí |
| Group Search Attribute Name | cn | Sí |
| Group Member Attribute Name | entryDN | Sí |
| Group Member Mapping Attribute Name | **memberUid** | **Sí** |
| Group Object Class Attribute Name | **posixGroup** | **Sí** |

*Tabla 4 - “Advanced configuration” probada – Workaround que funciona*


No olvides configurar la sección “Provider Role Mapping” para que la autorización funcione.


| **AOS Role** | **Grupo del proveedor** |
|---|---|
| administrator | gapstra-administrator | 
| device\_ztp | gapstra-device\_ztp |
| user | gapstra-user |
| viewer | gapstra-viewer |

*Tabla 5 - Configuración del mapeo de roles*

## Nota al margen {#side-note}

Aunque logro autenticación y autorización correctas, el atributo de usuario “role” en el perfil solo muestra una caja gris para el usuario respaldado por LDAP. Podría ser un bug de presentación; por lo demás la autorización funciona como se espera

{% include image.html url="/assets/img/2021-10-27-apstra-ldap-user-profile.png" description="Imagen 1 - Perfil de un usuario respaldado por LDAP." alt="Campo Roles del perfil de un usuario respaldado por LDAP en Apstra: una caja gris vacía" width=279 height=66 %}

{% include image.html url="/assets/img/2021-10-27-apstra-admin-user-profile.png" description="Imagen 2 - Perfil del usuario admin interno." alt="Campo Roles del perfil del usuario admin interno en Apstra: administrator" width=346 height=76 %}
