---
title: Mudança de horário no Paraguai 2010
description: "Guia sobre a mudança das regras de DST no Paraguai em 2010 e como atualizar o banco de dados de fusos horários Olson no Linux, Solaris, Tru64 e HP-UX."
date: 2010-03-02 17:17:04 -0300
permalink: /pt/index.php/2010/03/02/cambio-de-hora-en-paraguay-2010/
lang: pt
categories:
  - linux
tags:
  - timezone
  - paraguay
---

O Governo paraguaio resolveu modificar a data de entrada em vigor do horário de inverno em toda a república. Com o decreto anterior, vigente desde 2004, o relógio devia ser atrasado em 60 minutos no segundo domingo de março (14/mar este ano) e voltar a ser adiantado em 60 minutos no terceiro domingo de outubro (17/out este ano).

Com o novo decreto isso muda para atrasar o relógio em 60 minutos no segundo domingo de abril (11/abr este ano) e voltar a adiantá-lo em 60 minutos no primeiro domingo de outubro (3/out este ano).

<!--more-->

Referências:

http://www.abc.com.py/abc/nota/78024-En-abril-se-atrasa-la-hora/

http://www.presidencia.gov.py/v1/wp-content/uploads/2010/02/decreto3958.pdf

Bom, o que isso significa para quem trabalha com sistemas unix?. Uma máquina unix mantém a hora interna do sistema em UTC e ajusta a hora local conforme o fuso horário. Para isso se usa o banco de dados Olson, que registra os diferentes fusos horários e as regras para a mudança para o horário de verão (daylight saving transition ou DST), quando aplicável.

A versão mais recente deste banco de dados pode ser baixada de ftp://elsie.nci.nih.gov/pub/tzdata*.tar.gz. Se não tivermos a sorte de que essa nova legislação esteja refletida, precisamos fazer as mudanças à mão.

No nosso caso, devemos limitar a última regra (que começa em 2004) a 2009 e adicionar uma nova regra vigente de 2010 até o “fim dos tempos”. Provavelmente esta não será a última regra a adicionar, mas até que haja uma nova, ela deveria valer indefinidamente.

Assim ficaria sem os comentários:

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

Salvamos estas linhas em um arquivo de texto simples para depois serem compiladas: **/root/america_asuncion.zone**

Para os seguintes unix e unix-like, detalho o procedimento de verificação da data de mudança de horário e de correção.

## Linux {#linux}

- Estado inicial

**#** zdump -v America/Asuncion |grep 2010

- Criar um arquivo com o conteúdo listado acima

**#** vi /root/america_asuncion.zone

- Compilar o fuso horário

**#** zic /root/america_asuncion.zone

- Verificar as mudanças, a saída deve diferir da saída original

**#** zdump -v America/Asuncion |grep 2010

- Copiamos a zona para /etc/localtime. Antigamente se usava um link simbólico, mas às vezes dava problemas de “arquivo não encontrado” quando /usr era um sistema de arquivos separado.

**#** cp /usr/share/zoneinfo/America/Asuncion /etc/localtime

## Solaris {#solaris}

- Estado inicial

**#** zdump -v America/Asuncion|grep 2010

- Criar america_asuncion.zone

**#** vi /root/america_asuncion.zone

- Compilar as regras

**#** zic /root/america_asuncion.zone

- Verificar as mudanças

**#** zdump -v America/Asuncion|grep 2010

- Garantir que o sistema use a zona correta:

**#** grep TZ= /etc/TIMEZONE  
TZ=America/Asuncion

## Tru64 {#tru64}

- Verificar o estado inicial

**#** zdump -v America/Asuncion|grep 2010

- Criar o arquivo com as regras

**#** vi /root/america_asuncion.zone

- Compilar o arquivo de regras

**#** zic /root/america_asuncion.zone

- Verificar as mudanças

**#** zdump -v America/Asuncion|grep 2010

## HPUX {#hpux}

Bom, ele não usa o banco de dados Olson e mantém suas próprias regras de DST.

- Conferir o estado atual, para este passo precisamos do script dst.pl, que pode ser baixado dos fóruns da HP

Ref:

http://forums11.itrc.hp.com/service/forums/questionanswer.do?threadId=1089676  
http://forums11.itrc.hp.com/service/forums/questionanswer.do?admit=109447626+1267560461229+28353475&threadId=1007176

**#** ./dst.pl

- Editamos o arquivo de sistema que contém as regras

**#** vi /usr/lib/tztab

- Adicionamos ao final do arquivo:

```
# Horario normal es PYT con diferencia GMT-4, el horario de verano es PYST con diferencia GMT-3.
PYT4PYST
# Minuto - Hora - Dia - Mes - Año - Dia Semana.
0 23 8-14 4 2010-2038 6 PYT4
0 1  1-7 10 2010-2038 0 PYST3
```

- Definimos o fuso horário

**#** vi /etc/TIMEZONE

```
TZ=PYT4PYST
export TZ
```

- Conferimos as mudanças

**#** ./dst.pl

## Observação. {#observación}

Alguns processos que rodam perpetuamente podem precisar de uma reinicialização depois dessa mudança. Um deles seria o crond.

E é isso, agora nossos sistemas contemplam a nova regra vigente a partir deste ano.
