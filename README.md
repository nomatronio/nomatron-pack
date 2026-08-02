# nomatron-pack

Official [Nomad Pack](https://developer.hashicorp.com/nomad/tools/nomad-pack) for deploying [Nomatron](https://nomatron.io) on HashiCorp Nomad.

## Repository layout

```text
nomatron-pack/
├── packs/nomatron/     # Pack synced to community registry (templates, vars, examples, README)
├── docs/               # Platform setup guides (repo only — not synced)
├── CONTRIBUTING.md     # Maintainer workflow
├── LICENSE
└── .github/            # Validate + sync CI
```

| Path | Synced to community registry? |
|---|---|
| `packs/nomatron/` (templates, variables, metadata, outputs, README, CHANGELOG, examples, `.ci/`) | Yes — matches other registry packs |
| `docs/` | No — extended AWS/Azure/GCP/Proxmox/OpenStack/VMware guides live here |
| Repo root (CONTRIBUTING, workflows) | No |

**Pack README:** [packs/nomatron/README.md](packs/nomatron/README.md) — install, profiles, variables, deploy workflow. Links to platform docs in this repo.

**Platform guides:** [docs/README.md](docs/README.md) — VM, firewall, Docker, CNI, load balancing, dedicated nodes.

```bash
git clone https://github.com/nomatronio/nomatron-pack.git
cd nomatron-pack/packs/nomatron
nomad-pack info .
```

Or from the default registry (after publish):

```bash
nomad-pack run nomatron --var-file=production.vars.hcl
```

Maintainers: [CONTRIBUTING.md](CONTRIBUTING.md)
