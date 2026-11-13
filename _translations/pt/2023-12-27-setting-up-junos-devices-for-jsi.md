---
title: Configurando dispositivos JunOS para o Juniper Support Insights
description: Passo a passo da configuração dos NEs para permitir que o vLWC se conecte e extraia informações.
date: 2023-12-27 00:00:00 -0300
permalink: /pt/datacenter/networking/2023/12/27/setting-up-junos-devices-for-jsi.html
lang: pt
categories:
  - networking
tags:
  - juniper
  - junos
---

## Intro {#intro}

Voltando ao caminho "suportado", depois de implantar o vLWC você precisa preparar os dispositivos que serão monitorados. Não consegui encontrar um guia conciso para configurar corretamente os elementos de rede para o JSI, então estou compartilhando minhas anotações depois de um longo exercício de tentativa e erro.

<!--more-->

Depois de ler o [JSI FAQ](https://www.juniper.net/documentation/us/en/software/jsi/jsi-on-jsp-faqs/topics/concept/jsi-faq-list.html), minha interpretação é que vamos precisar do seguinte em cada elemento de rede:

1. NETCONF-SSH habilitado
2. SFTP habilitado
3. Uma conta de usuário de processo dedicada ao JSI/vLWC com permissões suficientes (princípio do menor privilégio)

Uma visão geral de como funciona a coleta de dados pode ser encontrada neste [flyer](https://www.juniper.net/content/dam/www/assets/flyers/us/en/juniper-support-insights-security-and-privacy-overview.pdf)


{% include image.html url="/assets/img/2023-12-27_datacollection_overview.png" description="Imagem 1 - Visão geral da coleta de dados" alt="Visão geral do fluxo" width=1102 height=553 %}

## Pré-requisitos {#pre-requirements}

### Par de chaves SSH {#ssh-key-pair}

Precisamos de um par de chaves SSH pública/privada para o usuário. Você pode criá-lo em qualquer máquina Linux. 

**Nota:** No meio do caminho descobri que o JunOS não aceita chaves DSA, só RSA.

{% highlight shell %}
ciro.iriarte@jhost01:~> ssh-keygen -t rsa -C "JSI process user" -f ~/.ssh/id_rsa-jsi
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): <-- make sure you input a passphrase
Enter same passphrase again: 
Your identification has been saved in /home/ciro.iriarte/.ssh/id_rsa-jsi
Your public key has been saved in /home/ciro.iriarte/.ssh/id_rsa-jsi.pub
The key fingerprint is:
SHA256:vMRG09Sd7BR1Q5P7B+9RakR2thSR3Md3bBOtYmm+VVc JSI process user
The key's randomart image is:
+---[RSA 3072]----+
|          .. o+&@|
|         o  . B*E|
|        o .  *.=O|
|       + .  = =o+|
|        S  + o =+|
|       o .  . +.+|
|        .    + .o|
|            .   .|
|                 |
+----[SHA256]-----+
{% endhighlight %}

Você vai usar:
- o conteúdo de *~/.ssh/id_rsa-jsi.pub* para configurar o acesso nos switches
- o conteúdo de *~/.ssh/id_rsa-jsi* + *a passphrase* serão usados no portal do JSI para definir as credenciais de acesso.

### Comandos que devem ser permitidos. {#actual-commands-that-should-be-permitted}

Do FAQ mencionado antes, temos que os comandos que o appliance vai executar são:

```
file list detail
show bgp summary
show chassis alarms
show chassis fpc
show chassis hardware extensive
show chassis routing-engine
show interfaces descriptions
show interfaces terse
show isis adjacency
show ospf neighbor
show rsvp neighbor
show system buffers
show system commit
show system core-dumps
show system license
show system uptime
show version
show vrrp detail
request support information
sftp
```

## Switches gerenciados pelo Apstra {#apstra-managed-switches}

### NETCONF {#netconf}
NETCONF já é um requisito do Apstra, então você já deve ter isso coberto. Para validar rapidamente, você pode verificar se a porta padrão está escutando pedidos de conexão:

{% highlight shell %}
ciro.iriarte@jhost01:~> nmap -p 830 ipf01-lf01.<TLD>
Starting Nmap 7.92 ( https://nmap.org ) at 2023-12-27 14:12 EST
Nmap scan report for ipf01-lf01.<TLD> (x.y.z.w)
Host is up (0.0012s latency).

PORT    STATE SERVICE
830/tcp open  netconf-ssh

Nmap done: 1 IP address (1 host up) scanned in 6.58 seconds
{% endhighlight %}

### SFTP {#sftp}
Não sei se SFTP é um requisito do Apstra, mas descobri que todos os switches do ambiente Apstra já tinham o subsistema SFTP habilitado. Se não for o seu caso, um configlet para habilitá-lo é tudo o que você precisa.

### Usuário de processo {#process-user}

Neste ambiente não temos TACACS+ (estamos em 2023, pessoal da Juniper, dá para termos LDAP de uma vez?). Para fins práticos, vamos usar configlets do Apstra para criar um usuário de processo a partir do Apstra.

#### Criação do configlet {#configlet-creation}

1. Acesse a página de criação de configlets.
{% include image.html url="/assets/img/2023-12-27_configlet00.png" description="Imagem 2 - Design --> Configlets" alt="Captura de tela do Apstra" width=259 height=613 %}
{% include image.html url="/assets/img/2023-12-27_configlet01.png" description="Imagem 3 - Botão Create configlet &quot;" alt="Captura de tela do Apstra" width=1352 height=262 %}

{:start="2"}
2. Preencha os dados básicos do configlet

{% include image.html url="/assets/img/2023-12-27_configlet02.png" description="Imagem 4 - Criação do configlet" alt="Captura de tela do Apstra" width=955 height=720 %}

{:start="3"}
3. Cole o conteúdo a seguir no corpo e clique em "Create"
```
system {
    login {
        class jsi-class {
            permissions view-configuration;
            allow-commands "(file list detail)|(show bgp summary)|(show chassis alarms)|(show chassis fpc)|(show chassis hardware extensive)|(show chassis routing-engine)|(show interfaces descriptions)|(show interfaces terse)|(show isis adjacency)|(show ospf neighbor)|(show rsvp neighbor)|(show system buffers)|(show system commit)|(show system core-dumps)|(show system license)|(show system uptime)|(show version)|(show vrrp detail)|(request support information)|(sftp)";
            deny-commands "(clear)|(file)|(file show)|(help)|(load)|(monitor)|(op)|(request)|(save)|(set)|(start)|(test)";
            deny-configuration all;
        }
        user svcjsi {
            full-name "JSI process user";
            uid 2007;
            class jsi-class;
            authentication {
                ssh-rsa "ssh-rsa your-key-super-long-string JSI process user";
            }
        }
    }
}
```

**Nota:** Garanta que o UID seja único no seu ambiente. Vi posts/notas/documentação aleatórios referenciando o UID 2000 (para outras implementações sem relação), e eu, super esperto, mudei para 2001 para evitar conflito com configurações que todo mundo poderia estar copiando e colando; acontece que quem implementou o Apstra teve a mesma ideia.

#### Importando o configlet para o blueprint {#importing-configlet-to-blueprint}

Para realmente aplicar o configlet criado aos seus elementos de rede, você deve:

1. Importar o configlet para o blueprint, atribuindo-o aos dispositivos de interesse. No meu caso, seriam todos os spines e leaf switches.

{% include image.html url="/assets/img/2023-12-27_import-configlet00.png" description="Imagem 5 - Acessar a seção de importação" alt="Captura de tela do Apstra" width=1455 height=437 %}

{% include image.html url="/assets/img/2023-12-27_import-configlet01.png" description="Imagem 6 - Selecionar o configlet e atribuí-lo aos dispositivos de interesse" alt="Captura de tela do Apstra" width=1020 height=777 %}

{:start="2"}
2. Fazer o commit da configuração para que seja enviada aos dispositivos.

{% include image.html url="/assets/img/2023-12-27_commit00.png" description="Imagem 7 - Solicitação para enviar as mudanças aos NEs" alt="Captura de tela do Apstra" width=1337 height=491 %}

{% include image.html url="/assets/img/2023-12-27_commit01.png" description="Imagem 8 - Preencher o changelog" alt="Captura de tela do Apstra" width=976 height=377 %}

## Switches standalone {#standalone-switches}

Esses switches não são gerenciados pelo Apstra nem por nenhum outro gerenciador, e também não há TACACS+ ou serviços semelhantes de autenticação ou RBAC (já mencionei que adoraria ter LDAP disponível para reutilizar os serviços de autenticação existentes?). Como são só 2, a configuração manual e local não deve ser um problema.

Conecte-se ao switch com um usuário admin, em modo edit.

### NETCONF {#netconf-1}

Habilitamos o serviço. O pessoal descolado da automação recomenda os últimos 3 comandos por interoperabilidade, mas como o vLWC é uma ferramenta fechada da Juniper para JunOS, ele pode esperar a configuração padrão, menos padronizada e não compatível. Algo para monitorar e validar depois de adicionar os switches ao JSI.

```
set system services netconf ssh
set system services netconf rfc-compliant
set system services netconf yang-compliant 
set system services netconf hello-message yang-module-capabilities advertise-standard-yang-modules
```

### SFTP {#sftp-1}

O subsistema SFTP precisa ser habilitado; parece estar desabilitado por padrão.

```
set system services ssh sftp-server
```

### Usuário de processo {#process-user-1}

1. Criamos a classe de usuário com o nível de acesso necessário
```
set system login class jsi-class permissions view-configuration
set system login class jsi-class allow-commands "(file list detail)|(show bgp summary)|(show chassis alarms)|(show chassis fpc)|(show chassis hardware extensive)|(show chassis routing-engine)|(show interfaces descriptions)|(show interfaces terse)|(show isis adjacency)|(show ospf neighbor)|(show rsvp neighbor)|(show system buffers)|(show system commit)|(show system core-dumps)|(show system license)|(show system uptime)|(show version)|(show vrrp detail)|(request support information)|(sftp)"
set system login class jsi-class deny-commands "(clear)|(file)|(file show)|(help)|(load)|(monitor)|(op)|(request)|(save)|(set)|(start)|(test)"
set system login class jsi-class deny-configuration all
```

2. Criamos o usuário, usando a classe criada anteriormente. Use a sua chave pública, não a minha!
```
set system login user svcjsi class jsi-class
set system login user svcjsi full-name "JSI process user"
set system login user svcjsi uid 2007
set system login user svcjsi authentication ssh-rsa "ssh-rsa your-key-super-long-string JSI process user"
```

### Commit final {#final-commit}

3. Fazer o commit da configuração (serviço e usuário)
```
commit
```

## Testando o NETCONF na mão {#testing-netconf-by-hand}

Antes de passar por todo o aparato do JSI, minha recomendação é rodar um teste local básico com o usuário que criamos.

Entre em uma máquina Linux com acesso aos switches e à chave privada do usuário que criamos, e tente conectar no switch usando NETCONF

{% highlight shell %}
# We start the ssh key agent
eval $(ssh-agent)

# We add the key to the agent, the command will prompt for the key passphrase
ssh-add ~/.ssh/id_rsa-jsi

# We try a connection on default port
MYSWITCH=host.tld
ssh svcjsi@$MYSWITCH -p 830 -s netconf
{% endhighlight %}

A resposta deve ser parecida com

{% highlight xml %}
<!-- No zombies were killed during the creation of this user interface -->
<!-- user svcjsi, class j-jsi-class -->
<nc:hello xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">
   <nc:capabilities>
    <nc:capability>urn:ietf:params:netconf:base:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:candidate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:confirmed-commit:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:validate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:netconf:capability:url:1.0?scheme=http,ftp,file</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:base:1.0?module=ietf-netconf&amp;revision=2011-06-01</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:candidate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:confirmed-commit:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:validate:1.0</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:netconf:capability:url:1.0?scheme=http,ftp,file</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:yang:ietf-inet-types?module=ietf-inet-types&amp;revision=2013-07-15</nc:capability>
    <nc:capability>urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring</nc:capability>
    <nc:capability>http://xml.juniper.net/netconf/junos/1.0</nc:capability>
    <nc:capability>http://xml.juniper.net/dmi/system/1.0</nc:capability>
  </nc:capabilities>
  <nc:session-id>65596</nc:session-id>
</nc:hello>
]]>]]>
{% endhighlight %}

