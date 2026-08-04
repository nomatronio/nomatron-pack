# Nomad client setup (all platforms)

Complete these steps on **every Linux Nomad client** that will run Nomatron. Platform-specific VM and firewall steps are in [../platforms/](../platforms/).

**Also read:**

- [Dedicated nodes — node_pool, meta, constraints](dedicated-nodes-and-placement.md) — **required for production**
- [Load balancing — ALB vs Traefik vs direct](load-balancing.md)

## 1. OS requirements

- **Linux x86_64 or arm64** (match `binary_arch` if using binary runtime)
- **Nomad 1.6+** client already joined to your cluster
- Supported distributions: Ubuntu 22.04/24.04 LTS, Debian 12, RHEL 9 / Rocky 9, Amazon Linux 2023

```bash
sudo apt-get update && sudo apt-get upgrade -y   # Debian/Ubuntu
# or: sudo dnf update -y                         # RHEL/Rocky/AL2023
```

Create a dedicated data directory:

```bash
sudo mkdir -p /opt/nomad/data /opt/nomad/volumes
sudo chown -R nomad:nomad /opt/nomad
```

## 2. Docker

Install Docker Engine when using the Docker Nomad driver (`runtime=docker`) or colocated provision-mode Postgres (`database_mode=provision`).

**Ubuntu / Debian:**

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker nomad
sudo systemctl enable --now docker
docker run --rm hello-world
```

**RHEL / Rocky / Amazon Linux 2023:** use Docker CE or your org-approved container runtime; ensure `nomad` user can access `/var/run/docker.sock`.

Verify from the Nomad client node:

```bash
nomad node status -self | grep -i docker
```

## 2b. Exec driver (required for `runtime=binary`)

Nomatron runs as a host binary via the **exec** driver when **`runtime=binary`** with BYODB — Docker is not used for the Nomatron task itself.

Enable in client config (see [nomad-client.hcl.example](nomad-client.hcl.example)):

```hcl
plugin "exec" {
  config {}
}
```

For **production binary**, install Nomatron on the client before deploy and set `binary_path` in your vars file. The pack can download release tarballs when `binary_install_method=artifact` (client needs outbound HTTPS to GitHub Releases).

```bash
nomad node status -self -verbose | grep -i exec
```

## 3. CNI plugins (required for `network_mode=bridge`)

Required for `database_mode=provision` and most production Linux jobs using `network_mode=bridge`.

```bash
CNI_VERSION=v1.6.0
ARCH=amd64   # or arm64 on Graviton/ARM VMs
sudo mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" \
  | sudo tar -C /opt/cni/bin -xz
ls /opt/cni/bin/bridge /opt/cni/bin/host-local /opt/cni/bin/loopback
```

Add to Nomad client config (see [nomad-client.hcl.example](nomad-client.hcl.example)):

```hcl
client {
  cni_path = "/opt/cni/bin"
}
```

Restart Nomad and verify bridge CNI is detected:

```bash
sudo systemctl restart nomad
nomad node status -self | grep -i cni
```

## 4. Nomad client configuration (dedicated nodes)

Production Nomatron runs on **dedicated clients**. Configure **both** the Nomad agent and the pack vars so the job only lands on those VMs.

### 4a. Client agent (`/etc/nomad.d/client.hcl`)

Use [nomad-client.hcl.example](nomad-client.hcl.example) as the starting point:

```hcl
client {
  enabled  = true
  cni_path = "/opt/cni/bin"

  # Must match pack var node_pool (Enterprise pools; OSS can use "default")
  node_pool = "nomatron"

  # Matched by pack constraints — set ONLY on Nomatron-dedicated clients
  meta {
    nomatron = "true"
    role     = "control"
  }

  host_network "default" {
    interface = "eth0"   # see your platform guide (ens5, ens4, ens192, …)
  }
}
```

Restart Nomad after editing:

```bash
sudo systemctl restart nomad
nomad node status -self -json | jq '.Meta'
```

### 4b. Pack vars (when you deploy)

In `production.vars.hcl` / `ha.vars.hcl`, set matching placement (see [examples/dedicated-nodes.vars.hcl.example](../../examples/dedicated-nodes.vars.hcl.example)):

```hcl
node_pool = "nomatron"

constraints = [
  {
    attribute = "$${meta.nomatron}"
    operator  = "="
    value     = "true"
  }
]
```

Run `nomad-pack plan` and confirm allocations target your dedicated nodes.

Full explanation: [dedicated-nodes-and-placement.md](dedicated-nodes-and-placement.md).

### Host volume (provision mode / lab only)

If using `database_mode=provision`, register a host volume on clients that may run Postgres — see [../../examples/nomad-client-host-volume.hcl.example](../../examples/nomad-client-host-volume.hcl.example).

Enable the **Docker** plugin (default in most installs). For **exec/binary** runtime, ensure the exec driver is enabled.

## 5. Load balancer mode (pack vars — not client config)

How users reach Nomatron is configured in the **pack vars file**, not on the Nomad client. See [load-balancing.md](load-balancing.md).

| Your setup | `load_balancer_mode` | Notes |
|---|---|---|
| Cloud LB (ALB, App Gateway, GLB) | `none` | Set `http_port_static = 4649`; **no Traefik** |
| Traefik/Fabio already on Nomad | `service` | Pack registers service tags |
| Pack installs Traefik | `traefik` | Two jobs deployed |
| Homelab / direct IP | `none` | `http_port_static = 4649` |

## 6. Consul (optional)

Required when `service_provider=consul` (common on older Nomad clusters) or when your LB uses Consul catalog.

Ensure the Nomad client config points at local Consul agents and that services can register. See [HashiCorp Nomad Consul integration](https://developer.hashicorp.com/nomad/docs/configuration/consul).

## 7. Verification

Before deploying the pack:

```bash
# Client is ready and has capacity
nomad node status -self

# Metadata for constraints
nomad node status -self -json | jq '.Meta'

# Docker driver
nomad node status -self -verbose | grep -A3 Drivers

# CNI bridge (Linux)
nomad node status -self -verbose | grep -i bridge

# Schedulable resources vs pack defaults (1000 MHz CPU, 2048 MiB memory)
nomad node status -self -json | jq '.Status.Drivers.Docker.NodeResources'
```

Expected: available CPU ≥ `nomatron_resources.cpu` and memory ≥ `nomatron_resources.memory` from your vars file.

## 8. Deploy the pack

```bash
cd nomatron-pack/packs/nomatron
cp examples/production.byodb.vars.hcl.example production.vars.hcl
# Merge examples/dedicated-nodes.vars.hcl.example for node_pool + constraints
# Edit database writer URL, secrets, public_hostname, load_balancer_mode
nomad-pack plan -var-file=production.vars.hcl .
nomad-pack run  -var-file=production.vars.hcl .
```

See [../README.md](../packs/nomatron/README.md) for profile-specific vars files.
