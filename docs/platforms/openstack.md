# OpenStack — Nomad client setup for Nomatron

Prepare **Nova instances** as Nomad clients for the Nomatron Nomad pack on private or public OpenStack clouds.

**Read first:** [Dedicated nodes](../common/dedicated-nodes-and-placement.md) · [Load balancing](../common/load-balancing.md) · [Nomad client setup](../common/nomad-client-setup.md) · [Ports](../common/ports-and-firewall.md)

## 1. VM sizing

| Profile | Instances | Flavor (example) |
|---|---|---|
| production | 1 | `m1.large` (2 vCPU, 8 GiB) or cloud-specific equivalent |
| ha | 3 across availability zones | `m1.large` × 3 |

OS: **Ubuntu 24.04** cloud image from Glance.

## 2. Network layout

### Neutron network

```text
Network: nomatron-net (10.20.0.0/16)
├── Subnet nomatron-clients  10.20.1.0/24  (AZ a)
├── Subnet nomatron-clients  10.20.2.0/24  (AZ b)
└── Subnet nomatron-clients  10.20.3.0/24  (AZ c)

Router: nomatron-router → external network (floating IPs optional)
```

- Nomad clients: **private network** only; use **floating IP** or **load balancer** for external access.
- PostgreSQL: **managed DBaaS** (Trove) or dedicated VM on a DB subnet — not on Nomad clients in production.

### Security groups vs provider firewall

Use **Neutron security groups** (stateful, per-port). Some deployments also apply **FWaaS** — duplicate rules there if required.

## 3. Security groups

Create security group `sg-nomad-client` and attach to all Nomad client ports.

### Ingress

| Rule | Protocol | Port | Remote |
|---|---|---|---|
| nomatron-http | TCP | 4649 | `sg-lb` or admin CIDR |
| serf-tcp | TCP | 7946 | `sg-nomad-client` (same group) |
| serf-udp | UDP | 7946 | `sg-nomad-client` |
| ssh | TCP | 22 | bastion / admin CIDR |

### Egress

Allow **5432** to PostgreSQL security group, **443** for registry and licensing egress.

### Load balancer (Octavia)

If using **Octavia** (LBaaS v2):

1. Create load balancer on public or internal VIP subnet.
2. Listener: HTTP/HTTPS → pool members on port **4649**.
3. Health monitor: HTTP GET `/api/v1/health?bootstrap=ok` (expect 200 when healthy).

### PostgreSQL security group

| Rule | Protocol | Port | Remote |
|---|---|---|---|
| postgres | TCP | 5432 | `sg-nomad-client` |

## 4. Launch instances

Via Horizon, OpenTofu/Terraform (`openstack_compute_instance_v2`), or CLI:

```bash
openstack server create \
  --image "Ubuntu 24.04" \
  --flavor m1.large \
  --network nomatron-net \
  --security-group sg-nomad-client \
  --key-name ops \
  --availability-zone nova:az-a \
  nomad-client-01
```

For HA, launch one instance per AZ with consistent naming.

Optional: use **config drive** or **cloud-init** user-data to bootstrap Docker/CNI (see common guide).

## 5. Nomad client config (dedicated nodes)

SSH via bastion or floating IP. Complete [nomad-client-setup.md](../common/nomad-client-setup.md).

OpenStack VMs often use `ens3`:

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
    interface = "ens3"
  }
}
```

Merge [dedicated-nodes.vars.hcl.example](../../packs/nomatron/examples/dedicated-nodes.vars.hcl.example) into your pack vars.

## 6. PostgreSQL (BYODB)

Options:

1. **Trove** PostgreSQL instance on private network
2. **Dedicated Nova VM** with Postgres + `sg-postgres`
3. **External managed Postgres** reachable via VPN/peering

Connection string example:

```hcl
database = {
  connection_string = "postgres://nomatron:PASS@10.20.10.5:5432/nomatron?sslmode=require"
  sslmode           = "require"
}
```

## 7. HA Serf

Use private fixed IPs from Neutron:

```hcl
serf = {
  retry_join = ["10.20.1.10:7946", "10.20.2.10:7946", "10.20.3.10:7946"]
}
```

Security group must allow **7946/tcp+udp** between members of `sg-nomad-client`.

## 8. Load balancing on OpenStack (pick one)

| Access model | Pack setting | Traefik? |
|---|---|---|
| **Octavia LB** (production HA) | `load_balancer_mode=none`, `http_port_static=4649` | **No** — Octavia → members :4649 |
| Floating IP on one client | `load_balancer_mode=none` | No — lab only |
| Traefik on Nomad | `load_balancer_mode=service` or `traefik` | Yes |

Octavia health monitor: `GET /api/v1/health?bootstrap=ok`. See [load-balancing.md](../common/load-balancing.md).

Set pack vars:

```hcl
load_balancer_mode = "none"
http_port_static   = 4649
server = {
  api_addr        = "https://nomatron.example.com"
  tls_enabled     = false
}
public_hostname = "nomatron.example.com"
```

## 9. Deploy pack

```bash
cp examples/ha.byodb.vars.hcl.example ha.vars.hcl
# Merge examples/dedicated-nodes.vars.hcl.example
nomad-pack plan -var-file=ha.vars.hcl .
nomad-pack run  -var-file=ha.vars.hcl .
```

## 10. Verify

```bash
openstack server list --name nomad-client
nomad node status -self
curl -s "http://<vip-or-fip>:4649/api/v1/health?bootstrap=ok"
```
