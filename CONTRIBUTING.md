# Contributing to nomatron-pack

## Repository layout

This repo mirrors the [Nomad Pack Community Registry](https://github.com/hashicorp/nomad-pack-community-registry) layout:

```text
nomatron-pack/
├── packs/nomatron/          # The pack — synced 1:1 to community registry
│   ├── metadata.hcl
│   ├── variables.hcl
│   ├── templates/
│   ├── README.md
│   ├── CHANGELOG.md
│   ├── outputs.tpl
│   ├── examples/
│   ├── docs/                # Extended platform guides (stay in pack)
│   └── .ci/                 # CI fixtures for registry validation
├── CONTRIBUTING.md          # This file — repo maintainer docs
├── LICENSE
└── .github/                 # Validate + sync workflows
```

| Location | Purpose |
|---|---|
| **`packs/nomatron/`** | Develop here. Copied verbatim to `hashicorp/nomad-pack-community-registry/packs/nomatron/` on release. |
| **Repo root** | Maintainer workflow, CI, license — not part of the pack sync. |

## Day-to-day development

1. Change the pack under [`packs/nomatron/`](packs/nomatron/) (templates, variables, docs, examples).
2. Validate locally:

```bash
cd packs/nomatron
nomad-pack fmt .
nomad-pack render --var-file=examples/production.byodb.vars.hcl.example . > /dev/null
nomad-pack plan  --var-file=examples/production.byodb.vars.hcl.example .
```

Use a real `*.vars.hcl` (not `.example`) when planning against a live cluster.

3. Update [`packs/nomatron/CHANGELOG.md`](packs/nomatron/CHANGELOG.md) and bump `pack.version` in [`packs/nomatron/metadata.hcl`](packs/nomatron/metadata.hcl).
4. Open a PR in **this** repo.

---

## Publishing to the Nomad Pack Community Registry

Follow this when opening the **initial** community-registry PR or syncing a **new release**.

### Initial submission

1. Fork [hashicorp/nomad-pack-community-registry](https://github.com/hashicorp/nomad-pack-community-registry) to **`nomatronio/nomad-pack-community-registry`**.
2. Sync the pack (1:1 copy):

```bash
git clone https://github.com/nomatronio/nomad-pack-community-registry.git
git clone https://github.com/nomatronio/nomatron-pack.git

# From nomatron-pack repo root:
./.github/scripts/sync-community-registry.sh \
  packs/nomatron \
  ../nomad-pack-community-registry/packs/nomatron
```

3. Ensure the pack layout matches other registry packs:

```text
packs/nomatron/
├── README.md
├── metadata.hcl
├── variables.hcl
├── CHANGELOG.md
├── outputs.tpl
├── templates/
├── examples/
├── docs/              # optional; full platform guides (recommended)
└── .ci/               # required for community registry CI
    ├── vars-quickstart.hcl
    ├── vars-production.hcl
    ├── vars-production-binary.hcl
    └── vars-ha.hcl
```

4. In `packs/nomatron/metadata.hcl`, set:

```hcl
app {
  url = "https://nomatron.io"
}

pack {
  name        = "nomatron"
  description = "..."
  version     = "0.2.0"   # match this repo's metadata.hcl
}
```

5. In `packs/nomatron/README.md`, include at minimum:

- What Nomatron is and what the pack deploys
- Dependencies: Nomad 1.6+, Linux clients, Docker, CNI (bridge), BYODB for production
- Link to full documentation: `https://github.com/nomatronio/nomatron-pack/tree/main/packs/nomatron/docs`
- Quick start: `nomad-pack run nomatron --var-file=production.vars.hcl`

6. Complete the upstream [PR checklist](https://github.com/hashicorp/nomad-pack-community-registry/blob/main/.github/pull_request_template.md).

7. In the PR description, request **`CODEOWNERS`** for `packs/nomatron/` → `@nomatronio/<team>` so Nomatron maintainers can approve future sync PRs.

8. **License:** this repo is [MPL-2.0](LICENSE), matching the community registry.

### Release sync (every version after the first)

When you tag a release in **this** repo (for example `v0.2.1`):

1. Merge and tag in `nomatronio/nomatron-pack`.
2. Bump `pack.version` in [`packs/nomatron/metadata.hcl`](packs/nomatron/metadata.hcl) and [`packs/nomatron/CHANGELOG.md`](packs/nomatron/CHANGELOG.md).
3. Push the tag — GitHub Actions syncs to the fork and opens an upstream PR (see below).
4. After upstream merge, users refresh with:

```bash
nomad-pack registry update default
# or only this pack:
nomad-pack registry update default --target=nomatron
```

### Per-release checklist

```text
[ ] Changes merged and tagged in nomatronio/nomatron-pack
[ ] packs/nomatron/metadata.hcl version bumped
[ ] packs/nomatron/CHANGELOG.md updated
[ ] packs/nomatron/ synced in community-registry fork
[ ] nomad-pack render / plan verified on synced copy
[ ] Community registry PR opened and merged
[ ] packs/nomatron/README.md still accurate (install path, registry status)
```

### What to sync vs keep local-only

| Include in `packs/nomatron/` | Do not publish |
|---|---|
| `templates/`, `variables.hcl`, `metadata.hcl`, `outputs.tpl` | `homelab.vars.hcl`, `mac-dev.vars.hcl` |
| `examples/*.example` | Any `*.vars.hcl` with real secrets |
| `docs/`, `README.md`, `CHANGELOG.md` | CI secrets, local test state |
| `.ci/vars-*.hcl` | Real secrets — CI placeholders only |

### After the pack is in the community registry

Users install from the default registry:

```bash
nomad-pack list
nomad-pack info nomatron
nomad-pack plan nomatron --var-file=production.vars.hcl
nomad-pack run  nomatron --var-file=production.vars.hcl
```

Update [`packs/nomatron/README.md`](packs/nomatron/README.md) section **“Get this pack”** once the initial community-registry PR is merged.

## Automated sync to the community registry

On every **`v*` git tag** push, [`.github/workflows/sync-community-registry.yml`](.github/workflows/sync-community-registry.yml):

1. Verifies `packs/nomatron/metadata.hcl` `pack.version` matches the tag (e.g. tag `v0.2.0` → version `"0.2.0"`)
2. Runs `nomad-pack render` for each `packs/nomatron/.ci/vars-*.hcl` fixture
3. Rsyncs `packs/nomatron/` → `packs/nomatron/` on the **fork** (1:1)
4. Opens a PR against **`hashicorp/nomad-pack-community-registry`**

### One-time setup

1. **Fork** [hashicorp/nomad-pack-community-registry](https://github.com/hashicorp/nomad-pack-community-registry) to **`nomatronio/nomad-pack-community-registry`**.

2. **Create a PAT** with `contents: write` on the fork and permission to open PRs upstream.

3. Add repository secret to **`nomatronio/nomatron-pack`**:
   - `COMMUNITY_REGISTRY_SYNC_TOKEN`

### Release workflow

```bash
# 1. Bump packs/nomatron/metadata.hcl pack.version and CHANGELOG.md
# 2. Commit, tag, push
git tag v0.2.0
git push origin v0.2.0
# 3. GitHub Actions opens PR: nomatron/sync-v0.2.0 → hashicorp/nomad-pack-community-registry
# 4. Review and merge upstream PR after CI passes
```

Manual re-run: **Actions → Sync community registry → Run workflow** (optional `tag` input).

Local dry-run:

```bash
./.github/scripts/sync-community-registry.sh packs/nomatron /tmp/packs/nomatron
```

Pull-request validation: [`.github/workflows/validate-pack.yml`](.github/workflows/validate-pack.yml).

## References

- [Nomad Pack documentation](https://developer.hashicorp.com/nomad/tools/nomad-pack)
- [Create custom packs](https://developer.hashicorp.com/nomad/tools/nomad-pack/create-packs)
- [Community registry](https://github.com/hashicorp/nomad-pack-community-registry)
- [Community registry PR template](https://github.com/hashicorp/nomad-pack-community-registry/blob/main/.github/pull_request_template.md)
