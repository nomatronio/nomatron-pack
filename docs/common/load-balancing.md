# Load balancing — how users reach Nomatron

Nomatron listens on **port 4649** inside each server task. Users normally reach it through **one front door** — not directly on every VM. This guide explains the three pack modes and when you need **Traefik**, **Fabio**, or a **cloud load balancer** (ALB, Azure App Gateway, GCP GLB, etc.).

**Assume you know nothing:** pick **one** entry path below. You do not stack Traefik *and* ALB both terminating traffic to Nomatron on 4649 unless you deliberately design a two-tier setup (unusual).

## Quick decision

```text
Where do users connect?
│
├─ Homelab / no LB ──────────────► load_balancer_mode = "none"
│                                   http_port_static = 4649 (recommended)
│                                   Users → http://client-ip:4649
│
├─ Cloud LB (ALB, App Gateway…) ─► load_balancer_mode = "none"
│                                   http_port_static = 4649
│                                   register each client VM in LB target pool
│                                   Users → https://nomatron.example.com (LB)
│                                   NO Traefik/Fabio required
│
├─ Traefik/Fabio already on Nomad ► load_balancer_mode = "service"
│                                   Traefik reads Nomad/Consul catalog
│                                   Users → Traefik → Nomatron tasks
│
└─ Want pack to install Traefik ──► load_balancer_mode = "traefik"
                                    Pack deploys Traefik system job
                                    Users → Traefik → Nomatron tasks
                                    Optional: cloud LB in front of Traefik only
```

## Pack variable: `load_balancer_mode`

| Value | Registers Nomad service? | Deploys Traefik? | Typical use |
|---|---|---|---|
| **`none`** | No | No | Cloud ALB/App Gateway/GLB, homelab direct IP, VPN-only access |
| **`service`** | Yes (Traefik-style tags) | No | Cluster already runs Traefik or Fabio with Nomad/Consul provider |
| **`traefik`** | Yes | Yes (pack deploys Traefik job) | No cloud LB; Traefik is the entry point on port 80/443 |

Related vars:

| Variable | When to set |
|---|---|
| `http_port_static = 4649` | **`none`** mode — fixed host port for cloud LB target groups |
| `register_service = true` | **`service`** or **`traefik`** — ignored in **`none`** mode |
| `register_grpc_service = true` | Separate Nomad service for Host Agent gRPC (Traefik TCP). Default `false`. |
| `agent_grpc_advertise_addr` | Public TCP `host:port` Host Agents dial. Required when the HTTP URL is HTTPS on `:443`. |
| `grpc_port_static` | Optional static host gRPC port. Leave `0` when Traefik on the same client binds `4650`. |
| `public_hostname` | DNS name users type (e.g. `nomatron.example.com`) |
| `public_scheme` | `https` when TLS terminates at LB or Traefik |
| `server.api_addr` | Full URL Nomatron uses in links/OAuth callbacks — usually `https://nomatron.example.com` |
| `server.trusted_origins` | Browser origins allowed for CSRF (UI login/forms) — usually `["https://nomatron.example.com"]` |
| `server.tls_enabled` | `false` when TLS terminates at LB/Traefik; `true` when Nomatron terminates TLS |

## Option A — Cloud load balancer (ALB, App Gateway, GLB, Octavia)

**You do not need Traefik or Fabio.** The cloud LB forwards HTTP(S) to each Nomad client on a **fixed port**.

### How it works

```text
Internet ──► ALB :443 ──► EC2 client 1 :4649 ──► Nomatron task
                      ├──► EC2 client 2 :4649 ──► Nomatron task
                      └──► EC2 client 3 :4649 ──► Nomatron task
```

### Pack settings

```hcl
load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649
serf_port_static   = 7946   # HA only

public_hostname = "nomatron.example.com"
public_scheme   = "https"

server = {
  port             = 4649
  api_addr         = "https://nomatron.example.com"
  trusted_origins  = ["https://nomatron.example.com"]
  tls_enabled      = false   # TLS terminates at ALB
}
```

**Why `http_port_static`?** With bridge networking, Nomad normally assigns a random host port. Cloud LBs need a **stable port** (4649) on each VM for target groups. Static port is enabled when `load_balancer_mode=none` and `http_port_static > 0`.

### Cloud LB configuration (same idea on AWS/Azure/GCP/OpenStack)

1. Create HTTP(S) load balancer with public or corp-facing listener on **443**.
2. Target group / backend pool: **each Nomad client private IP**, port **4649**, protocol HTTP.
3. Health check: `GET /api/v1/health?bootstrap=ok` — expect **200**.
4. TLS: terminate at LB (ACM certificate on AWS, etc.).
5. Security/firewall: LB → clients **4649/tcp** only; do not expose 4649 to the public internet.

