---
title: Cambio dell'ora in Paraguay 2010
description: "Guida al cambio delle regole DST in Paraguay nel 2010 e a come aggiornare il database dei fusi orari Olson su Linux, Solaris, Tru64 e HP-UX."
date: 2010-03-02 17:17:04 -0300
permalink: /it/index.php/2010/03/02/cambio-de-hora-en-paraguay-2010/
lang: it
categories:
  - linux
tags:
  - timezone
  - paraguay
---

Il Governo paraguaiano ha deciso di modificare la data di entrata in vigore dell'ora invernale in tutta la repubblica. Con il decreto precedente, in vigore dal 2004, l'ora andava spostata indietro di 60 minuti la seconda domenica di marzo (14/mar quest'anno) e di nuovo avanti di 60 minuti la terza domenica di ottobre (17/ott quest'anno).

Con il nuovo decreto cambia in: spostare l'ora indietro di 60 minuti la seconda domenica di aprile (11/apr quest'anno) e di nuovo avanti di 60 minuti la prima domenica di ottobre (3/ott quest'anno).

<!--more-->

Riferimenti:

http://www.abc.com.py/abc/nota/78024-En-abril-se-atrasa-la-hora/

http://www.presidencia.gov.py/v1/wp-content/uploads/2010/02/decreto3958.pdf

Bene, cosa comporta questo per chi lavora con sistemi unix?. Una macchina unix mantiene l'ora interna del sistema in UTC e regola l'ora locale in base al fuso orario. Per questo si usa il database Olson, che registra i diversi fusi orari e le regole per il passaggio all'ora legale (daylight saving transition o DST), dove previsto.

L'ultima versione di questo database si può scaricare da ftp://elsie.nci.nih.gov/pub/tzdata*.tar.gz. Se non abbiamo la fortuna che questa nuova legislazione sia già recepita, dobbiamo fare le modifiche a mano.

Nel nostro caso, dobbiamo limitare l'ultima regola (quella che inizia nel 2004) al 2009 e aggiungere una nuova regola in vigore dal 2010 fino alla “fine dei tempi”. Probabilmente non sarà l'ultima regola da aggiungere, ma finché non ce ne sarà una nuova, dovrebbe restare in vigore a tempo indeterminato.

Così sarebbe senza i commenti:

```
# Paraguay
Rule    Para    1975    1988    -    Oct     1    0:00    1:00    S
Rule    Para    1975    1978    -    Mar     1    0:00    0    -
Rule    Para    1979    1991    -    Apr     1    0:00    0    -
Rule    Para    1989    only    -    Oct    22    0:00    1:00    S
Rule    Para    1990    only    -    Oct     1    0:00    1:00    S
Rule    Para    1991    only    -    Oct     6    0:00    1:00    S
Rule    Para    1992    only    -    Mar     1    0:00    0    -
Rule    Para    1992    only    -    Oct     5    0:00    1:00    S
Rule    Para    1993    only    -    Mar    31    0:00    0    -
Rule    Para    1993    1995    -    Oct     1    0:00    1:00    S
Rule    Para    1994    1995    -    Feb    lastSun    0:00    0    -
Rule    Para    1996    only    -    Mar     1    0:00    0    -
Rule    Para    1996    2001    -    Oct    Sun>=1    0:00    1:00    S
Rule    Para    1997    only    -    Feb    lastSun    0:00    0    -
Rule    Para    1998    2001    -    Mar    Sun>=1    0:00    0    -
Rule    Para    2002    2004    -    Apr    Sun>=1    0:00    0    -
Rule    Para    2002    2003    -    Sep    Sun>=1    0:00    1:00    S
Rule    Para    2004    2009    -    Oct    Sun>=15    0:00    1:00    S
Rule    Para    2005    2009    -    Mar    Sun>=8    0:00    0    -
Rule    Para    2010    max    -       Oct     Sun>=1  0:00    1:00    S
Rule    Para    2010    max    -       Apr     Sun>=8  0:00    0       -

# Zone    NAME        GMTOFF    RULES    FORMAT    [UNTIL]
Zone America/Asuncion    -3:50:40 -    LMT    1890
            -3:50:40 -    AMT    1931 Oct 10 # Asuncion Mean Time
            -4:00    -    PYT    1972 Oct # Paraguay Time
            -3:00    -    PYT    1974 Apr
            -4:00    Para    PY%sT
```

Salviamo queste righe in un file di testo semplice da compilare in seguito: **/root/america_asuncion.zone**

Per i seguenti unix e unix-like, descrivo la procedura per verificare la data del cambio d'ora e per correggerla.

## Linux {#linux}

- Stato iniziale

**#** zdump -v America/Asuncion |grep 2010

- Creare un file con il contenuto elencato sopra

**#** vi /root/america_asuncion.zone

- Compilare il fuso orario

**#** zic /root/america_asuncion.zone

- Verificare le modifiche, l'output dovrebbe differire da quello originale

**#** zdump -v America/Asuncion |grep 2010

- Copiamo la zona in /etc/localtime. Una volta si usava un link simbolico, ma a volte dava problemi di “file non trovato” quando /usr era un filesystem separato.

**#** cp /usr/share/zoneinfo/America/Asuncion /etc/localtime

## Solaris {#solaris}

- Stato iniziale

**#** zdump -v America/Asuncion|grep 2010

- Creare america_asuncion.zone

**#** vi /root/america_asuncion.zone

- Compilare le regole

**#** zic /root/america_asuncion.zone

- Verificare le modifiche

**#** zdump -v America/Asuncion|grep 2010

- Assicurarsi che il sistema usi la zona corretta:

**#** grep TZ= /etc/TIMEZONE  
TZ=America/Asuncion

## Tru64 {#tru64}

- Verificare lo stato iniziale

**#** zdump -v America/Asuncion|grep 2010

- Creare il file con le regole

**#** vi /root/america_asuncion.zone

- Compilare il file delle regole

**#** zic /root/america_asuncion.zone

- Verificare le modifiche

**#** zdump -v America/Asuncion|grep 2010

## HPUX {#hpux}

Bene, non usa il database Olson e mantiene le proprie regole per il DST.

- Controllare lo stato attuale, per questo passaggio serve lo script dst.pl, che si può scaricare dai forum di HP

Rif:

http://forums11.itrc.hp.com/service/forums/questionanswer.do?threadId=1089676  
http://forums11.itrc.hp.com/service/forums/questionanswer.do?admit=109447626+1267560461229+28353475&threadId=1007176

**#** ./dst.pl

- Modifichiamo il file di sistema che contiene le regole

**#** vi /usr/lib/tztab

- Aggiungiamo alla fine del file:

```
# Horario normal es PYT con diferencia GMT-4, el horario de verano es PYST con diferencia GMT-3.
PYT4PYST
# Minuto - Hora - Dia - Mes - Año - Dia Semana.
0 23 8-14 4 2010-2038 6 PYT4
0 1  1-7 10 2010-2038 0 PYST3
```

- Definiamo il fuso orario

**#** vi /etc/TIMEZONE

```
TZ=PYT4PYST
export TZ
```

- Verifichiamo le modifiche

**#** ./dst.pl

## Osservazione. {#observación}

Alcuni processi che girano in continuazione possono richiedere un riavvio dopo questa modifica. Uno di questi sarebbe crond.

E questo è tutto, ora i nostri sistemi tengono conto della nuova regola in vigore da quest'anno.
