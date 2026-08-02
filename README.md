# nomatron-pack

Official [Nomad Pack](https://developer.hashicorp.com/nomad/tools/nomad-pack) for deploying [Nomatron](https://nomatron.io) on HashiCorp Nomad.

**Nomatron pack docs:** [packs/nomatron/README.md](packs/nomatron/README.md) — deployment profiles, variables, example HCL, and Nomatron-specific guidance.

**Platform setup guides:** [docs/README.md](docs/README.md) — AWS, Azure, GCP, Proxmox, OpenStack, VMware (repo only, not synced to the community registry).

Maintainers: [CONTRIBUTING.md](CONTRIBUTING.md)

## Repository layout

```text
nomatron-pack/
├── packs/nomatron/     # Synced to community registry (templates, vars, README, …)
├── docs/               # Platform guides (repo only)
├── examples/           # Copy of example vars (repo only; HCL also in pack README)
├── .ci/                # CI fixtures (repo only)
├── CONTRIBUTING.md
└── .github/
```

---

## Install and use nomad-pack

Nomatron is deployed with the **[nomad-pack](https://developer.hashicorp.com/nomad/tools/nomad-pack)** CLI — a templating tool that renders Nomad job specifications from a pack and registers them with your cluster.

### 1. Install the CLI

Download a release for your platform from [HashiCorp Releases (`nomad-pack`)](https://releases.hashicorp.com/nomad-pack/), unzip it, and put `nomad-pack` on your `PATH`.

macOS (Homebrew):

```bash
brew tap hashicorp/tap
brew install nomad-pack
```

Verify:

```bash
nomad-pack version
```

Full install options: [Nomad Pack documentation](https://developer.hashicorp.com/nomad/tools/nomad-pack).

### 2. Connect to your Nomad cluster

From a machine that can reach your Nomad servers:

```bash
export NOMAD_ADDR=https://nomad.example.com:4646   # your Nomad HTTP API
export NOMAD_TOKEN=<token>                          # required when ACLs are enabled

nomad node status    # confirm connectivity
```

You need permission to register jobs in the target namespace (default `default`).

### 3. Get the Nomatron pack

**The Nomatron pack is not yet in the HashiCorp community registry** (a PR is planned). When you first run `nomad-pack list`, the CLI downloads the [Nomad Pack Community Registry](https://github.com/hashicorp/nomad-pack-community-registry) — Nomatron will appear there after publish.

#### Option A — Clone and run locally

```bash
git clone https://github.com/nomatronio/nomatron-pack.git
cd nomatron-pack/packs/nomatron

nomad-pack info .
```

#### Option B — Default registry (after publish)

```bash
nomad-pack registry update default
nomad-pack info nomatron
nomad-pack run nomatron --var-file=production.vars.hcl
```

#### Option C — Custom registry (this repo)

```bash
nomad-pack registry add nomatronio \
  github.com/nomatronio/nomatron-pack \
  --target=nomatron

nomad-pack list --registry=nomatronio
nomad-pack info nomatron --registry=nomatronio
```

Pin a release:

```bash
nomad-pack registry add nomatronio \
  github.com/nomatronio/nomatron-pack \
  --target=nomatron \
  --ref=v0.2.0
```

List configured registries:

```bash
nomad-pack registry list
```

### 4. Create your variables file

Copy an example from [packs/nomatron/README.md](packs/nomatron/README.md) (each profile includes full HCL you can paste into a `*.vars.hcl` file). The same content lives under [`examples/`](examples/) in this repository for convenience.

```bash
# After pasting HCL into production.vars.hcl:
nomad-pack info .
```

### 5. Plan and deploy

Always **plan** before **run**:

```bash
# From packs/nomatron/ (clone) or use pack name nomatron (registry)
nomad-pack plan --var-file=production.vars.hcl .
nomad-pack run  --var-file=production.vars.hcl .
```

From a registry:

```bash
nomad-pack plan nomatron --var-file=production.vars.hcl
nomad-pack run  nomatron --var-file=production.vars.hcl
```

Override individual values:

```bash
nomad-pack run --var-file=production.vars.hcl --var='count=3' .
```

After deploy:

```bash
nomad job status nomatron
nomad-pack status
```

### 6. Other nomad-pack commands

| Command | Purpose |
|---|---|
| `nomad-pack info .` | Pack metadata and variable reference |
| `nomad-pack render --var-file=... .` | Print rendered Nomad job HCL |
| `nomad-pack status` | List pack deployments registered with this CLI |
| `nomad-pack destroy nomatron` | Tear down jobs created by a pack deployment |
| `nomad-pack fmt .` | Format pack templates |

Pack outputs (URLs, next steps) print after a successful `run`. Re-run with the same `--var-file` to upgrade after changing `nomatron_version`.

---

## Next steps

1. Read [packs/nomatron/README.md](packs/nomatron/README.md) — choose a deployment profile and copy the matching variables block.
2. Prepare Nomad clients — [docs/README.md](docs/README.md).
