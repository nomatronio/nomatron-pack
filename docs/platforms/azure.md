# Azure — Nomad client setup for Nomatron

Prepare **Azure Linux VMs** as Nomad clients for the Nomatron Nomad pack.

**Read first:** [Dedicated nodes](../common/dedicated-nodes-and-placement.md) · [Load balancing](../common/load-balancing.md) · [Nomad client setup](../common/nomad-client-setup.md) · [Ports](../common/ports-and-firewall.md)

## 1. VM sizing

| Profile | VMs | Size (starting point) |
|---|---|---|
| production | 1 | `Standard_D2s_v5` (2 vCPU, 8 GiB) |
| ha | 3 (one per availability zone) | `Standard_D2s_v5` × 3 |

OS: **Ubuntu 24.04 LTS** or **RHEL 9** (marketplace).

## 2. Virtual network layout

```text
vnet-nomatron 10.1.0.0/16
├── subnet-public   10.1.101.0/24   (optional: Application Gateway)
└── subnet-private  10.1.1.0/24     (Nomad clients)
    subnet-private  10.1.2.0/24     (AZ 2 — HA)
    subnet-private  10.1.3.0/24     (AZ 3 — HA)
```

- Deploy Nomad clients in **private subnets**.
- Use **Azure Database for PostgreSQL Flexible Server** (BYODB) in a delegated subnet or private endpoint — not on Nomad VMs in production.

## 3. Network security groups (NSG)

Attach NSG `nsg-nomad-client` to each client subnet or NIC.

### Inbound

| Priority | Name | Port | Source | Purpose |
|---:|---|---|---|---|
| 100 | nomatron-http | 4649 | Application Gateway subnet or admin CIDR | Nomatron API |
| 110 | serf-tcp | 7946 | VirtualNetwork | Serf TCP (HA) |
| 120 | serf-udp | 7946 | VirtualNetwork | Serf UDP (HA) |
| 130 | ssh | 22 | Bastion subnet | Admin (optional) |

### Outbound

Allow **5432** to PostgreSQL private endpoint/subnet, **443** to Internet or via firewall for image pulls and licensing.

### Application Gateway (optional)

- Frontend: 443 from users
- Backend pool: Nomad client private IPs on **4649**

## 4. Create Linux VMs

For each Nomad client:

1. Resource group + region with 3 AZs for HA.
2. VM: `Standard_D2s_v5`, Ubuntu 24.04, **no public IP** (use Bastion).
3. NIC in private subnet; attach `nsg-nomad-client`.
4. Enable **Azure Monitor** / VM extensions as required by policy.
5. Managed identity (optional) for Key Vault secret retrieval.

## 5. Nomad client config (dedicated nodes)

On each VM, install Docker and CNI per [nomad-client-setup.md](../common/nomad-client-setup.md), then configure the agent:

```hcl
client {
  enabled  = true
  cni_path = "/opt/cni/bin"
  node_pool = "nomatron"

  meta {
    nomatron = "true"
    role     = "control"
  }
}
```

Restart Nomad: `sudo systemctl restart nomad`

Match pack vars ([dedicated-nodes.vars.hcl.example](../../examples/dedicated-nodes.vars.hcl.example)):

```hcl
node_pool = "nomatron"
constraints = [{ attribute = "${meta.nomatron}", operator = "=", value = "true" }]
```

## 6. PostgreSQL (BYODB)

Example: **Azure Database for PostgreSQL Flexible Server**

1. Create server with **private access** (VNet integration).
2. Enable TLS; note FQDN: `nomatron.postgres.database.azure.com`.
3. Pack connection string:

```hcl
database = {
  connection_string = "postgres://USER@SERVER:5432/nomatron?sslmode=require"
  sslmode           = "require"
}
```

Ensure NSG allows client subnet → Postgres subnet on **5432**.

## 7. Load balancing on Azure (Application Gateway — no Traefik required)

Use **Azure Application Gateway** as the user entry point. You **do not** need Traefik unless it already runs on your Nomad cluster.

```text
Users → App Gateway :443 → each VM private IP :4649
```

Pack vars:

```hcl
load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649
public_hostname    = "nomatron.example.com"
server = { api_addr = "https://nomatron.example.com", tls_enabled = false }
```

Backend pool: all dedicated Nomad client NICs on port **4649**. Health probe: `/api/v1/health?bootstrap=ok`.

See [load-balancing.md](../common/load-balancing.md) for Traefik alternatives.

## 8. HA Serf

```hcl
serf = {
  retry_join  = ["10.1.1.4:7946", "10.1.2.4:7946", "10.1.3.4:7946"]
  encrypt_key = "..."
}
```

Open **7946/tcp+udp** between client private IPs (VirtualNetwork source).

## 9. Deploy pack

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
```
