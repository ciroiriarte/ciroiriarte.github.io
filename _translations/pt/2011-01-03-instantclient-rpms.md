---
title: InstantClient RPMs
description: "Compartilho um arquivo spec RPM aprimorado do Oracle InstantClient baseado no trabalho de Remi Collet, com ORACLE_HOME, suporte a tnsnames.ora e outras melhorias, para o openSUSE Build Service."
date: 2011-01-03 00:59:38 -0300
permalink: /pt/index.php/2011/01/03/instantclient-rpms/
lang: pt
categories:
  - linux
tags:
  - oracle
  - rpm
  - opensuse
---

Bom, alguns anos atrás me deparei com o arquivo SPEC do Oracle InstantClient preparado por Remi Collet, e foi ótimo encontrá-lo porque os RPMs originais feitos pela Oracle não ajudam a compilar outros pacotes que dependem deles.

<!--more-->

Criei um conjunto de pacotes para um projeto usando o arquivo original do Remi. Alguns dias depois eu os aprimorei para deixar o uso do pacote pelos usuários finais realmente tranquilo (variável de ambiente ORACLE\_HOME, PATHs, etc). Também adicionei outros ajustes, como um script para ajudar a compilar o Perl-DBD-Oracle (não feito por mim), e fiquei muito feliz com os resultados. É aqui que tudo foi ladeira abaixo. Havia uma política de permitir apenas software com código-fonte no openSUSE Build Service e os responsáveis simplesmente apagaram o pacote do meu projeto de repositório e eu perdi todo o trabalho feito.

Eu tinha a recriação do pacote na minha lista de tarefas, mas nunca tive tempo de fazer… Poucos dias atrás, diante de um novo projeto envolvendo Oracle, fui ao blog do Remi procurar o arquivo SPEC original e, por sorte, cerca de um mês antes [ele o tinha modificado](http://blog.famillecollet.com/post/2010/11/12/RPM-Oracle-Instant-Client-11.2-en) para suportar a versão mais recente do cliente (até esta data, 10.2.0.2).

Fiz algumas mudanças nele (neles, já que estavam divididos em dois) e estou compartilhando o resultado aqui. Como toque final vou adicionar o tnsping aos pacotes, que só é incluído na instalação “thick” da Oracle, e talvez eu una o sub-pacote “precomp\*” ao “devel”.

**Arquivos:**

[oracle-instantclient.spec](http://track.itsolutions.com.py/pub/oracle/oracle-instantclient.spec)  
[oracle-instantclient-11.2.0.2.0-37.1.nosrc.rpm](http://track.itsolutions.com.py/pub/oracle/oracle-instantclient.spec)

**Minhas mudanças nos arquivos SPEC do Remi:**

{% highlight text %}
* Sun Jan 2 2011 Ciro Iriarte  11.2.0.2.0
- Added ORACLE_HOME definition
- Added tnsnames.ora example and required directory structure

* Sat Jan 1 2011 Ciro Iriarte 11.2.0.2.0
- merge i386/x86_64 SPECs again
- fixed RPM Groups
- added Jean-Christophe Duberga's config script to help building Perl-DBD-Oracle
 (this wasn't documented on my first change in 2007, and was lost in OBS)
- skip RPATH and BYTECODE verifications in OBS builds
- renamed oracle-instantclient-basic to oracle-instantclient
- added unzip to BuildRequires
- general cleanup to make openSUSE 11.3 sanity checks happy
 o ToDo: Verify rpmlint filters
- add precomp and precomp-devel sub-packages
{% endhighlight %}

**Ref:**

 [Solicitação para permitir o OIC no Build Service](https://features.opensuse.org/308967)
