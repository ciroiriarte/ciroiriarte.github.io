---
title: Renderização mais rápida de japonês no Firefox
description: "Como corrigir a renderização lenta de texto japonês no Firefox no openSUSE instalando as fontes WQY, com instruções passo a passo usando zypper."
date: 2009-03-15 00:10:14 -0400
permalink: /pt/index.php/2009/03/15/faster-japanese-rendering-in-firefox/
lang: pt
categories:
  - linux
tags:
  - opensuse
  - firefox
  - fonts
---

Anos atrás descobri que renderizar conteúdo em japonês no Firefox era REALMENTE lento, mas simplesmente me resignei a conviver com isso e algum tempo depois esqueci o assunto, porque parei de acessar conteúdo em japonês….

Hoje encontrei conteúdo interessante de novo depois de ler alguns posts no kirainet.com, e de repente fiquei irritado mais uma vez com essa lentidão de renderização. Depois de pesquisar um pouco, encontrei [este ](http://forums.opensuse.org/applications/405280-firefox-slow-chinese-japanese-symbols-solution.html)post que resolve o problema. Não tenho muita certeza de por que essas fontes ajudam a renderizar as páginas mais rápido que as fontes padrão, será que elas não deveriam vir incluídas na distro?

Aqui está o procedimento para instalá-las no openSUSE (testado com 11.0@x86\_64):

Encontre um repositório adequado em http://software.opensuse.org/search

Adicione o repositório ao seu sistema (você não PRECISA fazer isso, mas assim poderá receber atualizações depois):

{% highlight shell %}
zypper addrepo http://download.opensuse.org/repositories/home:/swyear/openSUSE_11.0 "Japanese Fonts"
{% endhighlight %}

Instale os pacotes:

{% highlight shell %}
zypper install ttf-wqy-zenhei wqy-bitmapfont
{% endhighlight %}

Ele vai perguntar se deve confiar na chave e depois importá-la, é só responder “YES” às duas perguntas. Você terá que reiniciar o Firefox para usar essas fontes novas..

Páginas para testar a renderização:

- <https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC>
- <http://news.google.com/news?ned=cn>
- <http://news.google.com/news?ned=jp>
- <http://kayanomori.net/memo/index.php?iFolder%20Simple%20Server>
