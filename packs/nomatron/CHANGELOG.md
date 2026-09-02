## Version v0.2.10 (2026-09-02)

### Fixed

- **Traefik 404 with origin TLS:** stop emitting Nomad `serversTransport` tags. Traefik's Nomad provider cannot create that resource, so the HTTP router disappeared. Skip-verify for a private origin CA belongs in Traefik static config (`serversTransport.insecureSkipVerify=true`).

## Version v0.2.9 (2026-09-02)

### Fixed

- **TLS key permissions:** render `key.pem` as `0444`. The Nomatron image runs as Distroless `nonroot` (uid 65532); Nomad writes alloc secrets as root, so `0400` caused `open /secrets/tls/key.pem: permission denied`. The file stays in `NOMAD_SECRETS_DIR` (not the alloc `local/` tree).

## Version v0.2.8 (2026-09-02)

### Fixed

- **HA `encrypt_key` HCL:** `nomad-pack fmt` split Consul Template `{{` delimiters in the Serf encrypt_key stanza. Nomatron then parsed a literal `| toJSON` as a bitwise OR (`Unsupported operator`). Do not run `nomad-pack fmt` on templates that embed `{{` Nomad/Consul Template.

## Version v0.2.7 (2026-09-02)

### Added

- **Origin TLS from Nomad Variables / Vault:** when `server.tls_enabled = true` and `tls_cert_file` / `tls_key_file` are empty, the pack writes `tls_cert`, `tls_key`, and `tls_ca` from the secrets backend onto `${NOMAD_SECRETS_DIR}/tls/` at alloc start. Do not put PEMs in pack vars or the job spec.
- Traefik HTTP tags use `scheme=https` when origin TLS is on (optional `traefik_origin_insecure_skip_verify` for a private CA).

## Version v0.2.6 (2026-09-02)

### Added

- **Host Agent gRPC via Traefik TCP:** opt-in `register_grpc_service` registers a separate Nomad service (`nomatron-grpc`) with Traefik TCP passthrough tags. Do not put TCP tags on the HTTP `nomatron` service.
- **`agent_grpc_advertise_addr`:** public `host:port` Host Agents dial. When empty, Nomatron advertises the API hostname on port 443, which is the HTTP(S) reverse proxy — not gRPC.
- **`grpc_port_static`:** optional static host port for agent gRPC. Leave `0` (dynamic) when Traefik on the same client already binds `4650`.
- Pack Traefik (`load_balancer_mode=traefik`) adds a `nomatron-grpc` TCP entrypoint on `traefik_grpc_port` (default `4650`) when `register_grpc_service` is true.

## Version v0.2.5 (2026-08-31)

### Fixed

- **Serf advertise_addr in nomatron.hcl:** render the Nomad client IP with Consul Template `{{ env "NOMAD_HOST_IP_serf" }}` instead of `${NOMAD_HOST_IP_serf}`. Nomad does not interpolate `${}` inside template `data`, so the literal variable reached Nomatron's HCL parser and failed with "Variables not allowed".

## Version v0.2.4 (2026-08-31)

### Fixed

- **Community registry CI:** add MPL license headers so HashiCorp copywrite passes, and sync `.ci/vars-*.hcl` into the pack so registry `nomad-pack render` has placeholder secrets.

## Version v0.2.3 (2026-08-31)

### Changed

- Default `nomatron_version` is `v0.1.0-rc.45`. HA on Nomad needs this release (or later) so Serf registration uses the Nomad client IP.

### Fixed

- **Serf host IP registration:** each Nomatron task now sets `NOMAD_HOST_IP_serf` and `NOMAD_HOST_PORT_serf` from the group network port label `serf`. Nomatron rc.45+ writes those values into `server_nodes` when `serf.bind_addr` is `0.0.0.0`. If only `retry_join` is set and the host IP env var is missing, every allocation registers as `127.0.0.1:7946` and hits the unique constraint. Leave `serf.advertise_addr` empty so gossip also advertises the Nomad client IP, not the bridge/CNI address.

## Version v0.2.2 (2026-08-30)

### Fixed

- **`nomad_var` / `vault` database config:** emit a placeholder `connection_string` in `nomatron.hcl` so Nomatron HCL decode succeeds. The real URL still comes from `NOMATRON_DB_URL` at runtime.

## Version v0.2.1 (2026-08-30)

### Fixed

- **Serf `encrypt_key` with Nomad Variables / Vault:** remove extra quotes around `toJSON` in `nomatron.hcl` so HA deployments no longer render `encrypt_key = ""key""` and fail Nomatron config parsing.

## Version v0.2.0 (2026-08-02)

### Added

