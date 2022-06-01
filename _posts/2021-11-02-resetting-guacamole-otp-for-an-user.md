---
title: Resetting Guacamole OTP for an user
id: 329
date: '2021-11-02T10:19:37-03:00'
author: ciroiriarte
layout: post
guid: https://iriarte.it/?p=329
permalink: "/index.php/2021/11/02/resetting-guacamole-otp-for-an-user/"
categories:
- Uncategorized
tags:
- Guacamole
---

I’ve implemented Guacamole for remote access, for the time being it uses the builtin OTP module. In the future I might migrate to LemonLDAP or Keycloak for 2FA, for the time being the solution if good enough and works with zero configuration after module installation 🙂

![Multifactor Enrollment](https://iriarte.it/wp-content/uploads/2022/01/totp-enroll.png)

My particular setup is pulling users from FreeIPA through LDAP, but also uses MySQL as a supplement to handle the connections definitions and things like the OTP plugin information.

From time to time, an user would need to re-enroll a device because the original device was stolen or reset. Did a quick search, but couldn’t find a clean/easy option to reset it from the GUI in version 1.3.0.


As a quick fix (don’t want to have to rethink this each time a user has this requirement), I created a simple script to do the job for me.

All you need to do is setup your mysql DB connection in ~/.my.cnf and get the script from here:

<https://github.com/ciroiriarte/sysadmin-scripts/blob/main/guacamole-reset-user-otp.sh>

In most Linux machines, you can copy it to ~/bin/.

{% highlight shell %}
mkdir ~/bin
cd ~/bin
wget https://raw.githubusercontent.com/ciroiriarte/sysadmin-scripts/main/guacamole-reset-user-otp.sh
chmod +x guacamole-reset-user-otp.sh
{% endhighlight %}

If you run the script with no options, it will show you the syntax

{% highlight shell %}
guacamole-reset-user-otp.sh
Usage: /home/me/bin/guacamole-reset-user-otp.sh <username>
      /home/me/bin/guacamole-reset-user-otp.sh ciro.iriarte
{% endhighlight %}

And the execution should be as simple as:

{% highlight shell %}
guacamole-reset-user-otp.sh the.user
{% endhighlight %}
