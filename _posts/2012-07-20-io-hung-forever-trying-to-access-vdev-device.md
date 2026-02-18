---
id: 282
title: 'I/O hung forever trying to access VDEV device'
date: '2012-07-20T11:01:53-04:00'
author: Ciro Iriarte
layout: post
guid: 'http://cyruspy.wordpress.com/?p=282'
permalink: /index.php/2012/07/20/io-hung-forever-trying-to-access-vdev-device/
description: 'How to fix multipath I/O hung processes when accessing Hitachi VSP VDEV snapshot devices by enabling fail_if_no_path in the multipath configuration.'
categories:
    - Linux
    - Storage
tags:
    - storage
    - multipath
    - linux
    - hitachi
---

Setting up snapshots with Hitachi VSP we saw that many kpart processes were waiting for I/O trying to access VDEV devices. That's because of the queue_if_no_path feature in multipath.

<!-- more -->

The thing is, that’s a good feature, if you have really small gaps of times without access to the storage (cluster transition, someone messing with fiber cables, etc) you want the I/O to be queued and resume once conection comes back to live.

On the other side, VDEVs appear failed if the snapshots are not active, so most of the time you don't want to queue the probes from udev (hundreds of proceses in less than a day in our case). To solve this you can enable the "fail_if_no_path" feature per LUN, here's an example:

{% highlight shell %}
multipath {wwid 350760e9016040b000001040a00002001alias snapdata02LUno_path_retry fail}
{% endhighlight %}

And don’t forget to restart multipath daemon…

If needed, you can release pending I/O processes (and return I/O error) with the following command:

{% highlight shell %}
dmsetup message snapdata02LU 0 "fail_if_no_path"
{% endhighlight %}

That’s all…