# Contributing to nomatron-pack

## Repository roles

| Repository | Purpose |
|---|---|
| **[nomatronio/nomatron-pack](https://github.com/nomatronio/nomatron-pack)** (this repo) | **Source of truth** — develop, test, document, tag releases |
| **[hashicorp/nomad-pack-community-registry](https://github.com/hashicorp/nomad-pack-community-registry)** | **Distribution catalog** — vendored copy under `packs/nomatron/` so all `nomad-pack` users receive the pack on `nomad-pack list` |

The community registry does **not** mirror this repo automatically. Each release is synced via pull request.

## Day-to-day development

1. Change the pack under [`nomatron/`](nomatron/) (templates, variables, docs, examples).
2. Validate locally:

```bash
cd nomatron
nomad-pack fmt .
nomad-pack render --var-file=examples/production.byodb.vars.hcl.example . > /dev/null
nomad-pack plan  --var-file=examples/production.byodb.vars.hcl.example .
```

Use a real `*.vars.hcl` (not `.example`) when planning against a live cluster.

3. Update [`nomatron/CHANGELOG.md`](nomatron/CHANGELOG.md) and bump `pack.version` in [`nomatron/metadata.hcl`](nomatron/metadata.hcl).
4. Open a PR in **this** repo.

---

## Publishing to the Nomad Pack Community Registry

Follow this when opening the **initial** community-registry PR or syncing a **new release**.

### Initial submission

1. Fork [hashicorp/nomad-pack-community-registry](https://github.com/hashicorp/nomad-pack-community-registry).
2. Copy the pack into **`packs/nomatron/`**:

```bash
# From a clean checkout of both repos
rsync -a --delete \
  --exclude='homelab.vars.hcl' \
  --exclude='mac-dev.vars.hcl' \
  --exclude='*.vars.hcl' \
  nomatron-pack/nomatron/ \
  nomad-pack-community-registry/packs/nomatron/
```

3. Ensure the community pack layout is complete:

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
- Link to full documentation: `https://github.com/nomatronio/nomatron-pack/tree/main/nomatron/docs`
- Quick start: `nomad-pack run nomatron --var-file=production.vars.hcl`

6. Complete the upstream [PR checklist](https://github.com/hashicorp/nomad-pack-community-registry/blob/main/.github/pull_request_template.md):

- [ ] README covers anything not encoded in the pack
- [ ] `nomad-pack render nomatron` succeeds
- [ ] `nomad-pack plan nomatron` succeeds (with valid vars)
- [ ] Default variable values produce valid HCL
- [ ] Non-default paths tested (HA, provision lab, etc.)
- [ ] Linux / constraint requirements documented

7. In the PR description, request **`CODEOWNERS`** for `packs/nomatron/` → `@nomatronio/<team>` so Nomatron maintainers can approve future sync PRs.

8. **License:** this repo is [MPL-2.0](LICENSE), matching the community registry — no extra steps needed for license compatibility when syncing.

### Release sync (every version after the first)

When you tag a release in **this** repo (for example `v0.2.1`):

1. Merge and tag in `nomatronio/nomatron-pack`.
2. Bump `pack.version` in [`nomatron/metadata.hcl`](nomatron/metadata.hcl) and [`nomatron/CHANGELOG.md`](nomatron/CHANGELOG.md).
3. Sync to your community-registry fork (same `rsync` as above).
4. Bump `pack.version` in `packs/nomatron/metadata.hcl` and append `packs/nomatron/CHANGELOG.md`.
5. Open a PR against `hashicorp/nomad-pack-community-registry` titled e.g. `nomatron: sync pack v0.2.1`.
6. After merge, users refresh with:

```bash
nomad-pack registry update default
# or only this pack:
nomad-pack registry update default --target=nomatron
```

### Per-release checklist

```text
[ ] Changes merged and tagged in nomatronio/nomatron-pack
[ ] nomatron/metadata.hcl version bumped
[ ] nomatron/CHANGELOG.md updated
[ ] packs/nomatron/ synced in community-registry fork
[ ] packs/nomatron/metadata.hcl version matches
[ ] packs/nomatron/CHANGELOG.md updated
[ ] nomad-pack render / plan verified on synced copy
[ ] Community registry PR opened and merged
[ ] nomatron/README.md still accurate (install path, registry status)
```

### What to sync vs keep local-only

| Include in `packs/nomatron/` | Do not publish |
|---|---|
| `templates/`, `variables.hcl`, `metadata.hcl`, `outputs.tpl` | `homelab.vars.hcl`, `mac-dev.vars.hcl` |
| `examples/*.example` | Any `*.vars.hcl` with real secrets |
| `docs/`, `README.md`, `CHANGELOG.md` | CI secrets, local test state |
| `.ci/vars-*.hcl` | Real secrets — CI placeholders only |

### Versioning

| Version | Meaning |
|---|---|
| **`metadata.hcl` → `pack.version`** | Nomatron pack release (`0.2.0`, `0.2.1`, …) — bump on every pack release in both repos |
| **Community registry git tag** (`v0.2.1`) | Snapshot of the entire registry — optional pin for users who want a frozen catalog |

Users on `@latest` get new pack versions after `nomad-pack registry update default`. Users who pin a registry tag only get updates when they change `--ref`.

### After the pack is in the community registry

Users no longer need to clone this repo (unless they want full docs offline or unreleased changes):

```bash
nomad-pack list
nomad-pack info nomatron
nomad-pack plan nomatron --var-file=production.vars.hcl
nomad-pack run  nomatron --var-file=production.vars.hcl
```

Update [`nomatron/README.md`](nomatron/README.md) section **“Get this pack”** once the initial community-registry PR is merged.

## Automated sync to the community registry

On every **`v*` git tag** push, [`.github/workflows/sync-community-registry.yml`](../.github/workflows/sync-community-registry.yml):

1. Verifies `nomatron/metadata.hcl` `pack.version` matches the tag (e.g. tag `v0.2.0` → version `"0.2.0"`)
2. Runs `nomad-pack render` for each `nomatron/.ci/vars-*.hcl` fixture
3. Rsyncs `nomatron/` → `packs/nomatron/` on the **fork**
4. Opens a PR against **`hashicorp/nomad-pack-community-registry`** via [`peter-evans/create-pull-request`](https://github.com/peter-evans/create-pull-request)

### One-time setup

1. **Fork** [hashicorp/nomad-pack-community-registry](https://github.com/hashicorp/nomad-pack-community-registry) to **`nomatronio/nomad-pack-community-registry`** (name must match the workflow default, or edit the workflow env vars).

2. **Create a PAT** (classic) or fine-grained token with:
   - `contents: write` on the fork
   - ability to open pull requests to the upstream repository

3. Add repository secret to **`nomatronio/nomatron-pack`**:
   - `COMMUNITY_REGISTRY_SYNC_TOKEN` — the PAT

4. **First sync:** merge the initial community-registry PR manually if the fork is empty or behind upstream.

### Release workflow

```bash
# 1. Bump nomatron/metadata.hcl pack.version and CHANGELOG.md
# 2. Commit, tag, push
git tag v0.2.0
git push origin v0.2.0
# 3. GitHub Actions opens PR: nomatron/sync-v0.2.0 → hashicorp/nomad-pack-community-registry
# 4. Review and merge upstream PR after CI passes
```

Manual re-run: **Actions → Sync community registry → Run workflow** (optional `tag` input).

Local dry-run:

```bash
./.github/scripts/sync-community-registry.sh nomatron /tmp/packs/nomatron
```

Pull-request validation in this repo: [`.github/workflows/validate-pack.yml`](../.github/workflows/validate-pack.yml) (render + `nomad validate` on PRs).

## References

- [Nomad Pack documentation](https://developer.hashicorp.com/nomad/tools/nomad-pack)
- [Create custom packs](https://developer.hashicorp.com/nomad/tools/nomad-pack/create-packs)
- [Community registry](https://github.com/hashicorp/nomad-pack-community-registry)
- [Community registry PR template](https://github.com/hashicorp/nomad-pack-community-registry/blob/main/.github/pull_request_template.md)
