# Nomatron Network Agent Nomad Pack

Deploy the [Nomatron](https://nomatron.io) Network Agent on HashiCorp Nomad.

The agent is an outbound-only component: it connects private Nomad APIs to the Nomatron control plane. This pack is a sibling of the [Nomatron server pack](../nomatron/) in the same repository — deploy them independently (often on different clusters).

**Install nomad-pack and get this pack:** see the [nomatron-pack repository README](https://github.com/nomatronio/nomatron-pack/blob/main/README.md#install-and-use-nomad-pack).

---

## When to use this pack

| Goal | Path |
|---|---|
| Deploy the Network Agent on Nomad | This pack |
| Deploy the Nomatron server on Nomad | [`packs/nomatron`](../nomatron/) |
| Customize a raw agent job | Hand-written Nomad job (see [website docs](https://nomatron.io/docs/network-agent/running-network-agent-as-a-nomad-job/)) |

Recommended shape:

- one agent process per private cluster / trust boundary;
- place the job where it can reach the private Nomad API and Nomatron (`4650` gRPC, `4649` HTTP);
- no public load balancer or inbound ports;
- render `agent.hcl` (this pack) instead of a long env-only config.

---

## Prerequisites

- Nomad **1.6+** with a Linux client that can reach:
  - Nomatron gRPC (`server_addrs`, typically `:4650`)
  - Nomatron HTTP (`http_base_urls`)
  - the target Nomad HTTP API (`cluster.address`)
- A Network Agent ID and token from Nomatron
- The Nomad cluster ID registered in Nomatron
- Docker on the client when `runtime=docker` (default)

---

## Quickstart variables

Save as `agent.vars.hcl` (do not commit real secrets):

```hcl
namespace = "nomatron-agents"
node_pool = "default"

server_addrs   = ["nomatron.example.com:4650"]
http_base_urls = ["https://nomatron.example.com"]

agent_id = "REPLACE-WITH-AGENT-UUID"

cluster = {
  cluster_id  = "REPLACE-WITH-CLUSTER-UUID"
  address     = "https://nomad.internal.example.com:4646"
  acl_token   = "REPLACE-WITH-NOMAD-ACL-TOKEN"
  tls_enabled = false
  skip_verify = false
}

secrets = {
  agent_token = "REPLACE-WITH-AGENT-TOKEN"
}

# Optional placement — escape Nomad interpolations in -var-file HCL:
# constraints = [
#   { attribute = "$${node.class}", operator = "=", value = "infra" }
# ]
```

Plan and run from `packs/nomatron-agent/`:

```bash
nomad-pack plan --var-file=agent.vars.hcl .
nomad-pack run  --var-file=agent.vars.hcl .
```

---

## Production secrets (Nomad Variables)

```bash
nomad var put nomad/jobs/nomatron-agent/agent/nomatron-agent \
  agent_token="REPLACE" \
  nomad_acl_token="REPLACE"
```

```hcl
secrets_backend = "nomad_var"

secrets_nomad_var = {
  path = "nomad/jobs/nomatron-agent/agent/nomatron-agent"
}

# Leave cluster.acl_token empty — loaded from the Nomad Variable.
cluster = {
  cluster_id  = "REPLACE-WITH-CLUSTER-UUID"
  address     = "https://nomad.internal.example.com:4646"
  acl_token   = ""
  tls_enabled = true
  skip_verify = false
}
```

---

## Runtime options

| | `runtime=docker` | `runtime=binary` |
|---|---|---|
| Nomad driver | Docker | exec |
| Image / binary | `ghcr.io/nomatronio/nomatron-releases/nomatron-agent:<version>` | artifact download or `binary_path` |

---

## Key variables

- `server_addrs`, `http_base_urls` — control plane endpoints
- `agent_id`, `secrets.agent_token` (or Nomad Variable / Vault)
- `cluster` — primary Nomad cluster (`cluster_id`, `address`, ACL/TLS)
- `additional_clusters` — optional extra `cluster` blocks (prefer separate agents)
- `secrets_backend` — `pack_vars`, `nomad_var`, or `vault`
- `runtime`, `nomatron_agent_version`, `node_pool`, `constraints`

Run `nomad-pack info .` for the full variable reference.

---

## Multi-cluster note

`additional_clusters` ACL tokens are taken from the vars file even when `secrets_backend` is `nomad_var` or `vault`. Prefer one agent per cluster unless those clusters share a network and ownership boundary.

---

## Upgrading

Change `nomatron_agent_version` and redeploy with the same `--var-file`.
