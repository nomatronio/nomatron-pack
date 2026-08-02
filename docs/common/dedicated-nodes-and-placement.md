# Dedicated Nomad clients — node pools, metadata, and constraints

Nomatron should run on **dedicated Nomad clients** in production: VMs reserved for the control plane, not shared with arbitrary batch or app workloads. This guide explains how to **label clients**, **restrict the pack job** to those clients, and optional **Nomad Enterprise** guardrails.

If you are new to Nomad placement: a **job** (Nomatron) is scheduled onto **clients** (your VMs). Without restrictions, Nomad may place Nomatron on any client with free CPU and memory. Dedicated nodes prevent that.

## The three knobs (use together for production)

| Knob | Where | What it does |
|---|---|---|
| **`node_pool`** | Nomad client config **and** pack vars | Enterprise isolation — job only runs in clients assigned to that pool |
| **`client.meta`** | Nomad client config | Labels on each client (key/value tags) |
| **`constraints`** | Pack vars file | Job rules that match client metadata or other attributes |

**Rule:** values must **match on both sides**. If the pack says `node_pool = "nomatron"`, every client that should run Nomatron must have `node_pool = "nomatron"` in its agent config (or be started with `-node-pool=nomatron`).

```text
  Pack vars (nomad-pack)              Nomad client agent (/etc/nomad.d/client.hcl)
  ─────────────────────               ───────────────────────────────────────────
  node_pool   = "nomatron"     ←──→   client { node_pool = "nomatron" }
  constraints = meta.nomatron  ←──→   client { meta { nomatron = "true" } }
```

## Step 1 — Configure each dedicated client

Edit the Nomad **client** config on every VM that should run Nomatron. Merge with [nomad-client.hcl.example](nomad-client.hcl.example).

### Recommended production client block

```hcl
client {
  enabled  = true
  cni_path = "/opt/cni/bin"

  # Enterprise: isolate Nomatron workloads to this pool (must match pack vars).
  node_pool = "nomatron"

  # Labels used by job constraints (works on OSS and Enterprise).
  meta {
    nomatron = "true"      # required for constraint below
    role     = "control"   # optional — your ops taxonomy
    env      = "production"
  }

  host_network "default" {
    interface = "ens5"     # platform-specific — see platform guides
  }
}

plugin "docker" {
  config {
    allow_privileged = false
  }
}
```

Restart after changes:

```bash
sudo systemctl restart nomad
nomad node status -self
```

### Verify client labels

```bash
# Node pool (Enterprise shows non-default pools; OSS is always "default")
nomad node status -self | grep -i pool

# Metadata
nomad node status -self -json | jq '.Meta'
# Expect: { "nomatron": "true", "role": "control", ... }
```

**Do not** set `nomatron = "true"` on clients that should never run Nomatron (general-purpose batch nodes).

## Step 2 — Match the pack vars file

When you deploy with `nomad-pack`, set the same pool and add constraints.

### Production / HA example

```hcl
# production.vars.hcl (or ha.vars.hcl)

node_pool = "nomatron"

constraints = [
  {
    attribute = "${meta.nomatron}"
    operator  = "="
    value     = "true"
  }
]

# Optional: pin to a datacenter name if your cluster uses multiple DCs
# datacenters = ["dc1"]
```

The pack renders these as Nomad job-level `constraint` blocks. Nomatron will **only** schedule on clients where `meta.nomatron == "true"` **and** (Enterprise) `node_pool == "nomatron"`.

### Homelab / shared cluster (weaker isolation)

If Nomatron shares a cluster with other jobs but uses a named pool (for example `infra`):

```hcl
node_pool = "infra"

constraints = [
  {
    attribute = "${meta.nomatron}"
    operator  = "="
    value     = "true"
  }
]
```

Client config must use the same `node_pool = "infra"` and `meta { nomatron = "true" }`.

### Quickstart on a single dev client

If you have **one** client and nothing else competes for resources, you can skip custom meta and constraints:

```hcl
node_pool   = "default"   # OSS default
constraints = []
```

This is fine for first deploy; **not** recommended for shared production clusters.

## Step 3 — Plan before deploy

