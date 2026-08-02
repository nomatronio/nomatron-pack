# AWS — Nomad client setup for Nomatron

Prepare **EC2 Nomad clients** in a VPC for the Nomatron Nomad pack. For a full managed stack (ALB, RDS, ASG), see the [Nomatron AWS reference architecture](https://github.com/nomatronio/reference-architecture/tree/main/aws).

**Read first (all platforms):**

- [Dedicated nodes — node_pool, meta, constraints](../common/dedicated-nodes-and-placement.md)
- [Load balancing — ALB vs Traefik](../common/load-balancing.md)
- [Nomad client setup](../common/nomad-client-setup.md) · [Ports & firewall](../common/ports-and-firewall.md)

## 1. VM sizing

| Profile | Instances | Type (starting point) |
|---|---|---|
| production | 1 × Nomad client | `m7i.large` or `t3.large` (2 vCPU, 8 GiB) |
| ha | 3 × Nomad clients (one per AZ) | `m7i.large` × 3 (ref arch default) |

Use **Amazon Linux 2023** or **Ubuntu 24.04**. Enable IMDSv2. Attach an IAM instance profile if you use SSM Session Manager instead of SSH.

## 2. VPC layout

Recommended for production HA:

```text
VPC 10.0.0.0/16
├── public subnets (per AZ)     → ALB, NAT gateway
└── private subnets (per AZ)    → Nomad clients, RDS
```

- Place **Nomad clients in private subnets** with egress via NAT (or VPC endpoints for ECR/S3).
- Place **RDS PostgreSQL** in private subnets (BYODB writer endpoint).
- Single-AZ lab: one public + one private subnet is acceptable.

## 3. Security groups

Create three security groups (or equivalent rules in a shared SG model).

### `sg-nomad-client`

| Rule | Type | Port | Source |
|---|---|---|---|
| Inbound | TCP | 4649 | `sg-alb` (if using ALB) or admin CIDR |
| Inbound | TCP | 7946 | `sg-nomad-client` (self) — HA only |
| Inbound | UDP | 7946 | `sg-nomad-client` (self) — HA only |
| Inbound | TCP | 22 | Admin/bastion CIDR (optional) |
| Outbound | All | All | 0.0.0.0/0 (or restrict to VPC + endpoints) |

### `sg-alb` (if using load balancer)

| Rule | Type | Port | Source |
|---|---|---|---|
| Inbound | TCP | 80, 443 | Internet or corp CIDR |
| Outbound | TCP | 4649 | `sg-nomad-client` |

### `sg-rds` (BYODB)

| Rule | Type | Port | Source |
|---|---|---|---|
| Inbound | TCP | 5432 | `sg-nomad-client` |

Aligns with [aws-nomatron security groups](https://github.com/nomatronio/reference-architecture/blob/main/aws/modules/aws-nomatron/security.tf).

## 4. Launch EC2 instances

Per Nomad client:

1. AMI: Amazon Linux 2023 or Ubuntu 24.04 LTS.
2. Subnet: private subnet in distinct AZ for HA.
3. Security group: `sg-nomad-client`.
4. Storage: 30+ GiB gp3 root volume; add data volume if needed for host volumes (lab Postgres).
5. IAM role: `AmazonSSMManagedInstanceCore` for Session Manager (optional).
6. User data (optional): invoke [common/nomad-client-setup.md](../common/nomad-client-setup.md) scripts.

Tag instances for operations (example):

```text
Name=nomatron-nomad-client-1
nomatron-role=nomad-client
```

## 5. Nomad client config (dedicated nodes)

On **each** EC2 instance, configure the Nomad client before deploying the pack. Production clients should **not** share a pool with unrelated workloads.

Copy [nomad-client.hcl.example](../common/nomad-client.hcl.example) to `/etc/nomad.d/nomatron-client.hcl` and adjust:

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
    interface = "ens5"   # common on AL2023 / Ubuntu on EC2
  }
}
```

Then install Docker and CNI — full steps in [nomad-client-setup.md](../common/nomad-client-setup.md).

Verify:

```bash
sudo systemctl restart nomad
nomad node status -self -json | jq '.Meta'
```

See [dedicated-nodes-and-placement.md](../common/dedicated-nodes-and-placement.md) for Enterprise node pools, namespaces, and quotas.

## 6. Network ACLs (optional)

Security groups are usually sufficient. If using NACLs, allow ephemeral return traffic and the ports in [ports-and-firewall.md](../common/ports-and-firewall.md).

## 7. RDS / BYODB

1. Create RDS PostgreSQL 16 (Multi-AZ for production).
2. Place in private subnets; attach `sg-rds`.
3. Use writer endpoint in pack vars:

```hcl
database = {
  connection_string = "postgres://nomatron:SECRET@nomatron.xxxxx.region.rds.amazonaws.com:5432/nomatron?sslmode=require"
  sslmode           = "require"
}
```

## 8. Load balancing on AWS (ALB — no Traefik required)

For production on AWS, use an **Application Load Balancer**. You **do not** need Traefik or Fabio unless you already run them on Nomad.

```text
Users → ALB :443 → each EC2 :4649 → Nomatron task
```

1. Create ALB in public subnets; attach `sg-alb`.
2. Target group: **instance** type, port **4649**, health check `/api/v1/health?bootstrap=ok`.
3. Register all Nomad client instances (one per AZ for HA).
4. ACM certificate on HTTPS listener; redirect HTTP → HTTPS.

Pack vars for ALB (see [load-balancing.md](../common/load-balancing.md)):

```hcl
load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649

public_hostname = "nomatron.example.com"
public_scheme   = "https"

server = {
  api_addr    = "https://nomatron.example.com"
  tls_enabled = false   # TLS at ALB
}
```

Match pack placement to dedicated clients:

```hcl
node_pool = "nomatron"
constraints = [{ attribute = "${meta.nomatron}", operator = "=", value = "true" }]
```

**When to use Traefik instead:** only if you already operate Traefik on this Nomad cluster (`load_balancer_mode=service`) or want the pack to install it (`load_balancer_mode=traefik`). Do not configure ALB → 4649 on every node *and* Traefik to the same tasks without a deliberate two-tier design.

## 9. Serf retry_join (HA)

Use private IPs of Nomad clients:

```hcl
serf = {
  retry_join = ["10.0.1.10:7946", "10.0.2.10:7946", "10.0.3.10:7946"]
}
```

Ensure `serf_port_static = 7946` and security group allows self-referencing 7946/tcp+udp.

## 10. Deploy pack

```bash
cp examples/ha.byodb.vars.hcl.example ha.vars.hcl
# Merge snippets from examples/dedicated-nodes.vars.hcl.example
nomad-pack plan -var-file=ha.vars.hcl .
nomad-pack run  -var-file=ha.vars.hcl .
```

## 11. Verify

```bash
nomad job status nomatron
curl -s "https://nomatron.example.com/api/v1/health?bootstrap=ok"
# Or via ALB DNS before DNS cutover:
curl -s "http://<alb-dns>/api/v1/health?bootstrap=ok" -H "Host: nomatron.example.com"
```
