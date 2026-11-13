---
title: Integrando o sistema operacional dos appliances do Apstra ao FreeIPA
description: "Instalação do cliente IPA em appliances baseados em Ubuntu para o Apstra 4.2.0"
date: 2023-10-07 00:00:00 -0300
permalink: /pt/homelab/sdn/2023/10/07/Integrating-Apstra-Appliances-OS-to-FreeIPA.html
lang: pt
categories:
  - networking
  - security
tags:
  - apstra
  - freeipa
  - ubuntu
---

## Intenção {#intent}

Se você trabalha em qualquer ambiente sensato com servidores Unix/Linux, com certeza tem implantado algum esquema centralizado de autenticação/autorização para o acesso ao sistema operacional. Hoje em dia isso é LDAP ou LDAP+Kerberos.

No meu caso, uso o FreeIPA para o ecossistema Linux.

## Appliances do Apstra {#apstra-appliances}

O Apstra é uma ferramenta de gerenciamento de configuração e monitoramento para redes de Datacenter. Não acho que seja um controlador SDN propriamente dito (pelo menos no conceito original do termo), porque ele se parece mais com ferramentas de gerenciamento de configuração como Puppet ou Ansible. Mesmo assim, faz parte do ecossistema de ferramentas SDN. 

Os appliances do Apstra são baseados em Ubuntu LTS e, felizmente, temos o FreeIPA oficial disponível. Muito provavelmente seu representante da Juniper vai dizer que instalar pacotes oficiais do Ubuntu não é suportado.

Já implementei isso com o Apstra 4.1.0, 4.1.1 e 4.1.2, mas a 4.2.0 precisa de um ajuste desta vez. Funciona e, na minha experiência, não interfere na funcionalidade; mesmo assim, recomenda-se testar em um ambiente de laboratório antes de ir para produção. Prossiga por sua conta e risco.

## Premissas {#assumptions}
1. Você tem os appliances do ecossistema Apstra (AOS, ZTP, workers) corretamente implantados
2. O fuso horário correto já está configurado
3. A configuração do cliente NTP está pronta
4. A configuração do cliente DNS está pronta

## Configuração do lado do servidor FreeIPA {#freeipa-server-side-configuration}

Garanta que o cliente tenha uma entrada DNS.

{% highlight shell %}
ipa dnsrecord-add <your domain> <client shortname> --a-rec <IPv4 for the client>
ipa dnsrecord-add <your domain> <client shortname> --aaaa-rec <IPv6 for the client>
{% endhighlight %}

## Bibliotecas Python e AOS {#python-libraries-and-aos}

Bom, este é um caso especial do Apstra 4.2.0. Há módulos Python instalados com o *pip* fora do que os pacotes baseados em apt fornecem; aparentemente eles são necessários para a plataforma Apstra, mas quebram outras ferramentas como o ipa-client-install no appliance AOS (não acontece com o appliance ZTP).

Appliance ZTP:

{% highlight shell %}
admin@apstra-ztp-03:~$ pip show cryptography
Name: cryptography
Version: 3.4.8
Summary: cryptography is a package which provides cryptographic recipes and primitives to Python developers.
Home-page: https://github.com/pyca/cryptography
Author: The Python Cryptographic Authority and individual contributors
Author-email: cryptography-dev@python.org
License: BSD or Apache License, Version 2.0
Location: /usr/lib/python3/dist-packages
Requires: 
Required-by: ansible-core, paramiko
{% endhighlight %}

Appliance AOS:

{% highlight shell %}
admin@apstra-os-03:~$ pip show cryptography
Name: cryptography
Version: 38.0.0
Summary: cryptography is a package which provides cryptographic recipes and primitives to Python developers.
Home-page: https://github.com/pyca/cryptography
Author: The Python Cryptographic Authority and individual contributors
Author-email: cryptography-dev@python.org
License: BSD-3-Clause OR Apache-2.0
Location: /usr/local/lib/python3.10/dist-packages
Requires: cffi
Required-by: paramiko
{% endhighlight %}

Note que a versão do AOS é mais nova e que os módulos ficam em /usr/local/lib em vez de /usr/lib.

Uma aplicação baseada em contêineres como o Apstra deveria ter dentro do contêiner tudo o que precisa e não deveria exigir nem mexer nas bibliotecas do host.

### Como isso afeta o ipa-client-install {#how-it-affects-ipa-client-install}
A ferramenta de configuração do IPA falha com este erro:

