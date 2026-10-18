#!/usr/bin/env bash
# Copyright (c) 2026 Nomatron Ltd
# SPDX-License-Identifier: MPL-2.0
#
# Assert secret_change_mode resolution and HA runtime secret placement.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK="${ROOT}/packs/nomatron"
RENDERED="$(mktemp -d)"
VARS="$(mktemp -d)"
trap 'rm -rf "${RENDERED}" "${VARS}"' EXIT

render_job() {
  local var_file="$1"
  rm -rf "${RENDERED:?}/"*
  nomad-pack render --var-file="${var_file}" -o "${RENDERED}" "${PACK}" >/dev/null
  find "${RENDERED}/nomatron" -name '*.nomad' -print -quit
}

count_change_modes() {
  local job="$1"
  local mode="$2"
  grep -c "change_mode = \"${mode}\"" "${job}" || true
}

assert_ha_runtime_secret_layout() {
  local job="$1"
  python3 - "${job}" <<'PY'
import re
import sys

job_path = sys.argv[1]
text = open(job_path, encoding="utf-8").read()

if re.search(r"encrypt_key\s*=\s*\{\{-?\s*with nomadVar", text):
    sys.exit("serf encrypt_key must not be inline in nomatron.hcl via nomadVar")
if re.search(r"destination\s*=\s*\"local/", text):
    for m in re.finditer(
        r"template\s*\{(.*?)\n\s*\}",
        text,
        flags=re.S,
    ):
        block = m.group(1)
        if 'destination = "local/' not in block:
            continue
        if re.search(r"nomadVar|with secret|\.Data\.data", block):
            sys.exit("local/ template must not read nomadVar, Vault secret, or .Data.data")
        if re.search(r"serf_encrypt_key|encrypt_key", block):
            sys.exit("serf key material must not appear in local/ templates")

runtime_markers = (
    r"nomadVar",
    r"with secret",
    r"\.Data\.data",
)
for m in re.finditer(
    r"template\s*\{(.*?)\n\s*\}",
    text,
    flags=re.S,
):
    block = m.group(1)
    if 'change_mode = "restart"' not in block:
        continue
    if any(re.search(p, block) for p in runtime_markers):
        sys.exit("restart-mode template must not read Nomad Variables or Vault")

if "secrets/serf.key" not in text:
    sys.exit("expected ${NOMAD_SECRETS_DIR}/secrets/serf.key template")
if "--serf-encrypt-key-file=${NOMAD_SECRETS_DIR}/secrets/serf.key" not in text:
    sys.exit("expected --serf-encrypt-key-file in server args")
PY
}

cat > "${VARS}/ha-default.hcl" <<'EOF'
deployment_profile = "ha"
database_mode      = "byodb"
network_mode       = "bridge"
runtime            = "docker"
count              = 2
nomatron_version   = "v0.1.1"
secrets_backend    = "nomad_var"
secrets_nomad_var = {
  path = "nomad/jobs/nomatron/nomatron-server/nomatron"
}
load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649
public_hostname    = "nomatron.ci.example.com"
public_scheme      = "https"
database = {
  host                       = "db-writer.ci.example.com"
  port                       = 5432
  name                       = "nomatron"
  username                   = "nomatron"
  sslmode                    = "require"
  connection_string          = ""
  password                   = ""
  max_open_conns             = 25
  max_idle_conns             = 10
  conn_max_lifetime_seconds  = 300
  conn_max_idle_time_seconds = 60
}
server = {
  port                          = 4649
  api_addr                      = "https://nomatron.ci.example.com"
  trusted_origins               = ["https://nomatron.ci.example.com"]
  log_level                     = "info"
  log_format                    = "json"
  read_header_timeout_seconds   = 10
  read_timeout_seconds          = 30
  write_timeout_seconds         = 60
  idle_timeout_seconds          = 120
  tls_enabled                   = true
  tls_cert_file                 = ""
  tls_key_file                  = ""
  tls_ca_file                   = ""
}
serf = {
  node_name           = ""
  bind_addr           = "0.0.0.0"
  advertise_addr      = ""
  port                = 7946
  retry_join          = ["10.0.0.10:7946", "10.0.0.11:7946"]
  retry_join_interval = "30s"
  retry_join_max      = 0
  encrypt_key         = ""
  tags                = {}
  gossip_interval_ms  = 0
  gossip_nodes        = 0
  probe_interval_ms   = 0
  probe_timeout_ms    = 0
}
secrets = {
  encryption_key = ""
  license_key    = ""
  cluster_key    = ""
}
EOF

JOB="$(render_job "${VARS}/ha-default.hcl")"
noop_count="$(count_change_modes "${JOB}" noop)"
if [[ "${noop_count}" -lt 5 ]]; then
  echo "expected at least 5 change_mode = noop for HA (secrets + TLS + serf), got ${noop_count}" >&2
  exit 1
fi
assert_ha_runtime_secret_layout "${JOB}"

JOB="$(render_job "${ROOT}/.ci/vars-secret-change-single.hcl")"
restart_count="$(count_change_modes "${JOB}" restart)"
if [[ "${restart_count}" -lt 5 ]]; then
  echo "expected at least 5 change_mode = restart for count=1 (config + secrets + TLS), got ${restart_count}" >&2
  exit 1
fi
if grep -q 'change_mode = "noop"' "${JOB}"; then
  echo "did not expect change_mode = noop for count=1 default" >&2
  exit 1
fi

cp "${VARS}/ha-default.hcl" "${VARS}/ha-restart.hcl"
echo 'secret_change_mode = "restart"' >> "${VARS}/ha-restart.hcl"
JOB="$(render_job "${VARS}/ha-restart.hcl")"
restart_ha="$(count_change_modes "${JOB}" restart)"
if [[ "${restart_ha}" -lt 5 ]]; then
  echo "expected explicit secret_change_mode=restart on HA runtime templates, got ${restart_ha} restart stanzas" >&2
  exit 1
fi

cp "${VARS}/ha-default.hcl" "${VARS}/ha-invalid.hcl"
echo 'secret_change_mode = "invalid"' >> "${VARS}/ha-invalid.hcl"
if nomad-pack render --var-file="${VARS}/ha-invalid.hcl" -o "${RENDERED}" "${PACK}" >/dev/null 2>&1; then
  echo "expected render failure for invalid secret_change_mode" >&2
  exit 1
fi

cp "${VARS}/ha-default.hcl" "${VARS}/ha-old-version.hcl"
sed -i 's/nomatron_version   = "v0.1.1"/nomatron_version   = "v0.1.0-rc.45"/' "${VARS}/ha-old-version.hcl"
if nomad-pack render --var-file="${VARS}/ha-old-version.hcl" -o "${RENDERED}" "${PACK}" >/dev/null 2>&1; then
  echo "expected render failure for HA nomad_var below v0.1.1" >&2
  exit 1
fi

echo "secret_change_mode render tests passed"
