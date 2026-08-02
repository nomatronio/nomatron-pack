# nomatron-pack

Official [Nomad Pack](https://developer.hashicorp.com/nomad/tools/nomad-pack) for deploying [Nomatron](https://nomatron.io) on HashiCorp Nomad.

This repository follows the same layout as the [Nomad Pack Community Registry](https://github.com/hashicorp/nomad-pack-community-registry): the pack lives under **`packs/nomatron/`** and is copied verbatim to the community registry on release.

| Path | Purpose |
|---|---|
| [`packs/nomatron/`](packs/nomatron/) | **The pack** — templates, variables, examples, platform docs (synced to community registry) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Maintainer workflow, CI, community registry publish |
| [LICENSE](LICENSE) | MPL-2.0 (repo and pack) |
| [`.github/`](.github/) | Validate and sync workflows |

**Start here:** [packs/nomatron/README.md](packs/nomatron/README.md)

```bash
git clone https://github.com/nomatronio/nomatron-pack.git
cd nomatron-pack/packs/nomatron
nomad-pack info .
```

Or add this repo as a custom registry (same layout as the community registry):

```bash
nomad-pack registry add nomatronio github.com/nomatronio/nomatron-pack --target=nomatron
nomad-pack info nomatron --registry=nomatronio
```