## É só isso? {#is-that-it}

Bem, deve ser tudo para a configuração dos NEs. Agora você já deve conseguir entrar no portal do JSI e fazer o onboarding dos dispositivos (pessoal da Juniper, por favor adicionem suporte a FQDN no formulário além de endereços IP).

Divirta-se!

## Mais documentos de referência {#more-reference-documents}

Caso você ainda esteja lendo, estes são alguns documentos e notas que revisei no processo.

- [Establish an SSH Connection for a NETCONF Session](https://www.juniper.net/documentation/us/en/software/junos/netconf/topics/topic-map/netconf-ssh-connection.html)  
- [Managing Juniped devices with SSH and NETCONF](https://www.tinfoilcipher.co.uk/2021/07/29/ansible-and-juniper-junos-managing-devices-with-ssh-and-netconf/)
- [Example: Configuring User Permissions with Access Privileges for Operational Mode Commands](https://www.juniper.net/documentation/en_US/junos/topics/example/access-privileges-individual-operational-mode-commands-configuring.html)
- [Connect to the NETCONF Server Using SSH](https://www.juniper.net/documentation/us/en/software/junos/netconf/topics/task/netconf-session-connecting-to-server.html)
- [Technical note on using SSH keys with JunOS](https://supportportal.juniper.net/s/article/Junos-Generating-SSH-RSA-keys-locally-on-devices-running-Junos-OS)

## Erros conhecidos {#known-errors}

### JSI reportando credenciais erradas {#jsi-reporting-wrong-credentials}

Durante meus testes, descobri que o portal web do JSI não lida bem com atualização de credenciais. Você consegue salvar as mudanças, vê a nova informação no portal web, mas parece que ela não chega ao backend deles. Tive que excluir e recriar as credenciais no portal web para que funcionassem.

### NETCONF reportado como não configurado {#netconf-reported-as-not-configured}

Durante meus testes, consegui confirmar manualmente que o NETCONF estava configurado corretamente, mas o JSI continuava reportando:

```
The NETCONF subsystem is not enabled on the devices with the listed IP addresses. Please check and correct these entries
```

O time do JSI informou que havia um timer que não deixava o diálogo NETCONF terminar direito. Eles corrigiram do lado deles ampliando a configuração de timeout; não sei se é um parâmetro global da plataforma ou se você deve pedir isso para seus nós/sites/contas específicos.

Você pode referenciar o Juniper SR # 2023-1228-038580.
