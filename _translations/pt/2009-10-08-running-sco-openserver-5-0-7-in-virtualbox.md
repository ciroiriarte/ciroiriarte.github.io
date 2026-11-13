---
title: "Executando o SCO Openserver 5.0.7 no VirtualBox"
description: "Guia técnico para virtualizar o SCO OpenServer 5.0.7 no VirtualBox, com a configuração da VM, o procedimento de instalação, a configuração de rede e uma solução para o Guru Meditation."
date: 2009-10-08 16:38:22 -0400
permalink: /pt/index.php/2009/10/08/running-sco-openserver-5-0-7-in-virtualbox/
lang: pt
categories:
  - virtualization
tags:
  - virtualbox
  - sco
---

**Atualização:** *A partir do VirtualBox 3.0.10, o Openserver 5.0.7 não deve exigir gambiarras para instalar, só falta o suporte a SCSI… (confira os bug reports listados).*

Um cliente precisava substituir um antigo servidor SCO<!--more--> que rodava Foxplus; como é improvável que o Openserver 5 funcione em hardware novo, o único caminho disponível neste caso era virtualizar o servidor Openserver. Até hoje o iBCS ou ABI ou seja lá qual for a última encarnação não funcionou para nós.

Usamos SLES10SP2@x86\_64 como host, mas qualquer host que rode VirtualBox deve servir. A instalação original foi feita na 3.0.4, mas estes passos foram testados na 3.0.8 para este artigo. A única funcionalidade que falta é a GUI.

**Configuração da VM**

*General*

- Operating System: Other
- Version: Other

*System*

- Base Memory: 512M
- Enable ACPI
- Processor: 1
- Enable VT-x/AMD-V
- Enable Nested Paging (mostrou melhora nos testes de criação de arquivos)

*Hard Disks*

- IDE Controller: 1 disco (6GB, dinâmico). Nenhum dos drivers SCSI oficiais detecta os adaptadores SCSI virtualizados do VirtualBox

*CD/DVD Drive*

- Image mounted: OpenServer-5.0.7Hw-10Jun05\_1800.iso

*Network*:

- Intel PRO/1000 MT Desktop

**Procedimento de instalação** (vou listar apenas as mudanças relevantes em cada passo)

- *Preparing your disk and choosing software* -> *Optional Software*: Em "Graphical Environment" devemos desmarcar "X Server and Graphics Drivers", pois o Video Configuration Manager causa "Guru Meditation".

- *Configuring optional software* -> *Network card*: Adiada (não vai funcionar antes de instalar o MP5)

**Pós-instalação**

*Instalar o MP5*

- Monte o osr507suppcd5.iso. Execute "custom" e selecione "Software" -> "Install New" -> "From <your_vm_name>" -> "Media Device" = CD-ROM Drive 0

Selecione e instale**:**

- SCO Openserver Release 5.0.7 Maintenance Pack 5
- SCO Openserver Release 5.0.7 Graphics and NIC Drivers

Reinicie

*Configuração de rede*

- Execute scoadmin –&gt; Networks –&gt; Network Configuration Manager –&gt; Hardware –&gt; Add new LAN Adapter. Ele deve detectar a NIC Intel.

**Corrigindo o Guru Meditation ao desligar**

Os eventos de shutdown para reiniciar ou desligar também disparam “Guru Meditation”. Por enquanto encontrei uma solução para o desligamento, mas o reinício continua quebrado.

Edite /etc/conf/pack.d/uapm/space.c, procure a função "uapm_offstates" do tipo "ulong_t" e modifique os eventos 0 e 3 para dispararem "APMPWR_OFF".

Aqui está um patch:

```diff
--- space.c.orig 2009-10-08 16:38:00.000000000 -0400
+++ space.c 2009-10-08 16:38:00.000000000 -0400
@@ -76,10 +76,10 @@
 */

 ulong_t uapm_offstates[] = {
-  APMPWR_READY, /* 0 AD_HALT No auto reboot */
+  APMPWR_OFF, /* 0 AD_HALT No auto reboot */
   APMPWR_READY, /* 1 AD_BOOT Auto reboot */
   APMPWR_READY, /* 2 AD_IBOOT (same as AD_BOOT) */
-  APMPWR_SUSPEND, /* 3 AD_PWRDOWN Turn off power */
+  APMPWR_OFF, /* 3 AD_PWRDOWN Turn off power */
   APMPWR_STANDBY, /* 4 AD_PWRNAP Turn off if no A/C */
   APMPWR_SUSPEND, /* (anything else) (essentially AD_HALT) */
 };
```

Relinke o kernel e reinicie:

{% highlight shell %}
cd /etc/conf/cf.d
./link_unix
{% endhighlight %}

**Bug reports pendentes**:

- http://www.virtualbox.org/ticket/3953
- http://www.virtualbox.org/ticket/5096
- http://www.virtualbox.org/ticket/5164

É isso, espero que o pessoal da Sun consiga corrigir esses problemas em versões futuras…
