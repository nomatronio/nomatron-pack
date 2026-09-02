# Nomatron on Nomad — platform setup guides

Step-by-step instructions to prepare **Linux Nomad clients** for the [Nomatron Nomad pack](../packs/nomatron/README.md). These guides cover VM creation, networking, firewall rules, Nomad client placement (node pools, metadata, constraints), load balancing choices, and client software (Docker, CNI, Nomad).

**Deploying the pack:** see [Install and use nomad-pack](../README.md#install-and-use-nomad-pack) in the repository README (CLI install, clone vs registry, `plan` / `run`).

## Before you start

1. **Trying Nomatron?** Run `nomatron server --dev` — see [Try Nomatron](../packs/nomatron/README.md#try-nomatron-not-the-nomad-pack).
2. Choose a [deployment profile](../packs/nomatron/README.md#deployment-profiles): `production`, `ha`, or lab `quickstart`.
3. Read the **shared guides** below — especially for production placement or load balancing.
4. Follow your **platform guide** (production/HA only).
5. Deploy using a variables block from [packs/nomatron/README.md](../packs/nomatron/README.md) (or `nomad-pack run .` with no vars file for dev).

## Shared guides (read these)

| Topic | Guide | Why |
|---|---|---|
| **Dedicated clients** | [dedicated-nodes-and-placement.md](common/dedicated-nodes-and-placement.md) | `node_pool`, `client.meta`, pack `constraints`, Nomad Enterprise guardrails |
| **Load balancing** | [load-balancing.md](common/load-balancing.md) | ALB vs Traefik vs Fabio vs direct — **you pick one HTTP entry path**; Host Agent gRPC is a separate TCP path |
| **Client software** | [nomad-client-setup.md](common/nomad-client-setup.md) | Docker, CNI, full client config walkthrough |
| **Firewall ports** | [ports-and-firewall.md](common/ports-and-firewall.md) | Port matrix for Nomatron, Serf, LB, Postgres |
| **Secrets** | [secrets.md](common/secrets.md) | Nomad Variables (recommended) or Vault — not pack vars in production |

## Platform guides

| Platform | Guide | Load balancer (typical) |
|---|---|---|
| **AWS** | [aws.md](platforms/aws.md) | ALB → clients :4649 (**no Traefik**) |
| **Azure** | [azure.md](platforms/azure.md) | Application Gateway → clients :4649 |
| **GCP** | [gcp.md](platforms/gcp.md) | External HTTP(S) LB → clients :4649 |
| **Proxmox** | [proxmox.md](platforms/proxmox.md) | Direct IP, reverse proxy, or pack Traefik |
| **OpenStack** | [openstack.md](platforms/openstack.md) | Octavia LB or floating IP |
| **VMware** | [vmware.md](platforms/vmware.md) | NSX ALB / HAProxy / pack Traefik |

## Shared artifacts

| File | Purpose |
|---|---|
| [common/nomad-client.hcl.example](common/nomad-client.hcl.example) | Dedicated client config with `node_pool` + `meta` |
| [dedicated-nodes.vars.hcl.example](../examples/dedicated-nodes.vars.hcl.example) | Matching pack vars (`node_pool`, `constraints`) |
| [nomad-client-host-volume.hcl.example](../examples/nomad-client-host-volume.hcl.example) | Host volume for provision-mode Postgres (lab) |

## Architecture reminder

```text
[ Internet / users ]
        │
   [ ONE entry point ]          ← cloud LB, Traefik, or direct :4649 (pick one)
        │
  Nomad clients (dedicated)     ← node_pool + meta.nomatron=true; Docker + CNI
        │
  Nomatron job (nomad-pack)     ← constraints match client meta
        │
  PostgreSQL (BYODB)            ← managed DB; not on Nomad clients in production
```

**Production defaults:** dedicated clients + BYODB + cloud load balancer with `load_balancer_mode=none` and `http_port_static=4649`. Traefik is optional, not required when using ALB/App Gateway/GLB.
