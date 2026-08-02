# Contributing to nomatron-pack

## Repository layout

```text
nomatron-pack/
├── packs/nomatron/          # Synced to community registry (registry pack layout only)
│   ├── metadata.hcl
│   ├── variables.hcl
│   ├── templates/
│   ├── outputs.tpl
│   ├── README.md              # Full user README; links to docs/ in this repo
│   ├── CHANGELOG.md
│   ├── examples/
│   └── .ci/                   # Registry CI fixtures
├── docs/                      # Platform guides — NOT synced (repo only)
├── CONTRIBUTING.md
├── LICENSE
└── .github/
```

| Location | Synced? |
|---|---|
| `packs/nomatron/` | Yes — 1:1 to `hashicorp/nomad-pack-community-registry/packs/nomatron/` |
| `docs/` | No — linked from pack README via GitHub URLs |
| Repo root | No |

The sync script copies **only** registry pack files (`templates`, `examples`, `.ci`, `CHANGELOG.md`, `README.md`, `metadata.hcl`, `outputs.tpl`, `variables.hcl`). Nothing else under `packs/nomatron/` is published.

## Day-to-day development

1. Change templates/variables under [`packs/nomatron/`](packs/nomatron/).
2. Change platform guides under [`docs/`](docs/) (repo only).
3. Validate locally:

```bash
cd packs/nomatron
nomad-pack fmt .
nomad-pack render --var-file=examples/production.byodb.vars.hcl.example . > /dev/null
nomad-pack plan  --var-file=examples/production.byodb.vars.hcl.example .
```

4. Update [`packs/nomatron/CHANGELOG.md`](packs/nomatron/CHANGELOG.md) and bump `pack.version` in [`packs/nomatron/metadata.hcl`](packs/nomatron/metadata.hcl).
5. Open a PR in **this** repo.

When editing [`packs/nomatron/README.md`](packs/nomatron/README.md), link to platform docs with absolute GitHub URLs (`https://github.com/nomatronio/nomatron-pack/tree/main/docs/...`) so links work from the community registry cache.

---

## Publishing to the Nomad Pack Community Registry

### Initial submission

1. Fork [hashicorp/nomad-pack-community-registry](https://github.com/hashicorp/nomad-pack-community-registry) to **`nomatronio/nomad-pack-community-registry`**.
2. Sync the pack:

```bash
git clone https://github.com/nomatronio/nomad-pack-community-registry.git
git clone https://github.com/nomatronio/nomatron-pack.git

# From nomatron-pack repo root:
./.github/scripts/sync-community-registry.sh \
  packs/nomatron \
  ../nomad-pack-community-registry/packs/nomatron
```

3. Registry pack layout (same as hello_world / traefik):

```text
packs/nomatron/
├── README.md
├── metadata.hcl
├── variables.hcl
├── CHANGELOG.md
├── outputs.tpl
├── templates/
├── examples/
└── .ci/
```

4. Open a PR against upstream. Request **CODEOWNERS** for `packs/nomatron/` → `@nomatronio/<team>`.

### Release sync

Tag `v*` in this repo after bumping `packs/nomatron/metadata.hcl`. GitHub Actions syncs and opens an upstream PR.

### Per-release checklist

```text
[ ] packs/nomatron/metadata.hcl + CHANGELOG.md updated
[ ] packs/nomatron/README.md doc links still resolve (github.com/nomatronio/nomatron-pack/tree/main/docs/...)
[ ] ./.github/scripts/sync-community-registry.sh dry-run looks correct
[ ] Community registry PR merged
```

## Automated sync

On **`v*` tag** push, [`.github/workflows/sync-community-registry.yml`](.github/workflows/sync-community-registry.yml) validates, syncs whitelisted pack files to the fork, and opens an upstream PR.

**Secret:** `COMMUNITY_REGISTRY_SYNC_TOKEN` on `nomatronio/nomatron-pack`.

Local dry-run:

```bash
./.github/scripts/sync-community-registry.sh packs/nomatron /tmp/packs/nomatron
ls /tmp/packs/nomatron   # should match registry layout only
```

## References

- [Nomad Pack documentation](https://developer.hashicorp.com/nomad/tools/nomad-pack)
- [Community registry](https://github.com/hashicorp/nomad-pack-community-registry)
