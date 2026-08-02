# Proxmox — Nomad client setup for Nomatron

Prepare **QEMU/KVM Linux VMs** on Proxmox VE as Nomad clients for the Nomatron Nomad pack. Typical for homelab and on-prem deployments.

**Read first:** [Dedicated nodes](../common/dedicated-nodes-and-placement.md) · [Load balancing](../common/load-balancing.md) · [Nomad client setup](../common/nomad-client-setup.md) · [Ports](../common/ports-and-firewall.md)

## 1. VM sizing

| Profile | VMs | vCPU / RAM / disk |
|---|---|---|
| quickstart / lab | 1 | 2 vCPU, 8 GiB RAM, 32 GiB disk |
| production | 1 | 2 vCPU, 8 GiB RAM, 40 GiB disk |
| ha | 3 | 2 vCPU, 8 GiB RAM each (spread across Proxmox nodes if possible) |

Use **Ubuntu 24.04** or **Debian 12** cloud image. Enable **QEMU guest agent** for clean shutdowns.

## 2. Network layout

### Linux bridge (recommended)

Proxmox creates `vmbr0` bridged to a physical NIC. VMs get IPs on your LAN (e.g. `192.168.x.x`).

```text
[ Router / firewall ]
        │
   vmbr0 (192.168.3.0/24)
        │
   ├── nomad-client-01  192.168.3.11
   ├── nomad-client-02  192.168.3.12   (HA)
   └── postgres-host    192.168.3.130   (BYODB — can be VM or bare metal)
```

For HA, ensure all Nomad clients are **L2-adjacent** (same VLAN/bridge) so Serf gossip on **7946** works without NAT.

### VLAN (optional)

If isolating Nomad traffic:

1. Create VLAN-aware bridge `vmbr0` or dedicated `vmbr1` for VLAN ID (e.g. 100).
2. Assign VM NIC to that bridge/tag.
3. Route or firewall between VLANs for admin access and Postgres.

## 3. Firewall rules

Proxmox host firewall and/or upstream router/firewall must allow:

### Between Nomad clients (HA)

| Port | Protocol | Purpose |
|---|---|---|
| 7946 | TCP + UDP | Serf cluster gossip |
| 4649 | TCP | Nomatron HTTP (if direct access between nodes) |

### From users / admin

| Port | Protocol | Purpose |
|---|---|---|
| 4649 | TCP | Nomatron API (or via reverse proxy) |
| 22 | TCP | SSH admin |
| 4646 | TCP | Nomad UI/API (operators only) |

### To PostgreSQL (BYODB)

| Port | Protocol | Source | Purpose |
|---|---|---|---|
| 5432 | TCP | Nomad client IPs | Database |

**Proxmox datacenter firewall:** if enabled, add rules on the VM or security group level. Example (iptables on each VM via `ufw`):

```bash
sudo ufw allow from 192.168.3.0/24 to any port 7946
sudo ufw allow 4649/tcp
sudo ufw allow out 5432/tcp
```

## 4. Create VMs

In Proxmox UI or via Terraform (e.g. bpg/proxmox provider):

1. **Clone** from Ubuntu cloud template or ISO install.
2. **CPU:** 2 cores, type `host` or `x86-64-v2-AES`.
3. **Memory:** 8192 MiB; disable ballooning for predictable Nomad scheduling.
4. **Disk:** virtio-scsi, discard enabled, 32+ GiB on local-lvm or Ceph.
5. **Network:** virtio, bridge `vmbr0`, firewall enabled if using Proxmox FW.
6. **Cloud-init:** set hostname, SSH key, static IP or DHCP reservation.

Repeat for HA with distinct hostnames: `nomad-client-01`, `02`, `03`.

## 5. Install software

SSH to each VM and complete [common/nomad-client-setup.md](../common/nomad-client-setup.md):

```bash
# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker nomad

# CNI
CNI_VERSION=v1.6.0
sudo mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz" \
  | sudo tar -C /opt/cni/bin -xz
```

### Nomad client config (dedicated nodes)

Proxmox VMs typically use `eth0` or `ens18`:

```hcl
client {
  enabled  = true
  cni_path = "/opt/cni/bin"
  node_pool = "nomatron"   # homelab shared cluster: e.g. "infra"

  meta {
    nomatron = "true"
  }

  host_network "default" {
    interface = "ens18"
  }
}
```

Pack vars must match (`node_pool` + `constraints`) — see [dedicated-nodes-and-placement.md](../common/dedicated-nodes-and-placement.md).

Restart: `sudo systemctl restart nomad`

### Host volume (provision / lab only)

If running pack-managed Postgres on a client, register host volume — see [../../examples/nomad-client-host-volume.hcl.example](../../examples/nomad-client-host-volume.hcl.example).

## 6. PostgreSQL (BYODB)

Production: run Postgres on a **separate VM** or existing server (not on Nomad clients).

Example homelab setup:

```hcl
database = {
  connection_string = "postgres://nomatron:SECRET@192.168.3.130:5432/nomatron?sslmode=disable"
  sslmode           = "disable"
}
```

Use TLS (`sslmode=require`) when Postgres is configured with certificates.

## 7. HA Serf

```hcl
serf = {
  retry_join  = ["192.168.3.11:7946", "192.168.3.12:7946", "192.168.3.13:7946"]
  encrypt_key = "..."
}
serf_port_static = 7946
```

Ensure firewall allows **7946/tcp+udp** between all client IPs.

## 8. Load balancing (homelab — pick one)

| Option | Pack setting | When |
|---|---|---|
| **Direct IP** | `load_balancer_mode=none`, `http_port_static=4649` | Single node; browse to `http://192.168.3.11:4649` |
| **Reverse proxy** (Caddy/nginx) | `load_balancer_mode=none`, proxy → `:4649` | TLS on a small VM; **no Traefik on Nomad** |
| **Pack Traefik** | `load_balancer_mode=traefik` | Want LB as a Nomad job |
| **Existing Traefik on Nomad** | `load_balancer_mode=service` | Traefik already watches Nomad catalog |

You do **not** need Traefik for a simple homelab direct-IP setup. See [load-balancing.md](../common/load-balancing.md).

## 9. Deploy pack

```bash
cp examples/provision.vars.hcl.example homelab.vars.hcl   # quickstart / lab
nomad-pack run -var-file=homelab.vars.hcl .
```

Set `node_pool` and `constraints` to match client config — merge [dedicated-nodes.vars.hcl.example](../../examples/dedicated-nodes.vars.hcl.example).

## 10. Verify

```bash
nomad node status -self
nomad job status nomatron
curl -s "http://192.168.3.11:4649/api/v1/health?bootstrap=ok"
```
