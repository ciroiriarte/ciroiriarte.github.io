---
title: "Redefinindo o OTP do Guacamole para um usuário"
description: "Como redefinir o cadastro TOTP de um usuário do Guacamole com backend FreeIPA (LDAP) e MySQL."
date: 2021-11-02 10:19:37 -0300
permalink: /pt/index.php/2021/11/02/resetting-guacamole-otp-for-an-user/
lang: pt
categories:
  - security
tags:
  - guacamole
  - mfa
---

Implementei o Guacamole para acesso remoto; por enquanto ele usa o módulo OTP embutido. No futuro talvez eu migre para LemonLDAP ou Keycloak para 2FA, mas por ora a solução é boa o bastante e funciona sem configuração depois de instalar o módulo 🙂

{% include image.html url="/assets/img/2021-11-02-guacamole-totp-enroll.png" description="Tela de cadastro multifator (TOTP) do Guacamole" width=625 height=706 %}

Meu setup em particular puxa os usuários do FreeIPA via LDAP, mas também usa o MySQL como complemento para cuidar das definições de conexões e de coisas como as informações do plugin de OTP.

De vez em quando, um usuário precisa recadastrar um dispositivo porque o original foi roubado ou resetado. Fiz uma busca rápida, mas não encontrei uma opção limpa/fácil para redefinir pela GUI na versão 1.3.0.


Como solução rápida (não quero ter que repensar isso toda vez que um usuário precisar), criei um script simples que faz o trabalho por mim.

Tudo que você precisa fazer é configurar a conexão com o banco MySQL em ~/.my.cnf e pegar o script aqui:

<https://github.com/ciroiriarte/sysadmin-scripts/blob/main/guacamole-reset-user-otp.sh>

Na maioria das máquinas Linux, você pode copiá-lo para ~/bin/.

{% highlight shell %}
mkdir ~/bin
cd ~/bin
wget https://raw.githubusercontent.com/ciroiriarte/sysadmin-scripts/main/guacamole-reset-user-otp.sh
chmod +x guacamole-reset-user-otp.sh
{% endhighlight %}

Se você executar o script sem opções, ele vai mostrar a sintaxe

{% highlight shell %}
guacamole-reset-user-otp.sh
Usage: /home/me/bin/guacamole-reset-user-otp.sh <username>
      /home/me/bin/guacamole-reset-user-otp.sh ciro.iriarte
{% endhighlight %}

E a execução deve ser tão simples quanto:

{% highlight shell %}
guacamole-reset-user-otp.sh the.user
{% endhighlight %}
