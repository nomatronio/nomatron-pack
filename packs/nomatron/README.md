# Nomatron Nomad Pack

Deploy [Nomatron](https://nomatron.io) on HashiCorp Nomad with flexible runtime, database, HA, and load balancer options.

Nomatron is an operational control plane for HashiCorp Nomad. This pack deploys the Nomatron server — not application workloads managed by Nomatron.

This pack is the **primary deployment mechanism** and **reference architecture** for running Nomatron on Nomad.

## Install and use nomad-pack

Nomatron is deployed with the **[nomad-pack](https://developer.hashicorp.com/nomad/tools/nomad-pack)** CLI — a templating tool that renders Nomad job specifications from this pack and registers them with your cluster.

### 1. Install the CLI

Download a release for your platform from [HashiCorp Releases (`nomad-pack`)](https://releases.hashicorp.com/nomad-pack/), unzip it, and put `nomad-pack` on your `PATH`.

macOS (Homebrew):

```bash
brew tap hashicorp/tap
brew install nomad-pack
```

Verify:

```bash
nomad-pack version
```

Full install options: [Nomad Pack documentation](https://developer.hashicorp.com/nomad/tools/nomad-pack).

### 2. Connect to your Nomad cluster

From a machine that can reach your Nomad servers:

```bash
export NOMAD_ADDR=https://nomad.example.com:4646   # your Nomad HTTP API
export NOMAD_TOKEN=<token>                          # required when ACLs are enabled

nomad node status    # confirm connectivity
```

You need permission to register jobs in the target namespace (default `default`).

### 3. Get this pack

**The Nomatron pack is not yet in the HashiCorp community registry** (a PR is planned). When you first run `nomad-pack list`, the CLI downloads the [Nomad Pack Community Registry](https://github.com/hashicorp/nomad-pack-community-registry) (nginx, hello-world, traefik, etc.) — Nomatron will appear there after publish. Until then, use clone or custom registry below.

Use one of these methods:

#### Option A — Clone and run locally (recommended)

```bash
git clone https://github.com/nomatronio/nomatron-pack.git
cd nomatron-pack/packs/nomatron

nomad-pack info .          # show pack name, version, all variables
```

All commands below use `.` to mean “this pack directory”. From the repo root you can also pass `packs/nomatron`.

#### Option B — Add as a custom registry

Useful for CI/CD or when you do not want a full git clone on deploy hosts:

```bash
nomad-pack registry add nomatronio \
  github.com/nomatronio/nomatron-pack \
  --target=nomatron

nomad-pack list --registry=nomatronio
nomad-pack info nomatron --registry=nomatronio
```

Pin a git tag or SHA when you tag releases:

```bash
nomad-pack registry add nomatronio \
  github.com/nomatronio/nomatron-pack \
  --target=nomatron \
  --ref=v0.2.0
```

Then run with `--registry=nomatronio` and the pack name `nomatron` instead of `.`:

```bash
nomad-pack run nomatron --registry=nomatronio --var-file=production.vars.hcl
```

List configured registries:

```bash
nomad-pack registry list
```

### 4. Create your variables file

Example var files live in the [nomatron-pack repository](https://github.com/nomatronio/nomatron-pack/tree/main/examples) (`examples/` at repo root — not inside the cached pack). **Clone the repo**, copy one to a `*.vars.hcl` file, and edit it:

```bash
git clone https://github.com/nomatronio/nomatron-pack.git
cd nomatron-pack/packs/nomatron
cp ../../examples/production.byodb.vars.hcl.example production.vars.hcl
# Edit: database writer URL, secrets, public_hostname, node_pool, constraints
```

| Profile | Start from |
|---|---|
| Production (single node + BYODB, Docker) | [production.byodb.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/production.byodb.vars.hcl.example) |
| Production (single node + BYODB, binary/exec) | [production.byodb.binary.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/production.byodb.binary.vars.hcl.example) |
| HA (3+ servers + BYODB) | [ha.byodb.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/ha.byodb.vars.hcl.example) |
| Lab / demo (provisioned Postgres) | [provision.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/provision.vars.hcl.example) |
| Dedicated client placement | merge [dedicated-nodes.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/dedicated-nodes.vars.hcl.example) |

Inspect all variables and defaults:

```bash
nomad-pack info .
```

### 5. Plan and deploy

Always **plan** before **run** to catch placement and validation errors:

```bash
# From the packs/nomatron/ directory
nomad-pack plan --var-file=production.vars.hcl .
nomad-pack run  --var-file=production.vars.hcl .
```

Override individual values without editing the file:

```bash
nomad-pack run --var-file=production.vars.hcl --var='count=3' .
```

After deploy, check Nomad:

```bash
nomad job status nomatron
nomad-pack status
```

### 6. Other nomad-pack commands

| Command | Purpose |
|---|---|
| `nomad-pack info .` | Pack metadata and variable reference |
| `nomad-pack render --var-file=... .` | Print rendered Nomad job HCL (debugging, review) |
| `nomad-pack status` | List pack deployments registered with this CLI |
| `nomad-pack destroy nomatron` | Tear down jobs created by a pack deployment |
| `nomad-pack fmt .` | Format pack templates |

Pack outputs (URLs, next steps) print to the terminal after a successful `run`. Re-run with the same `--var-file` to upgrade Nomatron after changing `nomatron_version`.

### Quick deploy by profile

Production:

```bash
cp ../../examples/production.byodb.vars.hcl.example production.vars.hcl
# Edit database writer URL, secrets, public_hostname / api_addr
nomad-pack plan --var-file=production.vars.hcl .
nomad-pack run  --var-file=production.vars.hcl .
```

HA:

```bash
cp ../../examples/ha.byodb.vars.hcl.example ha.vars.hcl
# Edit database writer URL, serf.retry_join, secrets
nomad-pack plan --var-file=ha.vars.hcl .
nomad-pack run  --var-file=ha.vars.hcl .
```

Prepare Nomad clients first: [https://github.com/nomatronio/nomatron-pack/tree/main/docs/README.md](https://github.com/nomatronio/nomatron-pack/tree/main/docs/README.md).

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

| Profile | Example vars file | Postgres | Nomatron | Use when |
|---|---|---|---|---|
| **`quickstart`** | [provision.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/provision.vars.hcl.example) | Provisioned, colocated (`count=1`) or lab HA (`count>1`) | 1 or more | First eval, homelab, demos |
| **`production`** | [production.byodb.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/production.byodb.vars.hcl.example) | **BYODB** — HA writer URL, TLS | 1 server (Docker) | Production single-node, container runtime OK |
| **`production`** (binary) | [production.byodb.binary.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/production.byodb.binary.vars.hcl.example) | **BYODB** | 1 server (exec) | Production single-node, **no Docker** for Nomatron |
| **`ha`** | [ha.byodb.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/ha.byodb.vars.hcl.example) | **BYODB** — shared writer URL, TLS | 3+ servers, spread, Serf | Production Nomatron HA |

Set `deployment_profile` in your vars file. The pack **validates** profile constraints at render time (for example, `production` rejects provisioned Postgres).

**Lab Nomatron HA without external Postgres:** use [ha.provision-lab.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/ha.provision-lab.vars.hcl.example) (`deployment_profile=quickstart`, `count>1`, provision mode) — explicitly not for production.

### Decision guide

| Question | Answer |
|---|---|
| Production? | `deployment_profile=production` or `ha` + **BYODB** |
| Docker required on clients? | **No** for production BYODB if `runtime=binary` — see [Runtime options](#runtime-options) |
| Need multiple Nomatron servers? | `deployment_profile=ha`, `count≥3`, Serf config |
| Just trying Nomatron? | `deployment_profile=quickstart`, `database_mode=provision` |
| Postgres HA / failover? | Your managed DB or Patroni — point `database.connection_string` at the **writer** |
| Older Nomad + Consul? | `service_provider=consul` (see [Nomad version requirements](#nomad-version-requirements)) |

## Prerequisites

- **Nomad 1.6+** cluster with **Linux clients** for production and for `network_mode=bridge` — see [Nomad version requirements](#nomad-version-requirements)
- **Platform setup:** step-by-step VM, VPC/VNet, firewall, Docker, and CNI guides for [AWS, Azure, GCP, Proxmox, OpenStack, and VMware](https://github.com/nomatronio/nomatron-pack/tree/main/docs/README.md)
- **Dedicated Nomad clients:** [node_pool, client meta, and pack constraints](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/dedicated-nodes-and-placement.md) — required for production on shared clusters
- **Load balancing:** [ALB vs Traefik vs direct access](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/load-balancing.md)
- For `runtime=docker`: Docker driver enabled on clients
- For `runtime=binary`: **exec** driver enabled on clients; Docker **not** required for Nomatron (still required for `database_mode=provision` Postgres and `load_balancer_mode=traefik`)
- **CNI bridge plugin** (required when `network_mode=bridge`) — the default for `database_mode=provision` and for Linux production deployments. Nomad uses [bridge CNI plugins](https://developer.hashicorp.com/nomad/docs/networking/cni) (version **≥ 0.4.0**) on **Linux** clients. CNI plugins are **not available on macOS**; see [macOS dev mode](#macos-dev-mode-nomad-agent--dev) below.
- Host volumes supported when using `database_mode=provision`
- Optional: Nomad or Consul service registration for load balancer integration (`service_provider`)

### Nomad version requirements

The pack targets **Nomad 1.6+** on Linux clients with bridge CNI. Older clusters may work for some modes but are unsupported.

| Deployment | Minimum Nomad | Notes |
|---|---|---|
| Single node (`count=1`) — BYODB or colocated provision | **1.6+** | Bridge CNI, dynamic or static ports, bootstrap health checks |
| HA BYODB (`count > 1`, external Postgres) | **1.6+** | Spread across clients, Serf gossip, rolling updates |
| HA provision (`count > 1`, pack-managed Postgres) | **1.6+** (Consul: any Nomad with working Nomad–Consul integration) | One Postgres task; Nomatron servers resolve it via template — [`nomadService`](https://developer.hashicorp.com/nomad/docs/job-specification/template#nomadservice) when `service_provider=nomad` (Nomad 1.3+), or [`service`](https://developer.hashicorp.com/nomad/docs/job-specification/template#service) when `service_provider=consul` |

**Provision HA specifics:** Postgres registers using `service_provider` (`nomad` or `consul`). Nomatron server configs use a runtime template to build the database connection string from `postgres.service_name` (default `nomatron-postgres`):

- **`service_provider = "nomad"`** (default) — `nomadService` (Nomad native catalog; requires Nomad 1.3+)
- **`service_provider = "consul"`** — `service` (Consul catalog; typical for older Nomad clusters that already run Consul)

#### Using Consul for service registration

The pack variable `service_provider` controls where **service** blocks register and which template resolves provision HA Postgres:

| `service_provider` | Load balancer tags (Traefik/Fabio) | Provision HA Postgres discovery (`count > 1`) |
|---|---|---|
| **`nomad`** (default) | Nomad-native catalog / compatible LB setups | `nomadService` → `postgres.service_name` |
| **`consul`** | Consul catalog for LB integration | `service` → `postgres.service_name` |

For **Consul-backed clusters** (common on older Nomad), set `service_provider = "consul"`. Nomad clients must have [Consul integration](https://developer.hashicorp.com/nomad/docs/configuration/consul) configured so services register and templates can query the catalog.

**Older Nomad without native service discovery (< 1.3):** use `service_provider = "consul"` for provision HA, or BYODB / `count=1` colocated provision. Single-node and BYODB HA work without `nomadService`.

### CNI setup (Linux clients)

For full client preparation (Docker, CNI, Nomad config, firewall), see [https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/nomad-client-setup.md](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/nomad-client-setup.md) and your [platform guide](https://github.com/nomatronio/nomatron-pack/tree/main/docs/README.md).

Install the CNI plugins on each **Linux** Nomad client and point Nomad at the plugin directory.

```bash
sudo mkdir -p /opt/cni/bin
curl -L https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-amd64-v1.6.0.tgz \
  | sudo tar -C /opt/cni/bin -xz
```

On arm64 Linux clients, use `cni-plugins-linux-arm64-v1.6.0.tgz` instead.

Ensure the Nomad client configuration includes:

```hcl
client {
  cni_path = "/opt/cni/bin"
}
```

Restart Nomad after installing plugins. Verify bridge CNI is available:

```bash
nomad node status -self
```

Look for `plugins.cni.version.bridge` in the node attributes, or confirm the node is not excluded when you run `nomad-pack plan`.

### macOS dev mode (`nomad agent -dev`)

You **cannot** install working CNI bridge plugins on macOS. CNI binaries are Linux-only; installing them on a Mac produces `exec format error` and Nomad will not detect bridge CNI.

For local pack testing on a Mac, use **BYODB** with **`network_mode=standard`** (avoids bridge CNI) and an external Postgres reachable from Docker containers:

1. Install Docker Desktop and ensure it is running.
2. Start Postgres on the Mac host:

```bash
docker run -d --name nomatron-postgres \
  -e POSTGRES_DB=nomatron \
  -e POSTGRES_USER=nomatron \
  -e POSTGRES_PASSWORD=nomatron \
  -p 5432:5432 \
  postgres:16
```

3. Copy the example variables file, fill in secrets once, and start Nomad dev mode:

```bash
cp ../../examples/mac-dev.vars.hcl.example mac-dev.vars.hcl
# Edit mac-dev.vars.hcl — set encryption_key, license_key, cluster_key

nomad agent -dev
export NOMAD_ADDR=http://127.0.0.1:4646
```

4. Plan and deploy:

```bash
nomad-pack plan -var-file=mac-dev.vars.hcl .
nomad-pack run  -var-file=mac-dev.vars.hcl .
```

On macOS, `nomad agent -dev` exposes very little schedulable CPU (often ~28 MHz). If placement fails with **cpu exhausted**, check capacity with `nomad node status -self` and set `nomatron_resources.cpu` below the available total (for example `25`).

Use the same `secrets.license_key` and `secrets.cluster_key` values as your working deployment (for example the AWS reference architecture). A placeholder `cluster_key` such as `dev` will fail connected licensing even with a valid license key. The pack defaults `licensing.keygen_base_url` to `https://api.keygen.sh`, matching the AWS module.

Keep `secrets.encryption_key` stable across redeploys when reusing the same Postgres database. The README examples previously used `$(openssl rand -base64 32)` inline on every run, which changes the key each deploy and causes `cipher: message authentication failed` when Nomatron tries to decrypt the JWT signing key stored in the database. If that happens, either reuse the original encryption key or reset Postgres (`docker rm -f nomatron-postgres` and recreate the container), then deploy again with a new stable key.

`database_mode=provision` requires `network_mode=bridge` and a **Linux** Nomad client with CNI installed. It does not work on macOS dev mode.

### Local testing on Linux (`nomad agent -dev`)

Dev mode on **Linux** still requires CNI for `network_mode=bridge` (including `database_mode=provision`):

1. Install Docker and CNI plugins (see above).
2. Start Nomad with `client.cni_path` configured.
3. Run plan/deploy as in the quickstart or production sections below.

## Database choice

| Mode | Variable | When to use |
|---|---|---|
| **BYODB** | `database_mode=byodb` | **Production and HA** — RDS, Cloud SQL, Patroni leader, PgBouncer, any HA Postgres **writer** |
| **Provision** | `database_mode=provision` | **Quickstart / lab only** — colocated Postgres or lab multi-server HA |

Provisioned Postgres is **not for production**. The reference architecture uses BYODB with `sslmode=require` and a writer endpoint that survives DB failover (managed HA or Patroni).

See [production.byodb.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/production.byodb.vars.hcl.example) and [ha.byodb.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/ha.byodb.vars.hcl.example).

### BYODB connection

Point at the **writer** endpoint — not a read replica. Nomatron uses a single connection string for all servers.

```bash
cp ../../examples/production.byodb.vars.hcl.example production.vars.hcl
nomad-pack run -var-file=production.vars.hcl .
```

Pool sizing rule of thumb: `(count × max_open_conns) + headroom < postgres max_connections` (defaults: 25 open / 10 idle per Nomatron server).

## Quickstart (provisioned Postgres)

Demo/lab deployment with colocated Postgres. **Requires a Nomad host volume** on the client — container filesystem alone is ephemeral.

### 1. Register a host volume on the Nomad client

Postgres data must live on a **host volume**: a directory on the Nomad client that is bind-mounted into the Postgres container at `/var/lib/postgresql/data`.

On each client that may run the job:

```bash
sudo mkdir -p /opt/nomad/volumes/nomatron-postgres
sudo chown nomad:nomad /opt/nomad/volumes/nomatron-postgres
```

Add to the client's `client` block (see [nomad-client-host-volume.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/nomad-client-host-volume.hcl.example)):

```hcl
client {
  host_volume "nomatron-postgres" {
    path      = "/opt/nomad/volumes/nomatron-postgres"
    read_only = false
  }
}
```

Restart the Nomad client, then verify:

```bash
nomad node status -verbose
# HostVolumes should list nomatron-postgres
```

**Important:** `postgres.volume_path` in the pack is the **host volume name** (`nomatron-postgres`), not the filesystem path. The path is configured on the client. If the name does not match a registered host volume, placement fails with `missing compatible host volumes`.

### 2. Deploy

```bash
cp ../../examples/provision.vars.hcl.example provision.vars.hcl
# edit provision.vars.hcl — secrets, node_pool if needed

nomad-pack run -var-file=provision.vars.hcl .
```

Or inline:

```bash
nomad-pack run \
  -var database_mode=provision \
  -var 'postgres={"image_tag":"16","db_name":"nomatron","username":"nomatron","password":"nomatron","volume_path":"nomatron-postgres","cpu":500,"memory":1024}' \
  -var 'secrets={"encryption_key":"'"$(openssl rand -base64 32)"'","license_key":"'"$NOMATRON_LICENSE_KEY"'","cluster_key":"'"$NOMATRON_CLUSTER_KEY"'"}' \
  .
```

After deploy, open `/ui/setup` to initialize the database.

### Persistence behaviour

| Event | Data survives? |
|---|---|
| Task restart | Yes — same allocation, same host mount |
| Job redeploy (same node) | Yes — data remains in `/opt/nomad/volumes/nomatron-postgres` |
| Allocation moved to another node | **Only if** that node has the same host volume at the same path (or you restore from backup) |
| Delete host directory | No — data loss |

For production, use `database_mode=byodb` with managed or dedicated Postgres instead.

## Production

Use the reference vars file — do not use `database_mode=provision` in production.

```bash
cp ../../examples/production.byodb.vars.hcl.example production.vars.hcl
# Edit: database.connection_string (writer URL), secrets, server.api_addr / public_hostname
nomad-pack run -var-file=production.vars.hcl .
```

With Traefik bundled:

```bash
nomad-pack run -var-file=production.vars.hcl -var load_balancer_mode=traefik .
```

## High availability

Nomatron HA = `deployment_profile=ha` + BYODB + `count≥3` + Serf. Postgres HA is your responsibility via the writer endpoint.

```bash
cp ../../examples/ha.byodb.vars.hcl.example ha.vars.hcl
# Edit: database writer URL, serf.retry_join (one entry per node), serf.encrypt_key, secrets
nomad-pack run -var-file=ha.vars.hcl .
```

Generate a Serf encryption key:

```bash
nomatron keygen
```

### Lab: Nomatron HA with provisioned Postgres

For evaluation only — **not** `deployment_profile=ha`:

```bash
cp ../../examples/ha.provision-lab.vars.hcl.example ha-lab.vars.hcl
nomad-pack run -var-file=ha-lab.vars.hcl .
```

See [Nomad version requirements](#nomad-version-requirements) for Consul vs Nomad service discovery.

## Runtime options

Nomatron supports two runtimes. **Docker is the default** for quickstart and teams already running containers. **Binary + exec** is the recommended alternative for production control-plane nodes when Docker is undesirable — same model as the [AWS reference architecture](https://github.com/nomatronio/reference-architecture/tree/main/aws) (Nomatron installed via apt, not pulled as an image).

| | `runtime=docker` | `runtime=binary` |
|---|---|---|
| Nomad driver | Docker | **exec** |
| Docker on client | **Required** | **Not required** (Nomatron task only) |
| Version pin | Image tag (`nomatron_version`) | Host package/tarball + `nomatron_version` for audit |
| Production example | `production.byodb.vars.hcl.example` | `production.byodb.binary.vars.hcl.example` |
| CNI (`network_mode=bridge`) | Required | Required |

**When companies choose binary/exec:** container policy on control-plane hosts, apt/config-mgmt ownership of the binary, air-gapped installs (`binary_install_method=host`), reduced attack surface (no Docker socket for Nomatron).

**Still needs Docker:** `database_mode=provision` (Postgres task), `load_balancer_mode=traefik` (Traefik task). Production BYODB + cloud LB + `runtime=binary` avoids Docker entirely on Nomatron clients.

### Docker (default)

Uses `ghcr.io/nomatronio/nomatron-releases/nomatron:<version>`.

```bash
cp ../../examples/production.byodb.vars.hcl.example production.vars.hcl
nomad-pack run --var-file=production.vars.hcl .
```

Or override:

```bash
--var='runtime=docker' --var='nomatron_version=v0.1.0-rc.21'
```

### Binary / exec (production BYODB)

**Pre-installed binary** (recommended — install via [packages.nomatron.io](https://packages.nomatron.io/apt) or golden AMI before deploy):

```bash
cp ../../examples/production.byodb.binary.vars.hcl.example production.vars.hcl
# Install nomatron on each client, e.g.:
#   curl -fsSL https://packages.nomatron.io/apt/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/nomatron.gpg
#   echo "deb [signed-by=...] https://packages.nomatron.io/apt stable main" | sudo tee /etc/apt/sources.list.d/nomatron.list
#   sudo apt-get update && sudo apt-get install -y nomatron
nomad-pack plan --var-file=production.vars.hcl .
nomad-pack run  --var-file=production.vars.hcl .
```

Key vars:

```hcl
runtime               = "binary"
binary_install_method = "host"
binary_path           = "/usr/bin/nomatron"
nomatron_version      = "v0.1.0-rc.21"   # match installed package version
```

Ensure the Nomad client enables the **exec** driver (`plugin "exec" { config {} }`).

**Download artifact per allocation** (needs outbound access to GitHub releases):

```hcl
runtime               = "binary"
binary_install_method = "artifact"
binary_arch           = "amd64"   # or arm64
nomatron_version      = "v0.1.0-rc.21"
```

For HA with binary runtime, use [ha.byodb.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/ha.byodb.vars.hcl.example) and add the same `runtime` / `binary_*` settings.

## Load balancer

See **[https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/load-balancing.md](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/load-balancing.md)** for the full decision guide. Summary:

| Mode | When to use | Traefik/Fabio? |
|---|---|---|
| **`none`** + `http_port_static=4649` | Cloud LB (ALB, App Gateway, GLB) or homelab direct IP | **No** |
| **`service`** | Traefik/Fabio already running on Nomad | Yes (existing) |
| **`traefik`** | Want the pack to deploy Traefik | Yes (pack installs) |

**Cloud production default:** ALB → each Nomad client on **4649** — you do **not** need Traefik.

For `load_balancer_mode=service`, set `public_hostname` to generate router tags and derive `api_addr`:

```bash
-var load_balancer_mode=service \
-var public_hostname=nomatron.example.com \
-var public_scheme=https
```

For `load_balancer_mode=traefik`, the pack deploys a self-contained Traefik system job alongside Nomatron:

```bash
nomad-pack run -var load_balancer_mode=traefik -var-file=production.vars.hcl .
```

## Required secrets

| Variable | Description |
|---|---|
| `secrets.encryption_key` | 32-byte key for encrypting operational secrets (`openssl rand -base64 32`). Must stay the same for the lifetime of a database — do not regenerate on each redeploy. |
| `secrets.license_key` | Nomatron license key |
| `secrets.cluster_key` | Nomatron cluster key (must match the value used when the license was issued / your other environments) |
| `serf.encrypt_key` | Serf gossip encryption key (`nomatron keygen` or `openssl rand -base64 24`). Required when `count > 1`. Must be identical on every Nomatron node and stable across redeploys for that cluster. |

Pass secrets via `-var-file` (recommended) or `-var` at deploy time. Do not commit real values. See [production.byodb.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/production.byodb.vars.hcl.example) and [mac-dev.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/blob/main/examples/mac-dev.vars.hcl.example).

### Keep secrets stable across redeploys

Generate each value **once**, save in your `-var-file`, and reuse on every deploy:

```bash
# In mac-dev.vars.hcl (or production.vars.hcl / ha.vars.hcl):
# encryption_key = "<output of: openssl rand -base64 32>"
# license_key    = "..."
# cluster_key    = "nomatron-cluster-key"
# serf.encrypt_key = "<output of: nomatron keygen>"   # HA only
```

| Secret | Stored in Postgres? | When it must stay stable |
|---|---|---|
| `secrets.encryption_key` | Yes (encrypts JWT signing key and other secrets) | Same DB = same key forever |
| `secrets.cluster_key` | Licensing state | Same license / environment |
| `serf.encrypt_key` | No (Serf config only) | All HA nodes must share one key; changing it breaks gossip with peers on the old key |

For **Mac dev with `count=1`**, the pack does not emit `serf.encrypt_key` — you only need stable `encryption_key`, `license_key`, and `cluster_key` today. When you move to HA, add a fixed `serf.encrypt_key` the same way as the AWS module (`serf_encrypt_key` in tfvars).

## Key variables

### Top-level

- `deployment_profile` — `quickstart`, `production`, or `ha` (validated — see [Reference architecture](#reference-architecture))
- `database_mode` — `byodb` (production) or `provision` (lab)
- `runtime` — `docker` or `binary`
- `load_balancer_mode` — `none`, `service`, or `traefik`
- `nomatron_version` — release tag (default `v0.1.0-rc.20`)
- `count` — server instances (1 for quickstart; 2+ for HA)

### Placement (dedicated clients)

- `node_pool` — must match `client { node_pool = "..." }` on dedicated VMs ([guide](https://github.com/nomatronio/nomatron-pack/tree/main/docs/common/dedicated-nodes-and-placement.md))
- `constraints` — job rules matching client `meta` (e.g. `${meta.nomatron} = true`)
- `datacenters` — optional datacenter pin

See [dedicated-nodes.vars.hcl.example](https://github.com/nomatronio/nomatron-pack/tree/main/examples/dedicated-nodes.vars.hcl.example).

### Server (`server` object)

- `port` (4649), `api_addr`, `trusted_origins`, `log_level`, `log_format`
- HTTP timeouts, TLS settings

### Database (`database` object)

- `connection_string` or `host`/`port`/`name`/`username`/`password`/`sslmode`
- Connection pool settings

### Postgres provision (`postgres` object, `database_mode=provision` only)

- `image_tag`, `db_name`, `username`, `password`, resources
- `volume_path` — **Nomad host volume name** (default `nomatron-postgres`); register on the client with `host_volume` — see [Quickstart (provisioned Postgres)](#quickstart-provisioned-postgres)
- `service_name` — Consul/Nomad service name for HA discovery (default `nomatron-postgres`)
- `host_port` — host port for Postgres when `count > 1` (default `5432`); must be reachable from other Nomad clients in the pool

### Serf / HA (`serf` object)

- `encrypt_key`, `retry_join`, `advertise_addr`, `port` (7946)

### Bootstrap (`bootstrap` object)

- `root_username`, `root_password`
- `auto_init_database` — headless init for BYODB single-node only

## Ports

| Port | Purpose |
|---|---|
| 4649 | HTTP API and Web UI |
| 4650 | Agent gRPC |
| 7946 | Serf gossip (HA) |

Health check path: `/api/v1/health?bootstrap=ok`

## Upgrading

Change `nomatron_version` and redeploy. Nomad performs a rolling update when `count > 1`.

## Nomad client sizing (cloud)

**Platform setup (VPC, firewall, Docker, CNI):** [https://github.com/nomatronio/nomatron-pack/tree/main/docs/README.md](https://github.com/nomatronio/nomatron-pack/tree/main/docs/README.md) — step-by-step guides for AWS, Azure, GCP, Proxmox, OpenStack, and VMware.

Include **starting-point VM sizes** for dedicated Nomad clients — not a full cloud catalog. Sizes derive from pack defaults (`nomatron_resources`: 1000 MHz CPU, 2048 MiB memory per Nomatron server) plus headroom for the Nomad agent, Docker, and CNI.

**Gold standard:** dedicate Nomad clients to Nomatron for production/HA (one Nomatron allocation per client when `count > 1` so spread works). Run PostgreSQL **off** these nodes (`database_mode=byodb`). On shared Nomad clusters, add capacity for your other workloads on top of these baselines.

| Profile | Nomatron servers | Dedicated clients | Minimum per client | AWS (example) | GCP (example) | Azure (example) |
|---|---:|---:|---|---|---|---|
| **production** | 1 | 1 | 2 vCPU, 4 GiB RAM | `t3.large`, [`m7i.large`](https://github.com/nomatronio/reference-architecture/tree/main/aws) | `e2-standard-2` | `Standard_D2s_v5` |
| **ha** | 3 (recommended) | 3 (one per AZ/node) | 2 vCPU, 4 GiB RAM | `m7i.large` × 3 (AWS ref arch default) | `e2-standard-2` × 3 | `Standard_D2s_v5` × 3 |
| **quickstart** (provision) | 1 | 1 | 2 vCPU, 4 GiB RAM | `t3.large` | `e2-standard-2` | `Standard_D2s_v5` |

Verify schedulable capacity before deploy:

```bash
nomad node status -self
# Ensure available CPU (MHz) > nomatron_resources.cpu and memory > nomatron_resources.memory
```

Scale up when you observe sustained CPU/memory pressure, large numbers of organizations/clusters, or heavy concurrent plan/apply activity. The [Nomatron AWS reference architecture](https://github.com/nomatronio/reference-architecture/tree/main/aws) uses **`m7i.large`** for a three-node HA control plane — align Nomad client sizing with that where you deploy Nomatron on Nomad instead of EC2 ASG.

For full cloud stacks (VPC, load balancer, RDS, secrets), use provider reference modules rather than sizing Postgres or networking in this pack.

## Security notes

- Use BYODB with TLS (`sslmode=require` or stricter) in production
- Do not use provisioned Postgres outside demo/lab environments
- Keep `NOMATRON_ENCRYPTION_KEY` in a secret manager; all HA nodes must share the same key
- Set `server.api_addr` to the URL users and webhooks use to reach Nomatron

## License

This pack is licensed under the [Mozilla Public License 2.0](https://github.com/nomatronio/nomatron-pack/blob/main/LICENSE) (MPL-2.0), the same license as the [Nomad Pack Community Registry](https://github.com/hashicorp/nomad-pack-community-registry).

**Nomatron the product** (server binaries, UI, commercial license) is separate from **this Nomad pack** — deploying Nomatron still requires a valid [Nomatron license key](https://nomatron.io) in your vars file (`secrets.license_key`).

## References

- [Platform setup guides](https://github.com/nomatronio/nomatron-pack/tree/main/docs) — AWS, Azure, GCP, Proxmox, OpenStack, VMware (maintained in the nomatron-pack repository)
- [Nomad Pack documentation](https://developer.hashicorp.com/nomad/tools/nomad-pack) — install, commands, registries
- [Nomad Pack Community Registry](https://github.com/hashicorp/nomad-pack-community-registry) — default registry (nginx, traefik, etc.; Nomatron pending publish)
- [nomatronio/nomatron-pack](https://github.com/nomatronio/nomatron-pack) — source repository (clone or add as custom registry)
- [Nomatron AWS reference architecture](https://github.com/nomatronio/reference-architecture/tree/main/aws) — EC2 sizing, RDS, ALB (parallel path to this Nomad pack)
- [Nomatron container images](https://github.com/nomatronio/nomatron-releases)
