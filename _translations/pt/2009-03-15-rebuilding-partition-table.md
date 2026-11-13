---
title: Reconstruindo a tabela de partições
description: "Como recuperar uma tabela de partições sobrescrita por uma instalação de Linux abortada, usando a ferramenta TestDisk para restaurar o layout original das partições."
date: 2009-03-15 20:00:26 -0400
permalink: /pt/index.php/2009/03/15/rebuilding-partition-table/
lang: pt
categories:
  - linux
  - storage-backup
tags:
  - testdisk
  - partitioning
  - recovery
---

Bom, um ex-colega de escola me trouxe hoje o notebook dele e disse que de repente parou de funcionar (sei...).

Iniciei um disco de resgate Linux e, depois de inspecionar o disco rígido, vi que ele tinha 3 partições:

> Disco /dev/sdb: 160.0 GB, 160041885696 bytes  
> 255 heads, 63 sectors/track, 19457 cylinders  
> Units = cilindros of 16065 \* 512 = 8225280 bytes  
> Disk identifier: 0xac23bbdb
> 
> Disposit. Inicio Comienzo Fin Bloques Id Sistema  
> /dev/sdb1 1 18748 150593278+ 83 Linux  
> /dev/sdb2 18749 19457 5695042+ 5 Extendida  
> /dev/sdb5 18749 19457 5695011 82 Linux swap / Solaris

Hmm, partição Linux... Mas como pode ser?, ele só usa Windows… Obviamente alguém fez uma baita bagunça…

Tentei montar a primeira partição, mas aparentemente ela não tinha um sistema de arquivos válido. Tirei o disco, montei num case externo SATA <-> USB e conectei no meu notebook.

Primeiro tentei ver o que havia em cada partição: o utilitário “file” só dizia “data”, mas o “strings” na partição mostrava que os dados do WinXP ainda estavam no disco. Aparentemente alguém iniciou o notebook com um instalador Linux e abortou o processo de instalação, não sem antes estragar a tabela de partições.

Primeiro pensamento: “bom, vou apagar as partições atuais, criar uma única NTFS no disco todo e os dados vão aparecer sozinhos!”. Criada a partição, tentei acessar os dados e fracassei miseravelmente….

Então, obviamente, por ser um notebook, provavelmente ele tem aquelas partições de utilitários tão comuns hoje em dia. Como posso adivinhar a tabela de partições a partir dos bits do disco?!

Depois de pesquisar um tempo, descobri o [TestDisk](http://www.cgsecurity.org/wiki/TestDisk). Baixei, instalei, rodei no disco e alguns minutos depois ele encontrou a tabela de partições original!!!

Tive sorte, mas seu resultado pode variar…