This matches the [Nomatron AWS reference architecture](https://github.com/nomatronio/reference-architecture/tree/main/aws) (ALB → instances on 4649, no Traefik).

### HA note

Each of the 3 Nomatron servers runs on a different client. The LB balances across all healthy targets. Serf gossip (**7946**) is **client-to-client**, not through the LB.

## Option B — Traefik or Fabio already running (`service` mode)

Use this when your Nomad cluster **already has** Traefik or Fabio watching the Nomad or Consul service catalog.

### How it works

```text
Internet ──► Traefik :443 ──► (discovers "nomatron" service) ──► task :4649
```

The pack registers a Nomad **service** block with Traefik-compatible tags (hostname router, backend port 4649). Traefik picks up changes on deploy/scale automatically — no manual target group updates.

### Pack settings

```hcl
load_balancer_mode = "service"
register_service   = true
service_provider   = "nomad"   # or "consul" on older clusters

public_hostname = "nomatron.example.com"
public_scheme   = "https"

server = {
  api_addr        = "https://nomatron.example.com"
  trusted_origins = ["https://nomatron.example.com"]
  tls_enabled     = false   # Traefik terminates TLS
}
```

Default tags (unless you override `service_tags`):

```text
traefik.enable=true
traefik.http.routers.nomatron.rule=Host(`nomatron.example.com`)
traefik.http.services.nomatron.loadbalancer.server.port=4649
```

**Fabio:** Fabio uses different tag conventions. Set custom `service_tags` in your vars file per [Fabio route tags](https://fabiolb.net/feature/route-tags/). The Fabio route hostname must match an entry in `server.trusted_origins`.

**Do not also point ALB at 4649 on every node** unless Traefik listens there — pick Traefik *or* direct ALB, not both to Nomatron tasks.

## Option C — Pack deploys Traefik (`traefik` mode)

Use when you want a load balancer **on Nomad** but do not have Traefik installed yet.

### How it works

```text
Internet ──► Traefik task :80/443 ──► Nomatron tasks (via catalog)
```

`nomad-pack` renders **two** jobs: Nomatron + Traefik system job.

### Pack settings

```hcl
load_balancer_mode = "traefik"
register_service   = true

public_hostname = "nomatron.example.com"
public_scheme   = "https"

server = {
  api_addr        = "https://nomatron.example.com"
  trusted_origins = ["https://nomatron.example.com"]
  tls_enabled     = false
}
```

The pack’s Traefik job listens on **HTTP port 80** by default. Use `http://…` in `trusted_origins` until you configure HTTPS on Traefik (or place a cloud LB in front).

Deploy:

```bash
nomad-pack run -var-file=production.vars.hcl .
```

Open firewall **80/443** to Traefik tasks (not necessarily 4649 to the internet). Traefik and Nomatron should share the same `node_pool` if using dedicated clients.

### Traefik + cloud LB (optional two-tier)

Some teams place ALB **in front of** Traefik only:

```text
Internet ──► ALB :443 ──► Traefik :80 on 1–2 clients ──► Nomatron tasks
```

Configure ALB targets on Traefik's static port, keep `load_balancer_mode=traefik`. Nomatron stays on 4649 internally. This is optional — single-tier Traefik or single-tier ALB is simpler.

## Option D — No load balancer (`none`, homelab)

Direct access to one client:

```hcl
load_balancer_mode = "none"
http_port_static   = 4649
register_service   = false

server = {
  api_addr = "http://192.168.3.11:4649"
}
```

Users browse to `http://192.168.3.11:4649`. Restrict firewall to trusted LAN CIDR.

## Comparison table

| | Cloud ALB | Traefik/Fabio (`service`) | Pack Traefik (`traefik`) | Direct (`none`) |
|---|---|---|---|---|
| **Need Traefik?** | No | Yes (already installed) | Pack installs it | No |
| **`http_port_static`** | **4649** (required) | Not required | Not on Nomatron | Optional |
| **Auto-update on scale** | Manual/automation for target groups | Yes (catalog) | Yes (catalog) | N/A |
| **TLS termination** | At LB | At Traefik | At Traefik | Usually none (lab) |
| **Best for** | AWS/Azure/GCP production | Existing Nomad+Traefik shops | Small clusters without cloud LB | Homelab |

## Health checks

All paths should use the same health endpoint:

```text
GET /api/v1/health?bootstrap=ok
```

- **200** — Nomatron is up and database reachable (after bootstrap)
- **503** — process up but DB unreachable (check BYODB connectivity)

Configure this path on ALB target groups, Traefik, and Nomad service checks (automatic in **`service`** / **`traefik`** modes).

## TLS, api_addr, and CSRF

Nomatron listens HTTP on **4649** inside the task when `server.tls_enabled = false` (production default). TLS terminates at the **load balancer or Traefik/Fabio**. Postgres TLS is separate — use `database.sslmode = require` for production/HA (enforced by the pack). Host Agent **gRPC** still needs TLS on Nomatron when Traefik passthrough is used — see [Host Agent gRPC](#host-agent-grpc-traefik-tcp).

Set these to the **public URL users type in the browser** (scheme + hostname):

| Variable | Purpose |
|---|---|
| `server.api_addr` | Links, OAuth callbacks, webhooks |
| `server.trusted_origins` | CSRF allowlist for the web UI (`Origin` / `Referer` on POSTs) |
| `public_hostname` | Traefik `Host()` router tag (when using default `service_tags`) |

```text
Browser  Origin: https://nomatron.example.com
    →  ALB / Traefik / Fabio  (TLS here)
    →  client :4649 HTTP  →  Nomatron
```

**Traefik (`service` or `traefik` mode):** `public_hostname` drives `Host(\`…\`)` in service tags. It must match `trusted_origins` (same hostname; same `http` vs `https` as the browser URL). Mismatch causes CSRF errors on login even when routing works.

**Fabio:** configure `service_tags` so the public hostname matches `trusted_origins`.

**Pack Traefik:** bundled Traefik is HTTP :80 only until you add TLS. Match `trusted_origins` to what users actually browse.

**Multiple URLs:** add each origin, e.g. `["https://nomatron.example.com", "https://nomatron.internal.corp.example.com"]`.

## Host Agent gRPC (Traefik TCP)

The HTTP API and the Host Agent **gRPC control stream** are different listeners. Host Agents enroll over HTTPS (`server.api_addr`) and then open a **TLS gRPC** connection (HTTP/2 ALPN `h2`) to a **TCP** address. Pointing gRPC at an HTTPS reverse proxy on `:443` fails with `missing selected ALPN property`.

Keep the HTTP path you already have. Add a **second** front door for gRPC:

```text
HTTPS ──► Traefik HTTP ──► Nomatron :4649     (UI, API, Host Agent enroll)
TCP    ──► Traefik TCP  ──► Nomatron :4650    (Host Agent control stream)
```

### Pack settings (`service` or `traefik` mode)

```hcl
load_balancer_mode     = "service"   # or "traefik"
register_service       = true
register_grpc_service  = true
# Leave grpc_port_static = 0 so Nomad assigns a dynamic host port.
# Do not set 4650 on a client that also binds Traefik's nomatron-grpc entrypoint.

agent_grpc_advertise_addr = "xxxxx.a.pinggy.io:12345"  # public TCP host:port
```

Default gRPC tags (unless you override `grpc_service_tags`):

```text
traefik.enable=true
traefik.tcp.routers.nomatron-grpc.entrypoints=nomatron-grpc
traefik.tcp.routers.nomatron-grpc.rule=HostSNI(`*`)
traefik.tcp.routers.nomatron-grpc.tls=true
traefik.tcp.routers.nomatron-grpc.tls.passthrough=true
```

All HA allocations must use the **same** `grpc_service_name` (default `nomatron-grpc`) so Traefik load-balances them. Do **not** add TCP tags to the HTTP `nomatron` service.

### Traefik (existing job or pack Traefik)

The pack does not change a Traefik job you already run (`load_balancer_mode=service`). Add a TCP entrypoint named **`nomatron-grpc`**:

```yaml
entryPoints:
  nomatron-grpc:
    address: ":4650"
```

`load_balancer_mode=traefik` adds that entrypoint on `traefik_grpc_port` (default `4650`) when `register_grpc_service=true`.

TCP tunnels (Pinggy TCP, cloud NLB) must target **Traefik on the load-balancer client**, not one Nomatron allocation IP. If Pinggy and Traefik share a Nomad client, bind Pinggy to `127.0.0.1:4650`.

**Port clash:** if a Nomatron allocation on the Traefik client also publishes host `:4650`, Traefik cannot bind the entrypoint. Leave `grpc_port_static=0` (dynamic) or set `traefik_grpc_port` to something else (for example `14650`) and point the tunnel there.

### TLS

Host Agents always dial gRPC with TLS and present a client certificate. Traefik must **passthrough** TLS (the default tags). Nomatron gRPC TLS is the same flag as HTTP: set `server.tls_enabled = true` with a certificate whose SAN matches `agent_grpc_advertise_addr`. Terminating TLS at Traefik breaks client-certificate authentication.

After changing `agent_grpc_advertise_addr`, repair or recreate Host Agent jobs so they pick up the advertised gRPC address.

### Cloud TCP load balancer (`none` mode)

Use a **TCP** target group (not HTTP) on each client. Set `grpc_port_static` to a stable host port (typically `4650` when Traefik is not on those clients) and `agent_grpc_advertise_addr` to the NLB hostname and port. You can leave `register_grpc_service=false`.

## Related docs

- [Ports and firewall](ports-and-firewall.md) — which ports to open for each mode
- [Dedicated nodes](dedicated-nodes-and-placement.md) — node pools and constraints
- [Platform guides](../../packs/nomatron/README.md) — pack profiles and example vars