- **Secrets backends:** `secrets_backend` supports `pack_vars` (default), `nomad_var` (recommended for production), and `vault`. Runtime secrets are injected via Nomad template blocks — not stored in the job specification.
- **Production validation:** `deployment_profile=production|ha` now requires `server.trusted_origins`, and `http_port_static` when `load_balancer_mode=none`.
- **HA runbook:** post-deploy output documents one-time database initialization for HA.
- **Secrets guide:** [docs/common/secrets.md](https://github.com/nomatronio/nomatron-pack/blob/main/docs/common/secrets.md)
- Example vars: `production.byodb.nomad-var.vars.hcl.example`, `production.byodb.vault.vars.hcl.example`

### Removed

- **`database_mode=dev`** — use `nomatron server --dev` to trial Nomatron; this pack is for lab (`provision`) or production (`byodb`) on Nomad only.
- `dev` variable object and `examples/dev.vars.hcl.example`.

### Fixed

- Escape Nomad interpolations in example/README var files (`$${meta.nomatron}`) so `-var-file` works with nomad-pack HCL.
- Default job constraint `attr.kernel.name = linux` (Docker images and release binaries are Linux-only).
- **Binary artifact path:** release tarballs unpack under the task `local/bin/` directory; exec `command` uses that relative path.
- Config file path for Docker tasks: use `${NOMAD_TASK_DIR}/config/nomatron.hcl` (Nomad mounts `local/` as `NOMAD_TASK_DIR`, so do not double the `local/` prefix).
- Serf `node_name` default uses Nomad template `{{ env "NOMAD_ALLOC_ID" }}` instead of literal `${NOMAD_ALLOC_ID}` in `nomatron.hcl` (Nomatron's HCL parser rejects variable interpolation).
- Default `nomatron_version` updated to `v0.1.0-rc.20`.
- Licensing defaults aligned with AWS reference architecture: always emit `keygen_base_url = "https://api.keygen.sh"`; optional `trusted_account_id`, `trusted_public_key`, and `trusted_product_ids`.
- Added `examples/mac-dev.vars.hcl.example` and `.gitignore` for local `*.vars.hcl` secret files.
- Document host volume setup for `database_mode=provision`; default `postgres.volume_path` renamed to `nomatron-postgres` (host volume name, not filesystem path).

### Changed

- Default `database_mode=provision`, `runtime=docker` — lab quickstart requires a vars file (license + secrets).
- Repository layout: synced pack contains registry files only; platform guides in repo-root `docs/`, example vars in repo-root `examples/`.
- Default database pool limits: `max_open_conns=25`, `max_idle_conns=10`
- `deployment_profile` now enforced at render time with profile-specific validation

### Added

- **Platform setup guides** under `docs/` — AWS, Azure, GCP, Proxmox, OpenStack, VMware; dedicated nodes, load balancing, ports, Nomad client setup
- **README:** nomad-pack install, registry vs clone, plan/run workflow, command reference
- **CONTRIBUTING.md:** community registry initial PR and per-release sync checklist
- **LICENSE:** Mozilla Public License 2.0 (MPL-2.0)
- **`.ci/vars-*.hcl`:** community registry CI render/validate fixtures
- **GitHub Actions:** `validate-pack.yml` on PRs; `sync-community-registry.yml` opens upstream PR on `v*` tags
- **Reference architecture profiles** with validated constraints and gold-standard example vars (`production.byodb`, `production.byodb.binary`, `ha.byodb`, `ha.provision-lab`)
- Post-deploy runbook in pack outputs
- **Provision mode HA:** when `database_mode=provision` and `count > 1`, deploy one Postgres task and spread Nomatron servers; Postgres discovery via `nomadService` or Consul `service` template depending on `service_provider`
- README reference architecture section (profile matrix, decision guide, Nomad version requirements, Nomad client sizing for AWS/GCP/Azure)
- Full Nomatron server deployment replacing hello-world scaffold
- `database_mode`: BYODB (`byodb`) or optional colocated Postgres (`provision`)
- `runtime`: Docker container or binary (artifact download or host path)
- HA support with configurable `count`, Serf clustering, and spread constraints
- Load balancer modes: `none`, `service` (Traefik/Fabio tags), and `traefik` (deploy Traefik system job)
- Complete Nomatron configuration via `server`, `database`, `serf`, `licensing`, `telemetry`, and `operations` objects
- Deployment profiles: `quickstart`, `production`, `ha`
- Pack outputs with post-deploy URLs and next steps
- README: Nomad version requirements table; Consul vs native service discovery for provision HA
- `network_mode` variable (`bridge` or `standard`) for Linux CNI vs macOS dev without bridge CNI

## Version v0.0.1

Initial scaffold release.
