# GCP — Nomad client setup for Nomatron

Prepare **Compute Engine** VMs as Nomad clients for the Nomatron Nomad pack.

**Read first:** [Dedicated nodes](../common/dedicated-nodes-and-placement.md) · [Load balancing](../common/load-balancing.md) · [Nomad client setup](../common/nomad-client-setup.md) · [Ports](../common/ports-and-firewall.md)

## 1. VM sizing

| Profile | VMs | Machine type |
|---|---|---|
| production | 1 | `e2-standard-2` (2 vCPU, 8 GiB) |
| ha | 3 across zones | `e2-standard-2` × 3 |

OS: **Ubuntu 24.04 LTS** (x86_64 or `t2a-standard-2` for arm64 with `binary_arch=arm64`).

## 2. VPC layout

```text
VPC nomatron (custom mode)
├── subnet nomatron-clients 10.10.0.0/20  region-a
├── subnet nomatron-clients 10.10.16.0/20 region-b  (HA)
└── subnet nomatron-clients 10.10.32.0/20 region-c  (HA)
```

- **Private Google Access** enabled on client subnets (pull images, APIs without public IPs).
- **Cloud NAT** for outbound internet if VMs have no external IP.
- **Cloud SQL PostgreSQL** via private IP (BYODB) — use Private Service Connect or authorized networks restricted to client subnet.

## 3. Firewall rules

GCP firewall rules are **VPC-level** (tags-based).

Tag client VMs: `nomad-client`

| Rule name | Direction | Targets | Source | Ports |
|---|---|---|---|---|
| `allow-nomatron-lb` | ingress | `nomad-client` | LB subnet / `130.211.0.0/22` (GLB health) | tcp:4649 |
| `allow-serf` | ingress | `nomad-client` | `10.10.0.0/16` | tcp+udp:7946 |
| `allow-iap-ssh` | ingress | `nomad-client` | `35.235.240.0/20` (IAP) | tcp:22 |
| `allow-egress` | egress | `nomad-client` | 0.0.0.0/0 | all (or restrict) |

For **Cloud SQL**, use private IP; firewall on SQL side allows client subnet → **5432**.

## 4. Create Compute Engine instances

Per Nomad client:

1. **No external IP** (use IAP for SSH).
2. Service account with minimal roles (logging, monitoring); avoid broad storage admin.
3. **Shielded VM** options per org policy.
4. Same network tag: `nomad-client`.
5. Place each HA node in a **different zone** within the region.

## 5. Nomad client config (dedicated nodes)

Follow [nomad-client-setup.md](../common/nomad-client-setup.md). GCP primary interface is typically `ens4`:

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
    interface = "ens4"
  }
}
```

Pack vars: merge [dedicated-nodes.vars.hcl.example](../../examples/dedicated-nodes.vars.hcl.example).

## 6. Cloud SQL (BYODB)

1. Create **PostgreSQL 16** instance (regional HA for production).
2. Enable **private IP** on the VPC.
3. Connection string:

```hcl
database = {
  connection_string = "postgres://nomatron:PASS@10.x.x.x:5432/nomatron?sslmode=require"
  sslmode           = "require"
}
```

Use the Cloud SQL Auth Proxy only if your security model requires it; otherwise private IP is preferred for Nomad clients in the same VPC.

## 7. Load balancing on GCP (External HTTP(S) LB — no Traefik required)

Use **Google Cloud External HTTP(S) Load Balancer**. Point backend services at each Nomad client VM on port **4649**. You **do not** need Traefik for this path.

Pack vars:

```hcl
load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649
```

Health check: `/api/v1/health?bootstrap=ok`. TLS terminates at the load balancer.

Use `load_balancer_mode=service` or `traefik` only if Traefik/Fabio already runs on Nomad — see [load-balancing.md](../common/load-balancing.md).

## 8. HA Serf

```hcl
serf = {
  retry_join = ["10.10.0.4:7946", "10.10.16.4:7946", "10.10.32.4:7946"]
}
```

## 9. Deploy and verify

```bash
cp examples/production.byodb.vars.hcl.example production.vars.hcl
nomad-pack run -var-file=production.vars.hcl .
```

```bash
nomad node status -self
gcloud compute instances list --filter="tags.items=nomad-client"
```
