# Ports and firewall rules

Use this matrix when configuring cloud security groups, NSGs, GCP firewall rules, or on-prem host firewalls for **Nomad clients running Nomatron**.

## Nomatron server (pack defaults)

| Port | Protocol | Direction | Source | Destination | Purpose |
|---|---|---|---|---|---|
| **4649** | TCP | Inbound | Load balancer and/or admin CIDR | Nomad client | HTTP API and Web UI |
| **4650** | TCP | Inbound | Traefik / TCP LB / agent CIDR | Nomad client **or Traefik client** | Agent gRPC. Host Agents must not dial the HTTPS `:443` front door. With Traefik TCP, open this port on the **Traefik** client; Nomatron gRPC can stay on a dynamic host port (`grpc_port_static=0`). |
| **7946** | TCP + UDP | Inbound | Same Nomad client SG / Serf peer CIDR | Nomad client | Serf gossip (**HA only**, `count > 1`) |

When `load_balancer_mode=none` with a **cloud LB** (ALB, App Gateway, GLB, Octavia, NSX ALB), users reach Nomatron through the LB on port 4649 on each client — **no Traefik required**. Set `http_port_static=4649` in pack vars.

When `load_balancer_mode=service` or `traefik`, users reach Nomatron through **Traefik or Fabio** on Nomad — restrict **4649** on clients to the LB/reverse-proxy subnet, not the public internet.

When `load_balancer_mode=none` without a cloud LB (homelab), you may publish a static host port via `http_port_static` — open that port from trusted CIDRs only.

## Load balancer (if used)

| Port | Protocol | Direction | Source | Destination | Purpose |
|---|---|---|---|---|---|
| **80** | TCP | Inbound | Internet or corp network | LB | HTTP (Traefik/Fabio/ALB) |
| **443** | TCP | Inbound | Internet or corp network | LB | HTTPS |

LB → Nomad client: **4649/tcp** from LB security group to client security group (HTTP). For Host Agents, also allow **TCP** from the gRPC load balancer or tunnel to Traefik's `nomatron-grpc` entrypoint (default **4650/tcp** on the Traefik client), then Traefik → Nomatron alloc gRPC ports.

## PostgreSQL (BYODB — production)

| Port | Protocol | Direction | Source | Destination | Purpose |
|---|---|---|---|---|---|
| **5432** | TCP | Outbound | Nomad client SG | Database SG / writer endpoint | Nomatron → Postgres writer |

Nomad clients initiate outbound connections to Postgres. Allow **egress** from clients to the database security group on 5432. Do not expose Postgres to the public internet.

## Provision-mode Postgres (lab only)

When `database_mode=provision` and `count > 1`, one client runs Postgres with `postgres.host_port` (default **5432**) published on the host. Allow **5432/tcp** from other Nomad client IPs (Serf peer CIDR / client SG) to the Postgres host only.

## Nomad cluster (client ↔ server)

Nomad clients must reach Nomad servers on **4646/tcp** (HTTP API) and **4647/tcp** (RPC). Configure per your existing Nomad cluster — this pack does not run Nomad servers.

If using **Consul** (`service_provider=consul`), clients need reachability to Consul agents (default **8500/tcp** HTTP, **8301** LAN gossip).

## SSH / admin (recommended)

| Port | Protocol | Direction | Source | Destination | Purpose |
|---|---|---|---|---|---|
| **22** | TCP | Inbound | Admin bastion CIDR only | All Nomad clients | Break-glass SSH |

Prefer SSM (AWS), Azure Run Command, or IAP (GCP) over open SSH where available.

## Egress (all Nomad clients)

Allow outbound **443/tcp** for:

- Container image pulls (`ghcr.io`, Docker Hub if mirrored)
- Nomatron licensing (`api.keygen.sh` by default)
- Package downloads (if `runtime=binary` with artifact install)

Allow outbound **53/udp+tcp** (DNS) and NTP as required by your environment.

## HA checklist

- [ ] Serf **7946/tcp+udp** open between all Nomad clients that run Nomatron (`count > 1`)
- [ ] Postgres **5432/tcp** from all Nomatron clients to writer endpoint
- [ ] LB → client **4649/tcp** if using a load balancer
- [ ] Host Agent gRPC: TCP to Traefik (or `grpc_port_static`) — not HTTPS `:443`; set `agent_grpc_advertise_addr`
- [ ] `serf.retry_join` addresses match reachable client IPs/hostnames
- [ ] Leave `serf.advertise_addr` empty so each allocation advertises `NOMAD_HOST_IP_serf` (the Nomad client IP from port label `serf`). Do not advertise bridge/CNI allocation IPs such as `172.26.x` — those are not routable between clients.
- [ ] Each alloc has `NOMAD_HOST_IP_serf` and `NOMAD_HOST_PORT_serf` in the task environment (pack sets these from the `serf` port). If they are missing, Nomatron rc.45+ registers `127.0.0.1` and HA nodes collide. Use `nomatron_version` `v0.1.0-rc.45` or later.
