# Nomatron Nomad Pack

Deploy [Nomatron](https://nomatron.io) on HashiCorp Nomad with flexible runtime, database, HA, and load balancer options.

Nomatron is an operational control plane for HashiCorp Nomad. This pack deploys the Nomatron server — not application workloads managed by Nomatron.

This pack is the **primary deployment mechanism** and **reference architecture** for running Nomatron on Nomad.

**Install nomad-pack, get this pack, plan, and run:** see the [nomatron-pack repository README](https://github.com/nomatronio/nomatron-pack/blob/main/README.md#install-and-use-nomad-pack).

**Platform setup (VM, firewall, Docker, CNI, load balancing):** [docs](https://github.com/nomatronio/nomatron-pack/tree/main/docs/README.md).

---

## Reference architecture

Nomatron HA is **horizontal** (multiple Nomatron servers + Serf). PostgreSQL HA is **external** (BYODB to your writer endpoint). The pack does not run production Postgres replication — it integrates with the HA Postgres you already operate.

```text
                 [ Users / CI / Webhooks ]
                           │
                 [ Load balancer — Traefik / Fabio ]
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    Nomatron 1        Nomatron 2        Nomatron 3    ← count, spread, Serf
         │                 │                 │
         └─────────────────┼─────────────────┘
                           │
              [ PostgreSQL writer endpoint ]            ← BYODB (RDS, Patroni, etc.)
                           │
                 [ Nomad cluster (+ Consul?) ]
```

### Deployment profiles

| Profile | Variables section | Postgres | Nomatron | Use when |
|---|---|---|---|---|
| **`quickstart`** | [Quickstart (provision)](#quickstart-provision) | Provisioned, colocated | 1 or more | First eval, homelab, demos |
| **`production`** | [Production (BYODB, Docker)](#production-byodb-docker) | BYODB — HA writer, TLS | 1 server | Production, Docker OK |
| **`production`** (binary) | [Production (BYODB, binary)](#production-byodb-binary) | BYODB | 1 server (exec) | Production, no Docker for Nomatron |
| **`ha`** | [High availability (BYODB)](#high-availability-byodb) | BYODB — shared writer | 3+ servers, Serf | Production Nomatron HA |

Set `deployment_profile` in your vars file. The pack **validates** profile constraints at render time (for example, `production` rejects provisioned Postgres).

**Lab Nomatron HA without external Postgres:** [Lab HA (provision)](#lab-ha-provision) — `deployment_profile=quickstart`, `count>1`, not for production.

### Decision guide

| Question | Answer |
|---|---|
| Production? | `deployment_profile=production` or `ha` + **BYODB** |
| Docker required on clients? | **No** for production BYODB if `runtime=binary` — see [Runtime options](#runtime-options) |
| Need multiple Nomatron servers? | `deployment_profile=ha`, `count≥3`, Serf config |
| Just trying Nomatron? | `deployment_profile=quickstart`, `database_mode=provision` |
| Postgres HA / failover? | Your managed DB or Patroni — point `database.connection_string` at the **writer** |
| Older Nomad + Consul? | `service_provider=consul` (see [Nomad version requirements](#nomad-version-requirements)) |

---

## Prerequisites

- **Nomad 1.6+** cluster with **Linux clients** for production and for `network_mode=bridge`
- **Dedicated Nomad clients:** [node_pool, client meta, and constraints](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/dedicated-nodes-and-placement.md)
- **Load balancing:** [ALB vs Traefik vs direct access](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/load-balancing.md)
- For `runtime=docker`: Docker driver enabled on clients
- For `runtime=binary`: **exec** driver enabled; Docker **not** required for Nomatron (still required for `database_mode=provision` Postgres and `load_balancer_mode=traefik`)
- **CNI bridge plugin** when `network_mode=bridge` — see [Nomad client setup](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/nomad-client-setup.md)
- Host volumes when using `database_mode=provision`

### Nomad version requirements

| Deployment | Minimum Nomad | Notes |
|---|---|---|
| Single node — BYODB or colocated provision | **1.6+** | Bridge CNI, bootstrap health checks |
| HA BYODB (`count > 1`) | **1.6+** | Spread, Serf, rolling updates |
| HA provision (`count > 1`) | **1.6+** | Postgres via `nomadService` or Consul `service` template |

| `service_provider` | Provision HA Postgres discovery |
|---|---|
| **`nomad`** (default) | `nomadService` → `postgres.service_name` |
| **`consul`** | `service` → `postgres.service_name` |

### CNI setup (Linux clients)

See [nomad client setup](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/nomad-client-setup.md). Install CNI plugins and set `client { cni_path = "/opt/cni/bin" }` on each Linux client.

### macOS dev mode

CNI bridge does not work on macOS. Use **BYODB** + **`network_mode=standard`** and an external Postgres — see [macOS dev variables](#macos-dev-variables) below.

---

## Variables files

Save each block below as a `*.vars.hcl` file and pass it with `nomad-pack run --var-file=...`. Replace `REPLACE-*` placeholders before deploy. Do not commit real secrets.

### Dedicated client placement

Merge into production or HA vars. Client agent must set matching `node_pool` and `meta` — see [dedicated nodes guide](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/dedicated-nodes-and-placement.md).

```hcl
node_pool = "nomatron"

constraints = [
  {
    attribute = "${meta.nomatron}"
    operator  = "="
    value     = "true"
  }
]

# Optional: datacenters = ["dc1"]

# Cloud LB (ALB / App Gateway / GLB) — no Traefik:
# load_balancer_mode = "none"
# register_service   = false
# http_port_static   = 4649

# Existing Traefik/Fabio on Nomad:
# load_balancer_mode = "service"
# register_service   = true
```

### Production (BYODB, Docker)

Save as `production.vars.hcl`:

```hcl
deployment_profile = "production"
database_mode      = "byodb"
network_mode       = "bridge"

load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649

node_pool = "nomatron"
constraints = [
  { attribute = "${meta.nomatron}", operator = "=", value = "true" }
]

service_provider = "nomad" # use "consul" on older Nomad + Consul clusters

public_hostname = "nomatron.example.com"
public_scheme   = "https"

database = {
  connection_string          = "postgres://nomatron:REPLACE@db-writer.example.com:5432/nomatron?sslmode=require"
  host                       = ""
  port                       = 5432
  name                       = "nomatron"
  username                   = "nomatron"
  password                   = ""
  sslmode                    = "require"
  max_open_conns             = 25
  max_idle_conns             = 10
  conn_max_lifetime_seconds  = 300
  conn_max_idle_time_seconds = 60
}

server = {
  port                        = 4649
  api_addr                    = "https://nomatron.example.com"
  trusted_origins             = ["https://nomatron.example.com"]
  log_level                   = "info"
  log_format                  = "json"
  read_header_timeout_seconds = 10
  read_timeout_seconds        = 30
  write_timeout_seconds       = 60
  idle_timeout_seconds        = 120
  tls_enabled                 = false
  tls_cert_file               = ""
  tls_key_file                = ""
  tls_ca_file                 = ""
}

secrets = {
  encryption_key = "REPLACE-WITH-openssl-rand-base64-32-STABLE"
  license_key    = "REPLACE-WITH-YOUR-LICENSE-KEY"
  cluster_key    = "nomatron-cluster-key"
}
```

### Production (BYODB, binary)

Save as `production.vars.hcl`. Install Nomatron on each client at `binary_path` before deploy ([packages.nomatron.io](https://packages.nomatron.io/apt)).

```hcl
deployment_profile = "production"
database_mode      = "byodb"
network_mode       = "bridge"
runtime            = "binary"

binary_install_method = "host"
binary_path           = "/usr/bin/nomatron"
nomatron_version      = "v0.1.0-rc.21"

# Alternative: binary_install_method = "artifact", binary_arch = "amd64"

load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649

node_pool = "nomatron"
constraints = [
  { attribute = "${meta.nomatron}", operator = "=", value = "true" }
]

service_provider = "nomad"

public_hostname = "nomatron.example.com"
public_scheme   = "https"

database = {
  connection_string          = "postgres://nomatron:REPLACE@db-writer.example.com:5432/nomatron?sslmode=require"
  host                       = ""
  port                       = 5432
  name                       = "nomatron"
  username                   = "nomatron"
  password                   = ""
  sslmode                    = "require"
  max_open_conns             = 25
  max_idle_conns             = 10
  conn_max_lifetime_seconds  = 300
  conn_max_idle_time_seconds = 60
}

server = {
  port                        = 4649
  api_addr                    = "https://nomatron.example.com"
  trusted_origins             = ["https://nomatron.example.com"]
  log_level                   = "info"
  log_format                  = "json"
  read_header_timeout_seconds = 10
  read_timeout_seconds        = 30
  write_timeout_seconds       = 60
  idle_timeout_seconds        = 120
  tls_enabled                 = false
  tls_cert_file               = ""
  tls_key_file                = ""
  tls_ca_file                 = ""
}

secrets = {
  encryption_key = "REPLACE-WITH-openssl-rand-base64-32-STABLE"
  license_key    = "REPLACE-WITH-YOUR-LICENSE-KEY"
  cluster_key    = "nomatron-cluster-key"
}
```

### High availability (BYODB)

Save as `ha.vars.hcl`:

```hcl
deployment_profile = "ha"
database_mode      = "byodb"
network_mode       = "bridge"
count              = 3

load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649

node_pool = "nomatron"
constraints = [
  { attribute = "${meta.nomatron}", operator = "=", value = "true" }
]

service_provider = "nomad"

public_hostname = "nomatron.example.com"
public_scheme   = "https"

database = {
  connection_string          = "postgres://nomatron:REPLACE@db-writer.example.com:5432/nomatron?sslmode=require"
  host                       = ""
  port                       = 5432
  name                       = "nomatron"
  username                   = "nomatron"
  password                   = ""
  sslmode                    = "require"
  max_open_conns             = 25
  max_idle_conns             = 10
  conn_max_lifetime_seconds  = 300
  conn_max_idle_time_seconds = 60
}

server = {
  port                        = 4649
  api_addr                    = "https://nomatron.example.com"
  trusted_origins             = ["https://nomatron.example.com"]
  log_level                   = "info"
  log_format                  = "json"
  read_header_timeout_seconds = 10
  read_timeout_seconds        = 30
  write_timeout_seconds       = 60
  idle_timeout_seconds        = 120
  tls_enabled                 = false
  tls_cert_file               = ""
  tls_key_file                = ""
  tls_ca_file                 = ""
}

serf = {
  node_name           = ""
  bind_addr           = "0.0.0.0"
  advertise_addr      = ""
  port                = 7946
  retry_join          = ["10.0.1.10:7946", "10.0.1.11:7946", "10.0.1.12:7946"]
  retry_join_interval = "30s"
  retry_join_max      = 0
  encrypt_key         = "REPLACE-WITH-nomatron-keygen"
  tags                = {}
  gossip_interval_ms  = 0
  gossip_nodes        = 0
  probe_interval_ms   = 0
  probe_timeout_ms    = 0
}

secrets = {
  encryption_key = "REPLACE-WITH-openssl-rand-base64-32-STABLE"
  license_key    = "REPLACE-WITH-YOUR-LICENSE-KEY"
  cluster_key    = "nomatron-cluster-key"
}
```

Generate Serf encryption key: `nomatron keygen`

### Quickstart (provision)

Save as `provision.vars.hcl`. Requires a [host volume](#quickstart-host-volume) on the Nomad client.

```hcl
deployment_profile = "quickstart"
database_mode      = "provision"
network_mode       = "bridge"

postgres = {
  image_tag   = "16"
  db_name     = "nomatron"
  username    = "nomatron"
  password    = "nomatron"
  volume_path = "nomatron-postgres"
  cpu         = 500
  memory      = 1024
}

secrets = {
  encryption_key = "REPLACE-WITH-openssl-rand-base64-32"
  license_key    = "REPLACE-WITH-YOUR-LICENSE-KEY"
  cluster_key    = "nomatron-cluster-key"
}
```

After deploy, open `/ui/setup` to initialize the database.

### Lab HA (provision)

Save as `ha-lab.vars.hcl`. **Lab only** — not production.

```hcl
deployment_profile = "quickstart"
database_mode      = "provision"
network_mode       = "bridge"
count              = 3
load_balancer_mode = "none"
service_provider   = "consul"

postgres = {
  image_tag    = "16"
  db_name      = "nomatron"
  username     = "nomatron"
  password     = "nomatron"
  volume_path  = "nomatron-postgres"
  service_name = "nomatron-postgres"
  host_port    = 5432
  cpu          = 500
  memory       = 1024
}

serf = {
  node_name           = ""
  bind_addr           = "0.0.0.0"
  advertise_addr      = ""
  port                = 7946
  retry_join          = ["10.0.1.10:7946", "10.0.1.11:7946", "10.0.1.12:7946"]
  retry_join_interval = "30s"
  retry_join_max      = 0
  encrypt_key         = "REPLACE-WITH-nomatron-keygen"
  tags                = {}
  gossip_interval_ms  = 0
  gossip_nodes        = 0
  probe_interval_ms   = 0
  probe_timeout_ms    = 0
}

secrets = {
  encryption_key = "REPLACE-WITH-openssl-rand-base64-32-STABLE"
  license_key    = "REPLACE-WITH-YOUR-LICENSE-KEY"
  cluster_key    = "nomatron-cluster-key"
}
```

### macOS dev variables

Save as `mac-dev.vars.hcl`. Start Postgres on the Mac host, then `nomad agent -dev`. Use stable secrets across redeploys.

```hcl
database_mode = "byodb"
network_mode  = "standard"

nomatron_resources = {
  cpu    = 25
  memory = 512
}

database = {
  connection_string          = "postgres://nomatron:nomatron@host.docker.internal:5432/nomatron?sslmode=disable"
  host                       = ""
  port                       = 5432
  name                       = "nomatron"
  username                   = "nomatron"
  password                   = ""
  sslmode                    = "disable"
  max_open_conns             = 50
  max_idle_conns             = 25
  conn_max_lifetime_seconds  = 300
  conn_max_idle_time_seconds = 60
}

secrets = {
  encryption_key = "REPLACE-WITH-openssl-rand-base64-32"
  license_key    = "REPLACE-WITH-YOUR-LICENSE-KEY"
  cluster_key    = "REPLACE-WITH-YOUR-CLUSTER-KEY"
}
```

---

## Database choice

| Mode | Variable | When to use |
|---|---|---|
| **BYODB** | `database_mode=byodb` | **Production and HA** — RDS, Cloud SQL, Patroni leader, any HA Postgres **writer** |
| **Provision** | `database_mode=provision` | **Quickstart / lab only** |

Point BYODB at the **writer** endpoint — not a read replica. Pool sizing: `(count × max_open_conns) + headroom < postgres max_connections`.

### Quickstart host volume

Register on each client that may run provisioned Postgres:

```bash
sudo mkdir -p /opt/nomad/volumes/nomatron-postgres
sudo chown nomad:nomad /opt/nomad/volumes/nomatron-postgres
```

```hcl
client {
  host_volume "nomatron-postgres" {
    path      = "/opt/nomad/volumes/nomatron-postgres"
    read_only = false
  }
}
```

`postgres.volume_path` in the pack is the **host volume name** (`nomatron-postgres`), not the filesystem path.

---

## Runtime options

| | `runtime=docker` | `runtime=binary` |
|---|---|---|
| Nomad driver | Docker | **exec** |
| Docker on client | Required | Not required (Nomatron task only) |
| Production vars | [Production (BYODB, Docker)](#production-byodb-docker) | [Production (BYODB, binary)](#production-byodb-binary) |

**Still needs Docker:** `database_mode=provision`, `load_balancer_mode=traefik`.

For HA with binary runtime, add `runtime = "binary"` and `binary_*` settings to the [HA variables](#high-availability-byodb) block.

---

## Load balancer

See [load balancing guide](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/load-balancing.md).

| Mode | When to use |
|---|---|
| **`none`** + `http_port_static=4649` | Cloud LB (ALB, App Gateway, GLB) or direct IP |
| **`service`** | Traefik/Fabio already on Nomad |
| **`traefik`** | Pack deploys Traefik |

**Cloud production default:** ALB → each client on **4649** — no Traefik required.

---

## Required secrets

| Variable | Description |
|---|---|
| `secrets.encryption_key` | `openssl rand -base64 32` — stable for the lifetime of a database |
| `secrets.license_key` | Nomatron license key |
| `secrets.cluster_key` | Must match your license / other environments |
| `serf.encrypt_key` | `nomatron keygen` — required when `count > 1`, identical on all nodes |

Generate once, save in your vars file, reuse on every deploy. Do not commit real values.

---

## Key variables

- `deployment_profile` — `quickstart`, `production`, or `ha`
- `database_mode` — `byodb` or `provision`
- `runtime` — `docker` or `binary`
- `load_balancer_mode` — `none`, `service`, or `traefik`
- `nomatron_version` — release tag (default `v0.1.0-rc.20`)
- `count` — server instances
- `node_pool`, `constraints` — dedicated client placement
- `server`, `database`, `postgres`, `serf`, `bootstrap` — see `nomad-pack info nomatron`

Run `nomad-pack info .` (or `nomad-pack info nomatron` from the registry) for the full variable reference.

---

## Ports

| Port | Purpose |
|---|---|
| 4649 | HTTP API and Web UI |
| 4650 | Agent gRPC |
| 7946 | Serf gossip (HA) |

Health check: `/api/v1/health?bootstrap=ok`

---

## Upgrading

Change `nomatron_version` and redeploy. Nomad performs a rolling update when `count > 1`.

---

## Nomad client sizing (cloud)

Starting points for dedicated clients (2 vCPU, 4 GiB RAM minimum per node):

| Profile | Nomatron servers | AWS (example) | GCP | Azure |
|---|---|---|---|---|
| **production** | 1 | `t3.large` / `m7i.large` | `e2-standard-2` | `Standard_D2s_v5` |
| **ha** | 3 | `m7i.large` × 3 | `e2-standard-2` × 3 | `Standard_D2s_v5` × 3 |
| **quickstart** | 1 | `t3.large` | `e2-standard-2` | `Standard_D2s_v5` |

Full platform guides: [docs](https://github.com/nomatronio/nomatron-pack/tree/main/docs/README.md).

---

## Security notes

- Use BYODB with TLS (`sslmode=require`) in production
- Do not use provisioned Postgres outside demo/lab
- Keep encryption keys in a secret manager; HA nodes share the same key
- Set `server.api_addr` to the URL users and webhooks use

---

## License

This pack is [MPL-2.0](https://github.com/nomatronio/nomatron-pack/blob/main/LICENSE). Deploying Nomatron requires a valid [Nomatron license key](https://nomatron.io) in `secrets.license_key`.

## References

- [nomatron-pack README](https://github.com/nomatronio/nomatron-pack/blob/main/README.md) — install and use nomad-pack
- [Platform setup guides](https://github.com/nomatronio/nomatron-pack/tree/main/docs)
- [Nomad Pack documentation](https://developer.hashicorp.com/nomad/tools/nomad-pack)
- [Nomatron AWS reference architecture](https://github.com/nomatronio/reference-architecture/tree/main/aws)
- [Nomatron container images](https://github.com/nomatronio/nomatron-releases)
