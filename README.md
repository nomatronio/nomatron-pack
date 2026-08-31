# nomatron-pack

Official [Nomad Pack](https://developer.hashicorp.com/nomad/tools/nomad-pack) repository for deploying [Nomatron](https://nomatron.io) on HashiCorp Nomad.

| Pack | Path | Purpose |
|---|---|---|
| **nomatron** | [packs/nomatron/](packs/nomatron/) | Nomatron **server** (control plane) — primary production deploy path |
| **nomatron-agent** | [packs/nomatron-agent/](packs/nomatron-agent/) | Nomatron **Network Agent** (private Nomad connectivity) |

These packs are siblings: deploy them independently. The agent often runs on a different Nomad cluster than the server.

**Platform setup guides:** [docs/README.md](docs/README.md) — AWS, Azure, GCP, Proxmox, OpenStack, VMware (repo only, not synced to the community registry).

Maintainers: [CONTRIBUTING.md](CONTRIBUTING.md)

## Repository layout

```text
nomatron-pack/
├── packs/nomatron/         # Server pack (synced to community registry)
├── packs/nomatron-agent/   # Network Agent pack (synced to community registry)
├── docs/                   # Platform guides + screenshots (repo only)
├── examples/               # Example *.vars.hcl.example files (repo only)
├── .ci/                    # CI fixtures (repo only)
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
nomad-pack version
```

Full install options: [Nomad Pack documentation](https://developer.hashicorp.com/nomad/tools/nomad-pack).

### 2. Connect to your Nomad cluster

```bash
export NOMAD_ADDR=https://nomad.example.com:4646
export NOMAD_TOKEN=<token>   # when ACLs are enabled

nomad node status
```

### 3. Get a pack

#### Option A — Clone and run locally

```bash
git clone https://github.com/nomatronio/nomatron-pack.git
cd nomatron-pack/packs/nomatron          # or packs/nomatron-agent

nomad-pack info .
```

#### Option B — Custom registry (this repo)

```bash
nomad-pack registry add nomatronio \
  github.com/nomatronio/nomatron-pack \
  --target=nomatron

nomad-pack list --registry=nomatronio
nomad-pack info nomatron --registry=nomatronio
nomad-pack info nomatron-agent --registry=nomatronio
```

Pin a release:

```bash
nomad-pack registry add nomatronio \
  github.com/nomatronio/nomatron-pack \
  --target=nomatron \
  --ref=v0.2.0
```

### 4. Create your variables file

**Try Nomatron (no license):** run `nomatron server --dev` on your machine — see [Try Nomatron](packs/nomatron/README.md#try-nomatron-not-the-nomad-pack).

For the server pack, copy an example from [examples/](examples/) or the [server pack README](packs/nomatron/README.md).

For the agent pack, start from [examples/agent.vars.hcl.example](examples/agent.vars.hcl.example) or the [agent pack README](packs/nomatron-agent/README.md).

### 5. Plan and deploy

Always **plan** before **run**:

```bash
# Server (from packs/nomatron/)
nomad-pack plan --var-file=production.vars.hcl .
nomad-pack run  --var-file=production.vars.hcl .

# Agent (from packs/nomatron-agent/)
nomad-pack plan --var-file=agent.vars.hcl .
nomad-pack run  --var-file=agent.vars.hcl .
```

From a registry:

```bash
nomad-pack plan nomatron --var-file=production.vars.hcl --registry=nomatronio
nomad-pack run  nomatron --var-file=production.vars.hcl --registry=nomatronio

nomad-pack plan nomatron-agent --var-file=agent.vars.hcl --registry=nomatronio
nomad-pack run  nomatron-agent --var-file=agent.vars.hcl --registry=nomatronio
```

After deploy:

```bash
nomad job status nomatron
nomad job status nomatron-agent
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

---

## Next steps

1. Server: [packs/nomatron/README.md](packs/nomatron/README.md) — choose a deployment profile.
2. Agent: [packs/nomatron-agent/README.md](packs/nomatron-agent/README.md) — control-plane endpoints and cluster credentials.
3. Prepare Nomad clients — [docs/README.md](docs/README.md).
