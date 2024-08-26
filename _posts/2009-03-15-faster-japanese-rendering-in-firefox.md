---
id: 28
title: 'Faster Japanese rendering in Firefox'
date: '2009-03-15T00:10:14-04:00'
author: Ciro Iriarte
excerpt: 'Need decent rendering time for japanese text in Firefox?, here''s the solution..'
layout: post
guid: 'http://cyruspy.wordpress.com/?p=28'
permalink: /index.php/2009/03/15/faster-japanese-rendering-in-firefox/
categories:
    - Japanese
    - Linux
    - openSUSE
tags:
    - firefox
    - 'slow rendering'
---

Years before I found that rendering japanese content in Firefox was REALLY slow, but just resigned to live with it and some time later forgot about the whole thing as I stopped accessing japanese content….

Today I found some interesting content again after reading some posts at kirainet.com, and suddenly was annoyed once more with this rendering slowness. After researching a little, I found [this ](http://forums.opensuse.org/applications/405280-firefox-slow-chinese-japanese-symbols-solution.html)post which solves the issue. I’m not pretty sure about why this fonts help to render the pages faster than the stock fonts, should they be included in the distro?

Here’s the procedure to install them in openSUSE (tested with 11.0@x86\_64):

Find a suitable repository using http://software.opensuse.org/search

Add the repository to your system (you don’t HAVE TO, but this way you can get updates later):

> zypper addrepo http://download.opensuse.org/repositories/home:/swyear/openSUSE\_11.0 “Japanese Fonts”

Install the packages:

> zypper install ttf-wqy-zenhei wqy-bitmapfont

It will ask if it should trust and later import the key, just answer “YES” to both questions. You’ll have to restart Firefox to use this new fonts..

Pages to test rendering:

> [<span class="wpGallery">http://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC</span>](http://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC)
> 
> <http://news.google.com/news?ned=cn>
> 
> <http://news.google.com/news?ned=jp>
> 
> <http://kayanomori.net/memo/index.php?iFolder%20Simple%20Server>