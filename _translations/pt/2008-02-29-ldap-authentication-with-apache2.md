---
title: Autenticação LDAP com apache2
description: "Guia para configurar autenticação LDAP no Apache2 com mod_auth_ldap no SLES9, incluindo a configuração do certificado SSL e do .htaccess."
date: 2008-02-29 08:59:34 -0300
permalink: /pt/index.php/2008/02/29/ldap-authentication-with-apache2/
lang: pt
categories:
  - linux
  - security
tags:
  - apache
  - ldap
  - ssl
  - sles
---

Bem, precisei configurar autenticação usando mod_auth_ldap, aqui vai o procedimento.

<!--more-->

Primeiro precisamos garantir que os módulos necessários sejam carregados na inicialização do apache2; no SLES9 devemos modificar **/etc/sysconfig/apache2** adicionando *"ldap"* e *"auth_ldap"* à variável **APACHE_MODULES**. Esses módulos já vêm embutidos no apache2, então não precisamos instalá-los.

Como estamos usando SSL, vamos precisar do certificado da CA que assina o certificado do servidor LDAP, e também é preciso configurar duas variáveis: **LDAPTrustedCAType**, que especifica o tipo de certificado (“BASE64\_FILE” serve na maioria das vezes; a outra opção seria “DER\_FILE”) e **LDAPTrustedCA**, que aponta para o arquivo do certificado.

Criei um arquivo chamado *“ldapcert.conf”* em **/etc/apache2/conf.d/** configurando-as; este é o conteúdo:

LDAPTrustedCAType BASE64\_FILE  
LDAPTrustedCA /etc/ssl/certs/infra.ldap.pem

Agora devemos configurar o requisito de autenticação para as páginas desejadas; normalmente isso vai em um arquivo **.htaccess**, este é o conteúdo:

AuthName “My WebApp Auth”  
AuthType Basic  
AuthLDAPURL “ldaps://server1 server2/ou=people,dc=my,dc=comain,dc=com?uid”  
require valid-user

No nosso caso, temos dois servidores de diretório por redundância; eles devem ficar entre “ldaps://” e “/” separados por espaços; se você usar apenas um, ficaria algo como “ldaps://server1/ou=people,dc=my,dc=comain,dc=com?uid”.

Caso você use usuário/senha para fazer bind no diretório, deve usar *“AuthLDAPBindDN”* e *“AuthLDAPBindPassword”*; não consegui testar isso, então é só uma nota informativa.

Bem, estamos quase lá, agora precisamos reiniciar o apache; no sles: **“rcapache2 restart”** .

Nos logs devemos encontrar estas linhas:

LDAP: Built with OpenLDAP LDAP SDK <— *ldap modules loaded succesfully*
LDAP: SSL support available <— *CA cert found and read succesfully*

Isso é tudo…