Always run `nomad-pack plan` and confirm placement:

```bash
nomad-pack plan -var-file=production.vars.hcl .
```

Check that the planned allocations land on the expected node IDs. If placement fails with **no nodes matched constraint**, a client is missing matching `meta` or `node_pool`.

Common mistakes:

| Symptom | Fix |
|---|---|
| `no nodes matched constraint` | Add `meta { nomatron = "true" }` on clients, or fix typo in `constraints` |
| Job stuck unplaced, wrong pool | Align `node_pool` in client config and vars file |
| Job placed on wrong node | Another client has the same meta — use stricter labels or Enterprise node pools |
| HA servers on same node | Pack uses `spread` on `${node.unique.id}` — need **≥ `count` dedicated clients** |

## HA and dedicated nodes

For `deployment_profile = "ha"` with `count = 3`:

- Provision **3 dedicated clients** (one per AZ/zone is ideal).
- Each client gets the same `node_pool` and `meta.nomatron = "true"`.
- The pack spreads Nomatron servers across `${node.unique.id}` — you need at least 3 eligible clients or some servers will not place.

```bash
nomad node status -filter 'Meta.nomatron == true'   # Nomad 1.7+ filter syntax may vary
# Or: nomad node status and inspect Meta column manually
```

## Nomad Enterprise guardrails (recommended)

These features require **Nomad Enterprise**. On open-source Nomad, use **`client.meta` + `constraints`** (above) and operational discipline.

### Node pools (Enterprise)

Node pools are the primary Enterprise mechanism to isolate Nomatron from other teams' workloads.

1. Create a pool (CLI or API):

```bash
nomad node pool apply <<EOF
NodePool {
  Name        = "nomatron"
  Description = "Dedicated Nomatron control plane clients"
}
EOF
```

2. Assign each dedicated client: `client { node_pool = "nomatron" }`.
3. Set pack var: `node_pool = "nomatron"`.

Only clients in the `nomatron` pool are eligible — even if another client has spare CPU.

### Namespaces (Enterprise)

Run Nomatron in a dedicated namespace for RBAC and quotas:

```hcl
namespace = "nomatron"
```

Create the namespace and ACL policies so only platform admins can submit jobs there. See [HashiCorp Nomad namespaces](https://developer.hashicorp.com/nomad/docs/govern/namespaces).

### Resource quotas (Enterprise)

Cap total CPU/memory in the `nomatron` namespace so a misconfigured job cannot exhaust the cluster:

```bash
nomad quota apply <<EOF
Quota {
  Name = "nomatron-quota"
  Limits {
    Region = "global"
    RegionLimits {
      CPU       = 10000
      MemoryMB  = 20480
    }
  }
}
EOF
```

Size limits for your `count` × `nomatron_resources` plus headroom.

### Sentinel policies (Enterprise)

Example policy goals:

- Require `node_pool = "nomatron"` on jobs in the `nomatron` namespace
- Deny `raw_exec` driver for Nomatron jobs
- Require `deployment_profile` label in job meta (if you add custom meta to the job)

See [HashiCorp Sentinel for Nomad](https://developer.hashicorp.com/nomad/docs/govern/sentinel).

### Audit and compliance (Enterprise)

Enable [audit logging](https://developer.hashicorp.com/nomad/docs/govern/audit) on Nomad servers to record job submissions and client changes for Nomatron deploys.

### Summary: OSS vs Enterprise

| Goal | Open source | Enterprise |
|---|---|---|
| Keep Nomatron off general clients | `client.meta` + pack `constraints` | **Node pools** + meta constraints |
| RBAC / team isolation | ACL policies | **Namespaces** + ACLs |
| Cap resource usage | Manual monitoring | **Resource quotas** |
| Enforce placement rules in CI | Pre-deploy `nomad-pack plan` | **Sentinel** policies |
| Change audit trail | External logging | **Audit device** |

## Related docs

- [Nomad client setup](nomad-client-setup.md) — Docker, CNI, base client config
- [Load balancing](load-balancing.md) — ALB vs Traefik vs direct access
- [Platform guides](../packs/nomatron/README.md) — per-cloud VM and firewall steps
