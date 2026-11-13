---
title: Ricostruire la tabella delle partizioni
description: "Come recuperare una tabella delle partizioni sovrascritta da un'installazione di Linux interrotta, usando lo strumento TestDisk per ripristinare il layout originale delle partizioni."
date: 2009-03-15 20:00:26 -0400
permalink: /it/index.php/2009/03/15/rebuilding-partition-table/
lang: it
categories:
  - linux
  - storage-backup
tags:
  - testdisk
  - partitioning
  - recovery
---

Allora, un ex compagno di scuola mi ha portato oggi il suo portatile dicendomi che di colpo ha smesso di funzionare (come no).

Ho avviato un disco di rescue Linux e, dopo aver ispezionato l'hard disk, ho trovato 3 partizioni:

{% highlight text %}
Disco /dev/sdb: 160.0 GB, 160041885696 bytes
255 heads, 63 sectors/track, 19457 cylinders
Units = cilindros of 16065 * 512 = 8225280 bytes
Disk identifier: 0xac23bbdb

Disposit. Inicio Comienzo Fin Bloques Id Sistema
/dev/sdb1 1 18748 150593278+ 83 Linux
/dev/sdb2 18749 19457 5695042+ 5 Extendida
/dev/sdb5 18749 19457 5695011 82 Linux swap / Solaris
{% endhighlight %}

Mmm, una partizione Linux... Ma com'è possibile?, è uno che usa solo Windows… Ovviamente qualcuno ha combinato un bel disastro…

Ho provato a montare la prima partizione, ma a quanto pare non aveva un filesystem valido. Ho tolto il disco, l'ho montato in un box esterno SATA <-> USB e l'ho collegato al mio portatile.

Per prima cosa ho provato a vedere cosa c'era su ogni partizione: l'utility “file” diceva solo “data”, ma “strings” sulla partizione mostrava che i dati di WinXP erano ancora sul disco. A quanto pare qualcuno ha avviato il portatile con un installer Linux e ha interrotto l'installazione, non prima di aver rovinato la tabella delle partizioni.

Primo pensiero: “bene, cancello le partizioni attuali, creo una singola NTFS su tutto il disco e i dati ricompariranno da soli!”. Creata la partizione, ho provato ad accedere ai dati e ho fallito miseramente….

Quindi, ovviamente, essendo un portatile probabilmente ha quelle partizioni di utilità che si trovano così spesso al giorno d'oggi. Come faccio a indovinare la tabella delle partizioni dai bit sul disco?!

Dopo aver cercato un po' ho scoperto [TestDisk](http://www.cgsecurity.org/wiki/TestDisk). L'ho scaricato, installato e lanciato sul disco e qualche minuto dopo ha trovato la tabella delle partizioni originale!!!

Sono stato fortunato, ma il chilometraggio può variare…
