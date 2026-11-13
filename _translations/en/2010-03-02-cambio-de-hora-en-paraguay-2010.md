---
title: Daylight saving time change in Paraguay 2010
description: "A guide to Paraguay's 2010 DST rule change and how to update the Olson timezone database on Linux, Solaris, Tru64 and HP-UX."
date: 2010-03-02 17:17:04 -0300
permalink: /en/index.php/2010/03/02/cambio-de-hora-en-paraguay-2010/
lang: en
categories:
  - linux
tags:
  - timezone
  - paraguay
---

The Paraguayan Government decided to change the date on which winter time takes effect across the whole country. Under the previous decree, in force since 2004, the clock had to be set back 60 minutes on the second Sunday of March (14/Mar this year) and set forward again 60 minutes on the third Sunday of October (17/Oct this year).

Under the new decree this changes to setting the clock back 60 minutes on the second Sunday of April (11/Apr this year) and forward again 60 minutes on the first Sunday of October (3/Oct this year).

<!--more-->

References:

http://www.abc.com.py/abc/nota/78024-En-abril-se-atrasa-la-hora/

http://www.presidencia.gov.py/v1/wp-content/uploads/2010/02/decreto3958.pdf

Well, what does this mean for those of us who work with unix systems?. A unix machine keeps its internal system time in UTC, and adjusts the local time according to the timezone. For this it uses the Olson database, which records the different timezones and the rules for daylight saving transitions (DST) where applicable.

The latest version of this database can be downloaded from ftp://elsie.nci.nih.gov/pub/tzdata*.tar.gz. If we're not lucky enough to have this new legislation reflected in it, we have to make the changes by hand.

In our case, we have to limit the last rule (the one starting in 2004) to 2009 and add a new rule that applies from 2010 until “the end of time”. This probably won't be the last rule we'll have to add, but until there's a new one, it should stay in force indefinitely.

This is how it would look without the comments:

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

We save these lines in a plain text file to be compiled later: **/root/america_asuncion.zone**

For the following unix and unix-like systems, I detail the procedure to check the time change date and to fix it.

## Linux {#linux}

- Initial state

**#** zdump -v America/Asuncion |grep 2010

- Create a file with the content listed above

**#** vi /root/america_asuncion.zone

- Compile the timezone

**#** zic /root/america_asuncion.zone

- Verify the changes, the output should differ from the original output

**#** zdump -v America/Asuncion |grep 2010

- Copy the zone to /etc/localtime. A symbolic link used to be used, but it sometimes caused “file not found” problems when /usr was a separate filesystem.

**#** cp /usr/share/zoneinfo/America/Asuncion /etc/localtime

## Solaris {#solaris}

- Initial state

**#** zdump -v America/Asuncion|grep 2010

- Create america_asuncion.zone

**#** vi /root/america_asuncion.zone

- Compile the rules

**#** zic /root/america_asuncion.zone

- Verify the changes

**#** zdump -v America/Asuncion|grep 2010

- Make sure the system uses the correct zone:

**#** grep TZ= /etc/TIMEZONE  
TZ=America/Asuncion

## Tru64 {#tru64}

- Check the initial state

**#** zdump -v America/Asuncion|grep 2010

- Create the file with the rules

**#** vi /root/america_asuncion.zone

- Compile the rules file

**#** zic /root/america_asuncion.zone

- Verify the changes

**#** zdump -v America/Asuncion|grep 2010

## HPUX {#hpux}

Well, it doesn't use the Olson database, and keeps its own DST rules.

- Check the current state, for this step we need the dst.pl script, which can be downloaded from the HP forums

Ref:

http://forums11.itrc.hp.com/service/forums/questionanswer.do?threadId=1089676  
http://forums11.itrc.hp.com/service/forums/questionanswer.do?admit=109447626+1267560461229+28353475&threadId=1007176

**#** ./dst.pl

- Edit the system file that contains the rules

**#** vi /usr/lib/tztab

- Add at the end of the file:

```
# Horario normal es PYT con diferencia GMT-4, el horario de verano es PYST con diferencia GMT-3.
PYT4PYST
# Minuto - Hora - Dia - Mes - Año - Dia Semana.
0 23 8-14 4 2010-2038 6 PYT4
0 1  1-7 10 2010-2038 0 PYST3
```

- Define the timezone

**#** vi /etc/TIMEZONE

```
TZ=PYT4PYST
export TZ
```

- Check the changes

**#** ./dst.pl

## Note. {#observación}

Some processes that run perpetually may need a restart after this change. One of these would be crond.

And that's all, now our systems take into account the new rule in force from this year.
