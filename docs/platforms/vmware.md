# VMware vSphere — Nomad client setup for Nomatron

Prepare **vSphere VMs** as Nomad clients for the Nomatron Nomad pack. Applies to **VMware vSphere** (on-prem or VMC on AWS).

**Read first:** [Dedicated nodes](../common/dedicated-nodes-and-placement.md) · [Load balancing](../common/load-balancing.md) · [Nomad client setup](../common/nomad-client-setup.md) · [Ports](../common/ports-and-firewall.md)

## 1. VM sizing

| Profile | VMs | vCPU / RAM / disk |
|---|---|---|
| production | 1 | 2 vCPU, 8 GiB RAM, 40 GiB thin disk |
| ha | 3 | 2 vCPU, 8 GiB RAM each across ESXi hosts / clusters |

Guest OS: **Ubuntu 24.04 LTS** or **RHEL 9**. Install **open-vm-tools** for IP reporting and graceful shutdown.

## 2. Network layout

### Port groups

```text
vSphere Distributed Switch (or Standard Switch)
├── PG-NOMAD-CLIENTS   VLAN 120   10.30.1.0/24
├── PG-DB              VLAN 121   10.30.2.0/24   (PostgreSQL BYODB)
└── PG-LB              VLAN 122   10.30.3.0/24   (optional NSX / HAProxy / F5)
```

- Attach Nomad client VM NICs to **PG-NOMAD-CLIENTS**.
- PostgreSQL runs on **PG-DB** (managed appliance, RDS-style VM, or external Postgres).
- HA: spread VMs across **anti-affinity** rules or different ESXi hosts.

### NSX-T (optional)

If using **NSX-T**, define distributed firewall (DFW) policies instead of (or in addition to) guest firewalls:

| Policy | Source | Destination | Service |
|---|---|---|---|
| Allow Serf | Nomad SG | Nomad SG | TCP/UDP 7946 |
| Allow Nomatron | LB SG / users | Nomad SG | TCP 4649 |
| Allow Postgres | Nomad SG | DB SG | TCP 5432 |

## 3. Firewall rules

Without NSX, use **guest OS firewall** (ufw/firewalld) or upstream physical firewall.

### Required ports

| Port | Protocol | Scope | Purpose |
|---|---|---|---|
| 4649 | TCP | Users / LB → clients | Nomatron API |
| 7946 | TCP + UDP | Client ↔ client | Serf (HA) |
| 5432 | TCP | Clients → DB | PostgreSQL |
| 22 | TCP | Admin → clients | SSH |

Egress: **443** for container registry, artifact downloads, Keygen licensing.

## 4. Create VMs

### vSphere Client

1. Deploy from **Ubuntu OVA** or template.
2. **Hardware:** 2 vCPU, 8 GiB RAM, PVSCSI disk 40 GiB.
3. **Network:** VMXNET3 adapter on `PG-NOMAD-CLIENTS`.
4. **VM options:** enable CPU/Memory hot add only if your runbooks require it (not required for Nomatron).
5. **Anti-affinity:** DRS rule for HA nodes.

### Terraform (optional)

Use `hashicorp/vsphere` provider with cloned template, static IP via cloud-init or DHCP reservation.

## 5. Nomad client config (dedicated nodes)

On each guest, follow [nomad-client-setup.md](../common/nomad-client-setup.md).

Install VMware tools:

```bash
sudo apt-get install -y open-vm-tools
```

Primary NIC is often `ens192` (VMXNET3):

```hcl
client {
  enabled  = true
  cni_path = "/opt/cni/bin"
  node_pool = "nomatron"

  meta {
    nomatron = "true"
    role     = "control"
  }

  host_network "default" {
    interface = "ens192"
  }
}
```

Merge [dedicated-nodes.vars.hcl.example](../../packs/nomatron/examples/dedicated-nodes.vars.hcl.example) into pack vars. Nomad Enterprise: see [dedicated-nodes-and-placement.md](../common/dedicated-nodes-and-placement.md) for node pool and Sentinel recommendations.

Restart Nomad after config changes.

## 6. PostgreSQL (BYODB)

Common patterns:

| Pattern | Notes |
|---|---|
| Dedicated Postgres VM on PG-DB | Simple on-prem |
| External managed DB | Preferred for production |
| vSphere with Bitnami / Crunchy operator | Kubernetes-style; Postgres not on Nomad |

```hcl
database = {
  connection_string = "postgres://nomatron:SECRET@10.30.2.10:5432/nomatron?sslmode=require"
  sslmode           = "require"
}
```

## 7. Load balancing on VMware (pick one)

| Option | Pack setting | Traefik? |
|---|---|---|
| **NSX ALB / HAProxy / F5** → VM:4649 | `load_balancer_mode=none`, `http_port_static=4649` | **No** |
| **Pack Traefik** | `load_balancer_mode=traefik` | Pack deploys Traefik |
| **Existing Traefik on Nomad** | `load_balancer_mode=service` | Already installed |

Cloud-style LB (Avi, HAProxy) uses health check `/api/v1/health?bootstrap=ok` on port **4649**. Do not add Traefik unless you want Nomad-native service discovery. See [load-balancing.md](../common/load-balancing.md).

## 8. HA Serf

```hcl
serf = {
  retry_join  = ["10.30.1.11:7946", "10.30.1.12:7946", "10.30.1.13:7946"]
  encrypt_key = "..."
}
```

Ensure L2/L3 connectivity and firewall allow gossip between all client IPs.

## 9. Deploy pack

From an operator workstation with Nomad CLI access:

```bash
cp examples/ha.byodb.vars.hcl.example ha.vars.hcl
# Merge examples/dedicated-nodes.vars.hcl.example
nomad-pack plan -var-file=ha.vars.hcl .
nomad-pack run  -var-file=ha.vars.hcl .
```

## 10. Verify

```bash
nomad node status -self
nomad job status nomatron
curl -sk "https://nomatron.example.com/api/v1/health?bootstrap=ok"
```

Check vSphere: VMs powered on, tools running, no CPU/memory contention on shared datastores.
