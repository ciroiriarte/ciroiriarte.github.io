---
title: Integração da interface web do Apstra com o FreeIPA
description: "Fazendo os provedores LDAP do Apstra 4.0 autorizarem usuários do FreeIPA: a busca de grupos que falha e o workaround com posixGroup que funciona."
date: 2021-10-27 12:42:05 -0300
permalink: /pt/index.php/2021/10/27/apstra-web-ui-freeipa-integration/
lang: pt
categories:
  - networking
  - security
tags:
  - apstra
  - freeipa
  - ldap
---

## Primeira tentativa (a correta?) {#first-attempt-the-correct-one}

Querendo dar a vários usuários um acesso decente ao Apstra 4.0.0, descobri que ele suporta diretórios baseados em LDAP na forma de “Providers” na seção “External Systems”:

[Documentação do Apstra](https://www.juniper.net/documentation/us/en/software/apstra/apstra4.0.0/providers.html#creating-ldap-provider)

Adaptei feliz a configuração padrão para casar com o esquema do FreeIPA (testado com FreeIPA 4.6.8), consegui autenticar usuários com sucesso, mas a autorização falhou, não importa qual parâmetro eu mudasse para alterar a função de busca de grupos.

| Parâmetro | Valor |
|---|---|
| Groups Search DN | cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Users Search DN | cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Bind DN | uid=sys.apstra,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Password | you.wish |
| Encryption | STARTTLS |

*Tabela 1 - “Provider-specific Parameters” testados – Não funciona*


| **Parâmetro** | **Valor** | **Padrão do Apstra?** |
|---|---|---|
| Username Attribute Name | uid | Sim |
| User Search Attribute Name | uid | Sim |
| User First Name Attribute Name | givenName | Sim |
| User Last Name Attribute Name | sn | Sim |
| User Email Attribute Name | mail | Sim |
| User Object Class Attribute Name | inetOrgPerson\* | Sim |
| User Member Attribute Name | memberOf | Sim |
| Group Name Attribute Name | cn | Sim |
| Group DN Attribute Name | entryDN | Sim |
| Group Search Attribute Name | cn | Sim |
| Group Member Attribute Name | entryDN | Sim |
| Group Member Mapping Attribute Name | member | Não |
| Group Object Class Attribute Name | groupofnames\* | Não |

*Tabela 2 - “Advanced configuration” testada – Não funciona*


Leve em conta que “Group Object Class Attribute Name” pode receber “groupofnames” ou “ipausergroup” para este caso de uso.

Olhando os logs, o atributo para a busca de associação de usuários parece estar fixo em UID, então a busca é:


{% highlight text %}
SRCH base="cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com" scope=2 filter="(member=john.doe)" attrs="cn"
{% endhighlight %}

Quando deveria ser algo como:

{% highlight text %}
SRCH base="cn=groups,cn=accounts,dc=ipa,dc=mydomain,dc=com" scope=2 filter="(member=uid=john.doe,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com)" attrs="cn"
{% endhighlight %}

## O workaround {#the-workaround}

A forma correta de resolver isso seria aceitar um parâmetro com o atributo de usuário que devemos usar para a busca de associação a grupos (DN em vez de UID neste caso).

Como workaround, descobri que a [visão “compat”](https://www.freeipa.org/page/V4/chained_compat_tree) do FreeIPA pode ser usada para fornecer outra visão mais parecida com o que o openLDAP apresentaria, por exemplo.

O problema para mim é que a visão compat:

- é gerada na hora, não é indexada: provavelmente não escala se você lida com milhares de usuários.
- exige que o grupo seja da classe “posixGroup”: como se espera que os grupos do Apstra sejam grupos exclusivos da aplicação, isso vai poluir a visão dos sysadmins Unix/Linux com grupos irrelevantes.

Na esperança de uma correção adequada da [Juniper ](https://www.juniper.net/us/en.html)(agora dona do Apstra), e dado que este é um ambiente limitado (em termos de escalabilidade), o workaround parece bom o suficiente.

Como só a busca de grupos falha, usaremos a visão compat apenas para os grupos.


| **Parâmetro** | **Valor** |
|---|---|
| Groups Search DN | cn=groups,cn=**compat**,dc=ipa,dc=mydomain,dc=com |
| Users Search DN | cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Bind DN | uid=sys.apstra,cn=users,cn=accounts,dc=ipa,dc=mydomain,dc=com |
| Password | you.wish |
| Encryption | STARTTLS |

*Tabela 3 - “Provider-specific Parameters” testados – Workaround funcionando*



| **Parâmetro** | **Valor** | Padrão do Apstra? |
|---|---|---|
| Username Attribute Name | uid | Sim |
| User Search Attribute Name | uid | Sim |
| User First Name Attribute Name | givenName | Sim |
| User Last Name Attribute Name | sn | Sim |
| User Email Attribute Name | mail | Sim |
| User Object Class Attribute Name | inetOrgPerson | Sim |
| User Member Attribute Name | memberOf | Sim |
| Group Name Attribute Name | cn | Sim |
| Group DN Attribute Name | entryDN | Sim |
| Group Search Attribute Name | cn | Sim |
| Group Member Attribute Name | entryDN | Sim |
| Group Member Mapping Attribute Name | **memberUid** | **Sim** |
| Group Object Class Attribute Name | **posixGroup** | **Sim** |

*Tabela 4 - “Advanced configuration” testada – Workaround funcionando*


Não esqueça de configurar a seção “Provider Role Mapping” para a autorização funcionar.


| **AOS Role** | **Grupo do provedor** |
|---|---|
| administrator | gapstra-administrator | 
| device\_ztp | gapstra-device\_ztp |
| user | gapstra-user |
| viewer | gapstra-viewer |

*Tabela 5 - Configuração do mapeamento de papéis*

## Observação adicional {#side-note}

Mesmo conseguindo autenticação e autorização corretas, o atributo de usuário “role” no perfil mostra só uma caixa cinza para o usuário baseado em LDAP. Pode ser um bug de apresentação, fora isso a autorização funciona como esperado

{% include image.html url="/assets/img/2021-10-27-apstra-ldap-user-profile.png" description="Imagem 1 - Perfil de um usuário baseado em LDAP." alt="Campo Roles do perfil de um usuário baseado em LDAP no Apstra: uma caixa cinza vazia" width=279 height=66 %}

{% include image.html url="/assets/img/2021-10-27-apstra-admin-user-profile.png" description="Imagem 2 - Perfil do usuário admin interno." alt="Campo Roles do perfil do usuário admin interno no Apstra: administrator" width=346 height=76 %}
