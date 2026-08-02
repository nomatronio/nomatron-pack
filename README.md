# nomatron-pack

Official [Nomad Pack](https://developer.hashicorp.com/nomad/tools/nomad-pack) for deploying [Nomatron](https://nomatron.io) on HashiCorp Nomad.

## Repository layout

```text
nomatron-pack/
├── packs/nomatron/     # Synced to community registry (6 items only)
│   ├── templates/
│   ├── variables.hcl
│   ├── metadata.hcl
│   ├── outputs.tpl
│   ├── README.md
│   └── CHANGELOG.md
├── docs/               # Platform setup guides (repo only)
├── examples/           # Example var files (repo only)
├── .ci/                # CI render fixtures (repo only)
├── CONTRIBUTING.md
├── LICENSE
└── .github/
```

| Path | Synced to community registry? |
|---|---|
| `packs/nomatron/` | Yes — registry pack files only |
| `docs/`, `examples/`, `.ci/` | No |

**Pack README:** [packs/nomatron/README.md](packs/nomatron/README.md)

**Platform guides:** [docs/README.md](docs/README.md)

**Example var files:** [examples/](examples/)

```bash
git clone https://github.com/nomatronio/nomatron-pack.git
cd nomatron-pack/packs/nomatron
cp ../../examples/production.byodb.vars.hcl.example production.vars.hcl
nomad-pack plan --var-file=production.vars.hcl .
```

Maintainers: [CONTRIBUTING.md](CONTRIBUTING.md)
