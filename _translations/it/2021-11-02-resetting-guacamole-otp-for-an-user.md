---
title: "Reimpostare l'OTP di Guacamole per un utente"
description: "Come reimpostare l'iscrizione TOTP di un utente Guacamole con backend FreeIPA (LDAP) e MySQL."
date: 2021-11-02 10:19:37 -0300
permalink: /it/index.php/2021/11/02/resetting-guacamole-otp-for-an-user/
lang: it
categories:
  - security
tags:
  - guacamole
  - mfa
---

Ho implementato Guacamole per l'accesso remoto; per ora usa il modulo OTP integrato. In futuro potrei migrare a LemonLDAP o Keycloak per il 2FA, ma per ora la soluzione è abbastanza buona e funziona senza configurazione dopo l'installazione del modulo 🙂

{% include image.html url="/assets/img/2021-11-02-guacamole-totp-enroll.png" description="Schermata di iscrizione multifattore (TOTP) di Guacamole" width=625 height=706 %}

Il mio setup particolare preleva gli utenti da FreeIPA tramite LDAP, ma usa anche MySQL come supporto per gestire le definizioni delle connessioni e cose come le informazioni del plugin OTP.

Ogni tanto un utente deve registrare di nuovo un dispositivo perché quello originale è stato rubato o resettato. Ho fatto una ricerca veloce, ma non ho trovato un'opzione pulita/semplice per reimpostarlo dalla GUI nella versione 1.3.0.


Come soluzione rapida (non voglio dover ripensare tutto ogni volta che un utente ha questa esigenza), ho creato un semplice script che fa il lavoro al posto mio.

Tutto quello che devi fare è configurare la connessione al DB MySQL in ~/.my.cnf e prendere lo script da qui:

<https://github.com/ciroiriarte/sysadmin-scripts/blob/main/guacamole-reset-user-otp.sh>

Sulla maggior parte delle macchine Linux puoi copiarlo in ~/bin/.

{% highlight shell %}
mkdir ~/bin
cd ~/bin
wget https://raw.githubusercontent.com/ciroiriarte/sysadmin-scripts/main/guacamole-reset-user-otp.sh
chmod +x guacamole-reset-user-otp.sh
{% endhighlight %}

Se esegui lo script senza opzioni, ti mostrerà la sintassi

{% highlight shell %}
guacamole-reset-user-otp.sh
Usage: /home/me/bin/guacamole-reset-user-otp.sh <username>
      /home/me/bin/guacamole-reset-user-otp.sh ciro.iriarte
{% endhighlight %}

E l'esecuzione dovrebbe essere semplice come:

{% highlight shell %}
guacamole-reset-user-otp.sh the.user
{% endhighlight %}
