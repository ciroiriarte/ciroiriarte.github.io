---
title: Renderizado más rápido de japonés en Firefox
description: "Cómo arreglar el renderizado lento de texto japonés en Firefox sobre openSUSE instalando las fuentes WQY, con instrucciones paso a paso usando zypper."
date: 2009-03-15 00:10:14 -0400
permalink: /es/index.php/2009/03/15/faster-japanese-rendering-in-firefox/
lang: es
categories:
  - linux
tags:
  - opensuse
  - firefox
  - fonts
---

Hace años descubrí que renderizar contenido en japonés en Firefox era REALMENTE lento, pero simplemente me resigné a vivir con eso y algún tiempo después me olvidé del asunto porque dejé de acceder a contenido en japonés….

Hoy encontré contenido interesante otra vez después de leer algunos posts en kirainet.com, y de pronto volví a molestarme con esta lentitud de renderizado. Tras investigar un poco, encontré [este ](http://forums.opensuse.org/applications/405280-firefox-slow-chinese-japanese-symbols-solution.html)post que resuelve el problema. No estoy muy seguro de por qué estas fuentes ayudan a renderizar las páginas más rápido que las fuentes por defecto, ¿no deberían venir incluidas en la distro?

Este es el procedimiento para instalarlas en openSUSE (probado con 11.0@x86\_64):

Busca un repositorio adecuado en http://software.opensuse.org/search

Agrega el repositorio a tu sistema (no TIENES que hacerlo, pero así podrás obtener actualizaciones más adelante):

> zypper addrepo http://download.opensuse.org/repositories/home:/swyear/openSUSE\_11.0 “Japanese Fonts”

Instala los paquetes:

> zypper install ttf-wqy-zenhei wqy-bitmapfont

Te preguntará si debe confiar en la clave y luego importarla, simplemente responde “YES” a ambas preguntas. Tendrás que reiniciar Firefox para usar estas fuentes nuevas..

Páginas para probar el renderizado:

> <https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC>
> 
> <http://news.google.com/news?ned=cn>
> 
> <http://news.google.com/news?ned=jp>
> 
> <http://kayanomori.net/memo/index.php?iFolder%20Simple%20Server>
