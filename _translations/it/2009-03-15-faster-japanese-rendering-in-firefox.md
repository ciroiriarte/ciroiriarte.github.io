---
title: Rendering più veloce del giapponese in Firefox
description: "Come risolvere il rendering lento del testo giapponese in Firefox su openSUSE installando i font WQY, con istruzioni passo passo usando zypper."
date: 2009-03-15 00:10:14 -0400
permalink: /it/index.php/2009/03/15/faster-japanese-rendering-in-firefox/
lang: it
categories:
  - linux
tags:
  - opensuse
  - firefox
  - fonts
---

Anni fa avevo scoperto che il rendering dei contenuti in giapponese in Firefox era DAVVERO lento, ma mi ero semplicemente rassegnato a conviverci e poco dopo mi ero dimenticato di tutta la faccenda perché avevo smesso di accedere a contenuti in giapponese….

Oggi ho trovato di nuovo qualche contenuto interessante dopo aver letto alcuni post su kirainet.com, e all'improvviso mi sono irritato ancora una volta per questa lentezza di rendering. Dopo aver cercato un po', ho trovato [questo ](http://forums.opensuse.org/applications/405280-firefox-slow-chinese-japanese-symbols-solution.html)post che risolve il problema. Non sono molto sicuro del perché questi font aiutino a renderizzare le pagine più velocemente dei font di default, non dovrebbero essere inclusi nella distro?

Ecco la procedura per installarli su openSUSE (testata con 11.0@x86\_64):

Trova un repository adatto su http://software.opensuse.org/search

Aggiungi il repository al tuo sistema (non DEVI farlo, ma così potrai ricevere gli aggiornamenti in seguito):

> zypper addrepo http://download.opensuse.org/repositories/home:/swyear/openSUSE\_11.0 “Japanese Fonts”

Installa i pacchetti:

> zypper install ttf-wqy-zenhei wqy-bitmapfont

Ti chiederà se fidarti della chiave e poi se importarla, rispondi semplicemente “YES” a entrambe le domande. Dovrai riavviare Firefox per usare questi nuovi font..

Pagine per testare il rendering:

> <https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC>
> 
> <http://news.google.com/news?ned=cn>
> 
> <http://news.google.com/news?ned=jp>
> 
> <http://kayanomori.net/memo/index.php?iFolder%20Simple%20Server>
