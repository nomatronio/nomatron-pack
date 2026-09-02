# Secrets management

Production deployments should **not** pass secrets through `nomad-pack` variables (`secrets_backend=pack_vars`). Pack vars are rendered into the Nomad job specification and are visible to anyone with Nomad job read access.

Use one of these runtime patterns instead:

| Backend | Best for | Secrets in job spec? |
|---|---|---|
| **`nomad_var`** (recommended) | Nomad-only shops, no Vault | No — only the variable path |
| **`vault`** | Teams with HashiCorp Vault | No — only Vault paths and policies |
| **`pack_vars`** | Homelab, CI, quickstart | Yes — avoid in production |

## Nomad Variables (recommended)

Nomad Variables are encrypted at rest and scoped by ACL. Tasks read them at allocation time via a `template` block — values never appear in the submitted job.

### 1. Create the variable

Use the job-scoped path convention `nomad/jobs/<job>/<group>/<task>`:

```bash
nomad var put nomad/jobs/nomatron/nomatron-server/nomatron \
  encryption_key="$(openssl rand -base64 32)" \
  license_key="YOUR-LICENSE-KEY" \
  cluster_key="YOUR-CLUSTER-KEY" \
  db_url="postgres://nomatron:SECRET@db-writer.example.com:5432/nomatron?sslmode=require"
```

For HA, add the same Serf key on every server:

```bash
nomad var put nomad/jobs/nomatron/nomatron-server/nomatron \
  serf_encrypt_key="$(nomatron keygen)"
```

Re-run `nomad var put` to update values; allocations restart when `change_mode = "restart"`.

### Origin TLS PEMs (optional)

When Host Agents need Nomatron to speak TLS (gRPC passthrough) while pack vars stay free of secrets, store the PEMs in the **same** Variable and leave `server.tls_cert_file` / `tls_key_file` empty:

```bash
openssl req -x509 -newkey rsa:4096 -sha256 -days 825 -nodes \
  -keyout key.pem -out cert.pem \
  -subj "/CN=nomatron.example.com" \
  -addext "subjectAltName=DNS:nomatron.example.com"

nomad var put nomad/jobs/nomatron/nomatron-server/nomatron \
  tls_cert=@cert.pem \
  tls_key=@key.pem \
  tls_ca=@cert.pem
```

```hcl
server = {
  tls_enabled   = true
  tls_cert_file = ""
  tls_key_file  = ""
  tls_ca_file   = ""
}
```

The pack writes `${NOMAD_SECRETS_DIR}/tls/{cert,key,ca}.pem` at alloc start. The cert SAN must match `agent_grpc_advertise_addr` (and the hostname Traefik uses toward Nomatron). Nomad Variables are small (tens of KiB for the whole item); a typical cert + key + CA fits. Do not put PEMs in pack vars.

With Traefik in front, the pack appends `scheme=https` on the HTTP service. For a private CA, set Traefik static `serversTransport.insecureSkipVerify=true`. Do not put skip-verify on Nomad tags — Traefik ignores that and the HTTP router 404s. Edge TLS (Pinggy, ALB) is unchanged.

### 2. Deploy with the pack

```hcl
secrets_backend = "nomad_var"

secrets_nomad_var = {
  path = "nomad/jobs/nomatron/nomatron-server/nomatron"
  # keys = { ... }  # optional — defaults match the put command above
}

database = {
  host  = "db-writer.example.com"
  port  = 5432
  name  = "nomatron"
  # password and connection_string live in the Nomad Variable (db_url key)
}
```

See [examples/production.byodb.nomad-var.vars.hcl.example](../../examples/production.byodb.nomad-var.vars.hcl.example).

### ACL

Tasks receive implicit access to variables under their job path. For shared secrets across jobs, attach a workload identity policy — see [Nomad Variables in tasks](https://developer.hashicorp.com/nomad/docs/job-declare/nomad-variables).

## HashiCorp Vault

Use Vault when you already operate Vault for secrets, rotation, and audit.

### 1. Store secrets in KV v2

```bash
vault kv put secret/nomatron/production \
  encryption_key="$(openssl rand -base64 32)" \
  license_key="YOUR-LICENSE-KEY" \
  cluster_key="YOUR-CLUSTER-KEY" \
  db_url="postgres://nomatron:SECRET@db-writer.example.com:5432/nomatron?sslmode=require" \
  serf_encrypt_key="$(nomatron keygen)"
```

### 2. Nomad policy for the job

Create a Vault policy (example `nomatron.hcl`):

```hcl
path "secret/data/nomatron/production" {
  capabilities = ["read"]
}
```

Enable Nomad's Vault integration on clients and servers.

### 3. Deploy with the pack

```hcl
secrets_backend = "vault"

secrets_vault = {
  policies = ["nomatron"]
  path     = "secret/data/nomatron/production"
}
```

See [examples/production.byodb.vault.vars.hcl.example](../../examples/production.byodb.vault.vars.hcl.example).

## What each key supplies

| Key | Required | Maps to |
|---|---|---|
| `encryption_key` | Yes | `NOMATRON_ENCRYPTION_KEY` — stable for the life of the database |
| `license_key` | Yes | `NOMATRON_LICENSE_KEY` |
| `cluster_key` | Yes | `NOMATRON_CLUSTER_KEY` — identical on all HA nodes |
| `db_url` | BYODB | `NOMATRON_DB_URL` — full Postgres URL with `sslmode=require` |
| `serf_encrypt_key` | HA (`count > 1`) | Serf `encrypt_key` in `nomatron.hcl` |
| `root_password` | Optional bootstrap | `NOMATRON_ROOT_PASSWORD` |
| `tls_cert` / `tls_key` / `tls_ca` | Origin TLS (`server.tls_enabled`, empty file paths) | `${NOMAD_SECRETS_DIR}/tls/*.pem` — rename via `tls_secrets_keys` |

Key names are configurable via `secrets_nomad_var.keys` and `secrets_vault.keys`.

## Homelab / CI (`pack_vars`)

For local development, pass secrets via a gitignored `*.vars.hcl`:

```bash
nomad-pack run --var-file=mac-dev.vars.hcl .
```

Never commit real secrets. This mode is validated in CI only with placeholder values.

## Related

- [Load balancing and TLS](./load-balancing.md)
- [Ports and firewall](./ports-and-firewall.md)
- [Nomad secrets consumption patterns](https://www.hashicorp.com/blog/nomad-secrets-consumption-patterns-nomad-variables)
