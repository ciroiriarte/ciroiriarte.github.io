---
title: "Proxmox VE & Object Storage Services: Thinking out loud"
description: "Should Proxmox VE run Ceph's RADOS Gateway as a native S3 service? A design argued out loud: ingress, high availability, certificates, tenancy, and the cost of carrying a fork."
author: Ciro Iriarte
lang: en
date: 2026-11-14 00:10:00 -0300
categories:
  - storage-backup
  - virtualization
tags:
  - proxmox
  - ceph
  - object-storage
  - s3
---

I run a PVE cluster backed by Ceph. Block storage (RBD) and the shared filesystem (CephFS) show up as first-class citizens in the UI. Ceph also ships a perfectly good S3 implementation, the RADOS Gateway, and that one I still wire up by hand, off to the side, like a guilty secret.

So I sat down with the version of me that has already found three reasons this won't work: an Internet-facing listener on the hypervisors, a tenant model Proxmox doesn't have, and a fork of pve-manager I'd carry forever. The question was whether pulling RGW into Proxmox properly is worth it anyway. There's no code to install here; this is a design argument, and the working notes live in [pve-objectstorage](https://github.com/ciroiriarte/pve-objectstorage).

<!--more-->

## The itch

**— Me:** I have Ceph under the hood already. Why am I not serving S3 straight from the hypervisors?

**— Also me:** Because today you create it with `radosgw-admin`, hand-roll a `systemd` unit, put a load balancer in front, and hope nobody touches it during the next cluster upgrade. It works, but it's a pet, not a feature.

Block and file aren't pets. They're declared, clustered, and managed from the same place as everything else. The cluster is already there, the OSDs are already there, the data is already there. The only thing missing is Proxmox treating object storage as something it owns instead of something I smuggled in.

The fashionable answer is Rook, or some Ceph operator behind MetalLB. I'm not dragging a Kubernetes control plane onto bare-metal PVE nodes to hand out S3 buckets: a second distributed system to babysit and a second failure domain, all to expose a daemon Ceph already builds and PVE already packages.

**— Also me:** Then take the boring Proxmox answer. Put HAProxy and RGW in an LXC container, let `ha-manager` move it around, and patch nothing.

**— Me:** That's the pet again, just inside a container. The guest still needs Ceph keys and a route into the cluster network, it adds a hop to every request, and its lifecycle stays manual. And yes, the Ceph dashboard can already manage RGW users, buckets and quotas. What it can't do is speak PVE permissions or live in the same pane as everything else I run.

The native stack has everything I need: `pveceph`, `systemd`, `ifupdown2` with Linux VRFs, and HAProxy. The constraint writes itself: **native `systemd` + VRF + HAProxy, nothing else.**

## Keep the daemon dumb, then mind the network

Keep the RGW daemon simple: bare RADOS Gateway on the embedded Beast server, bound to a private IP on port 7480 (the plain `rgw_frontends` default; `cephadm` uses 80), translating HTTP into Ceph calls. No TLS, no public binding, no cleverness. If it dies, `systemd` brings it back. Proxmox owns the unglamorous automation around it: Ceph client keys, realm and zonegroup init for a single zone (multisite stays out of v1), the `systemd` units. The stuff I always get subtly wrong at 11pm.

Traffic from HAProxy to Beast crosses nodes as plain HTTP. SigV4 protects the credentials, not the payload, so this assumes a trusted backend network; TLS to the backends stays an option for sites that don't have one.

**— Me:** The pool wizard is easy, then. Pick an index pool, pick a data pool.

**— Also me:** That's not how RGW thinks. A bucket gets a **placement target** when it's created, and that can't be changed later. Inside the target, **storage classes** are chosen per object, at upload or by a lifecycle rule.

So the wizard models placement targets and their storage classes, not two CRUSH dropdowns. Under that, sure, a fast NVMe rule for the replicated index pool, an HDD rule or EC profile for bulk data. And the trap that only surfaces in production: an erasure-coded data pool needs `data_extra_pool` pointed at a replicated pool, because EC can't hold omap. Leave it unset and RGW falls back to the EC data pool, and multipart uploads fail. The wizard should set it automatically, and coexist with PVE's existing pool and autoscaler UI rather than fight it.

Then comes the part every one of these designs quietly dies on: putting HAProxy in front. A PVE node already has other things that want port 443, on networks that don't belong together. Bind `*:443` and you've armed a wildcard land mine: the next 443 listener collides, or you expose an endpoint on a network it had no business touching. So the rule is absolute: **HAProxy never binds wildcards.** Explicit IPs, full stop, and the generator refuses to emit a config that breaks that. To keep ingress off the underlay, the public frontend binds into a VRF such as `vrf-public`.

**— Also me:** Careful with that VRF. Start the whole HAProxy with `ip vrf exec vrf-public` and *every* socket it opens lands in that VRF, including the backend connections to RGW on the private network. Those die unless you leak routes between tables. It isn't a sandbox either: `ip vrf exec` attaches a cgroup BPF hook that binds new sockets to the VRF device, closer to `SO_BINDTODEVICE` than to a network namespace.

**— Me:** So HAProxy stays in the default VRF and only the frontend binds into the public one (`bind 203.0.113.10:443 interface vrf-public`). Backends keep using the underlay routes, and Keepalived's VIP lives in `vrf-public` next to the frontend. Multiple proxies can share a VRF; the moment they share a port, the tooling forces distinct IPs.

{% include image.html url="/assets/img/2026-11-14-rgw-data-path.svg" description="Image 1 - The request path: TLS ends at HAProxy, whose frontend binds into vrf-public; backends reach RGW over the backend network" alt="Diagram: S3 clients reach a VIP on port 443 in the public network, which points at gw1 (active HAProxy) or gw2 (standby). HAProxy forwards plain HTTP over the backend network to RGW Beast daemons on pve1 to pve3, port 7480, which talk to Ceph RADOS." width=860 height=360 %}

This is its own subsystem, not a checkbox under Ceph, and it must not be glued onto SDN. SDN is tenant overlay territory, and infrastructure ingress has no business sharing a blast radius with tenant network changes. So: a "Unified Infrastructure Proxy" configured at the Datacenter level, a new panel next to ACME and SDN, one lightweight `systemd` worker per service. For v1 it fronts exactly one backend, the RadosGW. Fronting the PVE API too is tempting and doubles the attack surface for little gain, so it waits.

**— Also me:** And the elephant: you just put an Internet-facing listener on the same kernel as your VMs and your Ceph keys. The VRF limits *where* it listens, not what a compromised HAProxy can reach. On a hyperconverged node, an S3 traffic spike also competes with VMs and OSDs for CPU.

**— Me:** Which is why the gateway is a role, not something every node runs. I pick the nodes, ideally ones without OSDs, or dedicated gateway hosts, and the `systemd` units get `CPUQuota=` and `MemoryMax=` so a busy bucket can't starve a VM. If that's still too close for comfort, the same design runs on hosts with no guests at all.

{% include image.html url="/assets/img/2026-11-14-rgw-placement.svg" description="Image 2 - Where the gateway runs: a role on chosen cluster nodes without OSDs (A), or dedicated hosts with no guests (B)" alt="Diagram: in option A a five-node PVE and Ceph cluster has three nodes with VMs and OSDs and two gateway nodes running HAProxy and RGW with no OSDs. In option B a three-node cluster with VMs and OSDs sits next to two separate gateway hosts running HAProxy and RGW with no guests." width=860 height=260 %}

## High availability, pick your poison

That leaves the question that matters more than any config syntax: what happens when a gateway node dies? Three options, and no free lunch:

- **Single active ingress (failover).** HAProxy + Keepalived, a floating VIP, one node taking the traffic and balancing it across every RGW daemon. Failover for the ingress, not for the backends. Stable, simple mental model, some throughput left on the table. It's the same shape as Ceph's own `cephadm` RGW ingress, so I can borrow proven config logic without dragging `cephadm` in as a second control plane.
- **All-active load sharing.** DNS round-robin across every gateway's HAProxy. Great for throughput, but correctness leans on the resolver evicting dead nodes, and stock DNS does *no* health checking. A dead node keeps handing out its IP and clients keep hitting failures. Best-effort at most, not something I'd call highly available with a straight face.
- **Anycast (advanced, opt-in).** One S3 VIP announced from every gateway over BGP/EVPN, which PVE SDN already speaks via FRR. With BFD it converges faster than VRRP; with default BGP timers it's slower. ECMP also rehashes flows whenever a node joins or leaves, which kills long multipart uploads in flight. And it drags the SDN/FRR dependency right back in, the thing I just decoupled from. Strictly opt-in, for sites already running a routed fabric.

{% include image.html url="/assets/img/2026-11-14-rgw-ha-options.svg" description="Image 3 - The three high-availability options" alt="Diagram with three panels. A, failover VIP: clients reach a VIP held by active gw1, with gw2 on standby linked by VRRP. B, DNS round-robin: DNS returns three A records for gw1 to gw3, and gw3 is dead but still answered. C, anycast: a router does ECMP towards gw1 to gw3, which all announce the same /32 over BGP with BFD." width=900 height=300 %}

Ship failover as the default, expose the other two as deliberate choices. What's not defensible is shipping DNS round-robin *as if* it were HA when nothing is health-checking it.

## Certificates, the thing that pages you at 3am

Certs go in `pmxcfs`, same as every other secret: drop the cert and key under `/etc/pve/priv/<service>/` and every node sees them. It's the pattern PVE already uses for storage passwords (`/etc/pve/priv/storage/<id>.pw`), and it needs no `pmxcfs` C patch: arbitrary private paths are allowed, and raw cert blobs aren't the structured config that has to be registered.

**— Also me:** Replicating a file isn't deploying a cert. Nothing tells HAProxy on the other nodes that it changed. And PVE's ACME support is per node today: Node → Certificates for the certs, Datacenter → ACME for accounts and DNS plugins. There's no cluster-wide certificate to hang this off.

**— Me:** Then it's new code, built on the ACME plumbing rather than beside it. One renewal lead, elected with a `pmxcfs` lock so nodes don't stampede the CA, writes the cert and bumps a version file. Each gateway node checks that file on a timer and reloads HAProxy when it changes. No inotify tricks on a FUSE filesystem.

DNS-01 is the default. It doesn't care which node answers, so it doesn't fight the VIP, and it's the only way to get the wildcard certificate that virtual-hosted buckets (`bucket.s3.example.com`) need, along with wildcard DNS and `rgw_dns_name`. HTTP-01 isn't impossible, but PVE's standalone plugin wants port 80 to itself, which collides with HAProxy owning the endpoint. A `systemctl reload` then swaps the cert: established connections finish on the old process, and only a handful of new connections can fail during the handover. Set `hard-stop-after` so old workers serving long S3 transfers don't linger forever.

## Who is allowed to touch what

**— Me:** Am I building an S3 file browser into Proxmox now?

**— Also me:** Hard no. Proxmox is the control plane, not a data-plane file manager.

The admin surface is provisioning and health: `pveceph rgw create/destroy <id>` for daemon lifecycle, a Datacenter → Ceph → Object Storage panel for realm health and daemon distribution, the placement wizard, and a thin GUI over `radosgw-admin` to mint users, rotate keys, set quotas.

The tenant surface stays tiny: endpoint URL, view/rotate keys, watch quota, maybe make a bucket. Every actual object operation, PUT/GET, multipart, ACLs, CORS, goes through real S3 clients (AWS CLI, boto3). I'm not reimplementing the S3 data path inside a hypervisor UI, and any version of me that suggests otherwise should be escorted out of the meeting.

**— Also me:** Tidy. Except "the tenant" isn't a thing PVE actually has.

**— Me:** No, it isn't. PVE has users, groups, realms and ACLs, but no native *tenant* object. Someone has to decide what a tenant maps to: most likely a PVE group sharing one S3 identity and key set, gated by a new privilege set (`S3.Allocate`, `S3.KeyManage`, `S3.Audit`) through the normal ACL machinery. And the spec still lacks things tenants want on day one: key *revocation*, not just rotation; bucket versioning and lifecycle; quota alerts. Until that's pinned down I'm describing a UI I haven't designed yet.

## Authentication, where PVE admits its limits

Tenants can't log in to S3 with their Proxmox password. PVE session tickets and SigV4 don't interoperate, so you provision identity rather than proxy logins. A shared directory or IdP behind both, LDAP or OIDC, is the closest you get to "same credentials". Two modes:

- **Isolated native auth (default).** Proxmox runs `radosgw-admin user create` and hands out standalone access/secret keys, separate from PVE logins. A leaked PVE password isn't a leaked bucket, and the other way round.
- **Identity federation (OIDC/STS).** Clients trade a JWT for temporary credentials via RGW's STS endpoint (`AssumeRoleWithWebIdentity`). This is more than "point RGW at Keycloak": the control plane has to provision an RGW OIDC provider object, IAM roles with trust policies, per-role permission policies, and define how a PVE group maps onto those roles. On the RGW side it also means `rgw_s3_auth_use_sts = true` and the same `rgw_sts_key` on every gateway, the two settings everyone trips over. The mapping is the unglamorous half, and exactly where anyone who has wired up STS will poke first.

Both keep PVE out of the request path. If the management UI is down, buckets keep answering. That's the property I care about.

## The unglamorous truth about shipping this

Proxmox's API and UI are gloriously monolithic, so this can't be 100% greenfield. The clean part is two net-new `.deb` packages: `pve-ceph-radosgw` for the backend logic and `systemd` automation, and `pve-service-gateway` for the proxy (`pve-infra-proxy` was too generic). The messy part is patching stock Proxmox.

**— Me:** Patch `Ceph.pm`, drop the UI into `pvemanagerlib.js`, done.

**— Also me:** Not quite. The CLI lives in `PVE/CLI/pveceph.pm`, the API under `PVE/API2/`, the UI in the modular `www/manager6/` tree; `pvemanagerlib.js` is generated from it.

Then the genuinely thankless detail: making custom packages *win* against upstream. A `+` marker does **not** reliably override stock: `9.0.1-1+rgw1` sorts *before* the next upstream `9.0.2-1`, so the next point release overtakes it. The durable answer is to continuously rebase the downstream packages and prefer them with narrow, per-package APT pins below 1000; 990 beats the stock repository's 500. At 1000 or above, APT will *downgrade* to reach the pinned version, which is actively dangerous. The kind of thing that's invisible right up until it ruins a Tuesday.

**— Also me:** And every one of those pins is a liability with a schedule. While you're pinned, upstream pve-manager releases, security fixes included, wait until you rebase.

**— Me:** Which is why the downstream packages are a staging area, not a destination. The honest end state is patches on pve-devel. A fork is how I prove the design works, not how I want to run it.

## Where I landed with myself

The infrastructure half holds up: bare Beast daemons doing the dumb translation on chosen nodes, a VRF-bound gateway doing the scary public-facing work, certificates riding on plumbing that already exists, identity that keeps PVE out of the data path, no Kubernetes in sight. The product half doesn't exist yet: what a tenant is and what it may do. That's architecture, not homework. Then there's the actual homework: observability, backup and restore of the realm/zone/user/key metadata, and Ceph upgrades, where RGW has to go last and `pveceph` has to know it.

Of the three reasons this wouldn't work, I have an answer for the listener on the hypervisors, a plan for the fork, and nothing yet for tenancy.

So the design stays a draft on purpose. Half of architecture is letting it sit until the part of you that finds the flaws gets bored and goes quiet. Mine isn't quiet yet, but for the first time it's nodding along more than arguing, which is usually the sign something's worth building. The gory specifics (realm init, the HAProxy generators, the packaging strategy) live in my [pve-objectstorage](https://github.com/ciroiriarte/pve-objectstorage) notes. If you run RGW next to PVE and see a hole I missed, that's where to tell me.
