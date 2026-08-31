# Contributing to nomatron-pack

## Repository layout

```text
nomatron-pack/
├── packs/nomatron/          # Server pack — synced to community registry
│   ├── templates/
│   ├── variables.hcl
│   ├── metadata.hcl
│   ├── outputs.tpl
│   ├── README.md
│   └── CHANGELOG.md
├── packs/nomatron-agent/    # Network Agent pack — synced to community registry
│   ├── templates/
│   ├── variables.hcl
│   ├── metadata.hcl
│   ├── outputs.tpl
│   ├── README.md
│   └── CHANGELOG.md
├── docs/                    # Platform guides + screenshots (repo only)
├── examples/                # Example *.vars.hcl.example files (repo only)
├── .ci/                     # CI render fixtures (repo only)
├── CONTRIBUTING.md
├── LICENSE
└── .github/
```

The sync script copies **only** the registry pack files for a given pack directory. `docs/`, `examples/`, and `.ci/` never leave this repository.

## Day-to-day development

1. Edit the pack you are changing under [`packs/nomatron/`](packs/nomatron/) or [`packs/nomatron-agent/`](packs/nomatron-agent/).
2. Edit platform guides in [`docs/`](docs/) and example vars in [`examples/`](examples/).
3. Validate locally:

```bash
# Server
cd packs/nomatron
nomad-pack fmt .
nomad-pack render --var-file=../../.ci/vars-production.hcl . > /dev/null

# Agent
cd ../nomatron-agent
nomad-pack fmt .
nomad-pack render --var-file=../../.ci/vars-agent.hcl . > /dev/null
```

4. Bump `pack.version` in that pack’s `metadata.hcl` and update its `CHANGELOG.md`.
5. Open a PR.

When editing pack READMEs, keep product-specific content in the pack README; put nomad-pack install/usage in the [root README](README.md). Link to `docs/` with absolute GitHub URLs so links work from the community registry cache.

CI fixtures: `.ci/vars-*.hcl` render against the **server** pack, except `.ci/vars-agent*.hcl` which render against **nomatron-agent**.

## Publishing to the community registry

```bash
./.github/scripts/sync-community-registry.sh \
  packs/nomatron \
  ../nomad-pack-community-registry/packs/nomatron

./.github/scripts/sync-community-registry.sh \
  packs/nomatron-agent \
  ../nomad-pack-community-registry/packs/nomatron-agent
```

On **`v*` tag** push, [`.github/workflows/sync-community-registry.yml`](.github/workflows/sync-community-registry.yml) validates both packs, syncs both directories, and opens an upstream PR. The git tag must match `packs/nomatron/metadata.hcl` `pack.version`.

**Secret:** `COMMUNITY_REGISTRY_SYNC_TOKEN` on `nomatronio/nomatron-pack`.

Local dry-run:

```bash
./.github/scripts/sync-community-registry.sh packs/nomatron /tmp/nomatron-sync-test
./.github/scripts/sync-community-registry.sh packs/nomatron-agent /tmp/nomatron-agent-sync-test
find /tmp/nomatron-sync-test /tmp/nomatron-agent-sync-test
```

For community-registry review, attach Nomad UI screenshots of the job running (overview, allocations, allocation detail) under [`docs/screenshots/`](docs/screenshots/).