{% highlight shell %}
admin@apstra-os-03:~$ ipa-client-install 
Traceback (most recent call last):
  File "/usr/sbin/ipa-client-install", line 22, in <module>
    from ipaclient.install import ipa_client_install
  File "/usr/lib/python3/dist-packages/ipaclient/install/ipa_client_install.py", line 7, in <module>
    from ipaclient.install import client
  File "/usr/lib/python3/dist-packages/ipaclient/install/client.py", line 37, in <module>
    from ipalib import api, errors, x509
  File "/usr/lib/python3/dist-packages/ipalib/__init__.py", line 921, in <module>
    from ipalib.frontend import Command, LocalOrRemote, Updater
  File "/usr/lib/python3/dist-packages/ipalib/frontend.py", line 31, in <module>
    from ipalib.parameters import create_param, Param, Str, Flag
  File "/usr/lib/python3/dist-packages/ipalib/parameters.py", line 125, in <module>
    from ipalib.x509 import (
  File "/usr/lib/python3/dist-packages/ipalib/x509.py", line 91, in <module>
    @crypto_utils.register_interface(crypto_x509.Certificate)
**AttributeError: module 'cryptography.utils' has no attribute 'register_interface'. Did you mean: 'verify_interface'?**
{% endhighlight %}

Parece que o FreeIPA usava uma função que não era pensada para ser usada fora da implementação do capy/cryptography. A equipe deste último projeto [decidiu depreciar a função](https://github.com/pyca/cryptography/pull/7234) na 38.0; instalar a biblioteca mais nova fora do que a distro fornece quebra o cliente FreeIPA fornecido por ela.

O projeto FreeIPA [está se adequando à mudança upstream](https://github.com/freeipa/freeipa/pull/6455), e isso deve estar incluído na 4.11+

### A forma correta de lidar com isso {#the-correct-way-of-dealing-with-this}

#### Regra de ouro {#golden-rule}

Você não mexe nas bibliotecas fornecidas pela distribuição Linux. Nunca.

#### Ferramentas à disposição de quem empacota software {#tools-at-hand-for-software-packagers}

Contêineres são uma solução atual de entrega de software que poderia resolver isso. Aliás, a Juniper usa contêineres docker. Estou meio perdido sobre por que isso é um problema hoje com o appliance AOS do Apstra, mas empacotar todas as dependências dentro dos contêineres deveria ser o caminho correto.


### Workaround para clientes da Juniper {#workaround-for-juniper-customers}

Tudo o que podemos fazer até a Juniper empacotar o Apstra direito como um conjunto de imagens de contêiner é escolher o caminho menos feio. Neste caso, reconstruí um pacote do Ubuntu 23.04, que é baseado no código-fonte do FreeIPA 4.9.11, para o Ubuntu 22.04 (no qual o appliance do Apstra é baseado).

Vamos adicionar o repositório só para o AOS; o appliance ZTP pode usar os pacotes padrão. 

{% highlight shell %}
sudo sh -c 'echo "deb http://download.opensuse.org/repositories/home:/ciriarte:/apstra-4.2.0-fix/xUbuntu_22.04/ /" | sudo tee /etc/apt/sources.list.d/home:ciriarte:apstra-4.2.0-fix.list'
sudo sh -c 'curl -fsSL https://download.opensuse.org/repositories/home:ciriarte:apstra-4.2.0-fix/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg > /dev/null'
sudo chmod a+r /etc/apt/trusted.gpg.d/home_ciriarte_apstra-4.2.0-fix.gpg
sudo chmod a+r /etc/apt/sources.list.d/home:ciriarte:apstra-4.2.0-fix.list
sudo apt update
{% endhighlight %}

Depois de adicionar o repositório, é só seguir o procedimento abaixo.


## Configuração dos clientes {#clients-configuration}

Para cada cliente em questão, appliance ZTP, appliance AOS principal ou workers, você precisará executar estes passos.

### Validação de DNS {#dns-validation}
O DNS é crítico neste ambiente, garanta que os clientes realmente consigam localizar seus servidores IP.

1. Teste se o cliente está realmente configurado
{% highlight shell %}
dig _ldap._tcp.<your domain> SRV
{% endhighlight %}

{:start="2"}
1. Teste se todos os servidores esperados estão realmente respondendo. Há cenários esquisitos em que alguns servidores respondem e outros não.
{% highlight shell %}
dig @<recursor/resolver 1 IP>  _ldap._tcp.<your domain> SRV
dig @<recursor/resolver 2 IP>  _ldap._tcp.<your domain> SRV
{% endhighlight %}

### Instalação e configuração do cliente {#client-installation--configuration}

O cliente FreeIPA faz parte dos repositórios padrão, é só instalá-lo com o gerenciador de pacotes:

{% highlight shell %}
sudo apt install -y freeipa-client
sudo ipa-client-install --mkhomedir --enable-dns-updates \
 --domain=<IPA domain in lowercase> --realm=<IPA domain in uppercase>
{% endhighlight %}

### Limitar o acesso SSH {#limit-ssh-access}

É uma boa prática limitar o acesso via SSH aos usuários que realmente precisam de acesso ao nó. 

Pensando bem, isso deveria ser feito com o módulo HBAC do FreeIPA + pam_sss.so. Não lembro por que neste ambiente estamos fixando o grupo no nível do sshd, vou manter por consistência. **A revisar**

{% highlight shell %}
sudo sh -c 'echo "AllowGroups ssh-allow gapstra-administrator" >> /etc/ssh/sshd_config'
sudo systemctl restart sshd
{% endhighlight %}
