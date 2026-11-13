---
title: InstantClient RPMs
description: "Condivido un file spec RPM migliorato di Oracle InstantClient basato sul lavoro di Remi Collet, con ORACLE_HOME, supporto a tnsnames.ora e altri miglioramenti, per openSUSE Build Service."
date: 2011-01-03 00:59:38 -0300
permalink: /it/index.php/2011/01/03/instantclient-rpms/
lang: it
categories:
  - linux
tags:
  - oracle
  - rpm
  - opensuse
---

Qualche anno fa mi sono imbattuto nel file SPEC di Oracle InstantClient preparato da Remi Collet ed è stato un bel colpo, perché gli RPM originali fatti da Oracle non servono per compilare altri pacchetti che dipendono da essi.

<!--more-->

Ho creato una serie di pacchetti per un progetto partendo dal file originale di Remi. Qualche giorno dopo li ho migliorati per rendere l'uso del pacchetto davvero fluido per gli utenti finali (variabile d'ambiente ORACLE\_HOME, PATH, ecc). Ho aggiunto anche altri ritocchi, come uno script per aiutare a compilare Perl-DBD-Oracle (non fatto da me), ero davvero contento dei risultati. Qui è dove è andato tutto a rotoli. Su openSUSE Build Service c'era una politica che ammetteva solo software con codice sorgente e i responsabili hanno semplicemente cancellato il pacchetto dal mio progetto di repository e ho perso tutto il lavoro fatto.

Avevo la ricreazione del pacchetto nella mia lista di cose da fare, ma non ho mai avuto tempo… Qualche giorno fa, di fronte a un nuovo progetto con Oracle, sono andato sul blog di Remi a cercare il file SPEC originale e per fortuna circa un mese prima [lo aveva modificato](http://blog.famillecollet.com/post/2010/11/12/RPM-Oracle-Instant-Client-11.2-en) per supportare l'ultima versione del client (a oggi, 10.2.0.2).

Ci ho fatto qualche modifica (a loro, dato che erano divisi in due) e condivido qui il risultato. Come tocco finale aggiungerò tnsping ai pacchetti, che è incluso solo nell'installazione “thick” di Oracle, e forse unirò il sotto-pacchetto “precomp\*” a “devel”.

**File:**

[oracle-instantclient.spec](http://track.itsolutions.com.py/pub/oracle/oracle-instantclient.spec)  
[oracle-instantclient-11.2.0.2.0-37.1.nosrc.rpm](http://track.itsolutions.com.py/pub/oracle/oracle-instantclient.spec)

**Le mie modifiche ai file SPEC di Remi:**

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

**Rif:**

 [Richiesta per ammettere OIC nel Build Service](https://features.opensuse.org/308967)
