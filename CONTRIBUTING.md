# Contributing to nomatron-pack

## Repository layout

```text
nomatron-pack/
├── packs/nomatron/          # Synced to community registry — 6 items only
│   ├── templates/
│   ├── variables.hcl
│   ├── metadata.hcl
│   ├── outputs.tpl
│   ├── README.md
│   └── CHANGELOG.md
├── docs/                    # Platform guides (repo only)
├── examples/                # Example *.vars.hcl.example files (repo only)
├── .ci/                     # CI render fixtures (repo only)
├── CONTRIBUTING.md
├── LICENSE
└── .github/
```

The sync script copies the registry pack files plus `.ci/vars-*.hcl` (placeholder secrets so HashiCorp `validate.sh` can render the pack). `docs/` and `examples/` never leave this repository.

## Day-to-day development

1. Edit pack templates/variables in [`packs/nomatron/`](packs/nomatron/).
2. Edit platform guides in [`docs/`](docs/) and example vars in [`examples/`](examples/).
3. Validate locally:

```bash
cd packs/nomatron
nomad-pack fmt .
nomad-pack render --var-file=../../examples/production.byodb.vars.hcl.example . > /dev/null
nomad-pack plan  --var-file=../../examples/production.byodb.vars.hcl.example .
```

4. Bump `pack.version` in [`packs/nomatron/metadata.hcl`](packs/nomatron/metadata.hcl) and update [`packs/nomatron/CHANGELOG.md`](packs/nomatron/CHANGELOG.md).
5. Open a PR.

When editing [`packs/nomatron/README.md`](packs/nomatron/README.md), keep Nomatron-specific content only; put nomad-pack install/usage in the [root README](README.md). Link to `docs/` with absolute GitHub URLs so links work from the community registry cache.

## Publishing to the community registry

```bash
./.github/scripts/sync-community-registry.sh \
  packs/nomatron \
  ../nomad-pack-community-registry/packs/nomatron
```

Registry layout:

```text
packs/nomatron/
├── templates/
├── variables.hcl
├── metadata.hcl
├── outputs.tpl
├── README.md
└── CHANGELOG.md
```

On **`v*` tag** push, [`.github/workflows/sync-community-registry.yml`](.github/workflows/sync-community-registry.yml) validates, syncs, and opens an upstream PR.

**Secret:** `COMMUNITY_REGISTRY_SYNC_TOKEN` on `nomatronio/nomatron-pack`.

Local dry-run:

```bash
./.github/scripts/sync-community-registry.sh packs/nomatron /tmp/nomatron-sync-test
find /tmp/nomatron-sync-test
```
