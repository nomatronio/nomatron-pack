# Copyright (c) 2026 Nomatron Ltd
# SPDX-License-Identifier: MPL-2.0

# ---------------------------------------------------------------------------
# Top-level deployment knobs
# ---------------------------------------------------------------------------

variable "deployment_profile" {
  description = "Reference architecture preset: quickstart (demo/lab), production (single Nomatron + BYODB), or ha (multi-server Nomatron + shared BYODB). Enforced by pack validation — see README."
  type        = string
  default     = "quickstart"
}

variable "database_mode" {
  description = "Database strategy: byodb (production — HA PostgreSQL writer) or provision (lab — colocated Postgres task). To try Nomatron without Nomad, run: nomatron server --dev"
  type        = string
  default     = "provision"
}

variable "runtime" {
  description = "Nomatron runtime: docker (container image) or binary (exec driver)."
  type        = string
  default     = "docker"
}

variable "load_balancer_mode" {
  description = "Load balancer integration: none (direct access), service (register with Nomad/Consul for Traefik/Fabio), or traefik (also deploy a Traefik system job)."
  type        = string
  default     = "none"
}

variable "nomatron_version" {
  description = "Nomatron release version tag (for example v0.1.0-rc.45). Used for container image and binary artifact URLs. HA on Nomad requires v0.1.0-rc.45 or later so Serf registration uses NOMAD_HOST_IP_serf."
  type        = string
  default     = "v0.1.0-rc.45"
}

# ---------------------------------------------------------------------------
# Nomad job placement
# ---------------------------------------------------------------------------

variable "job_name" {
  description = "Nomad job name. When empty, the pack name is used."
  type        = string
  default     = ""
}

variable "region" {
  description = "Nomad region for the job."
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Nomad namespace for the job."
  type        = string
  default     = "default"
}

variable "datacenters" {
  description = "Datacenters eligible for task placement."
  type        = list(string)
  default     = ["*"]
}

variable "node_pool" {
  description = "Nomad node pool for the job."
  type        = string
  default     = "default"
}

variable "count" {
  description = "Number of Nomatron server instances. Use 1 for single-node quickstart. Use 2+ for HA with Serf clustering (BYODB or provisioned Postgres)."
  type        = number
  default     = 1
}

variable "constraints" {
  description = "Job-level constraints."
  type = list(object({
    attribute = string
    operator  = string
    value     = string
  }))
  default = []
}

variable "network_mode" {
  description = "Group network mode. Use bridge (default, requires Linux CNI plugins) for colocated Postgres or shared task networking. Use standard for macOS BYODB (ports only, no bridge CNI)."
  type        = string
  default     = "bridge"
}

variable "nomatron_resources" {
  description = "CPU and memory for the Nomatron server task."
  type = object({
    cpu    = number
    memory = number
  })
  default = {
    cpu    = 1000
    memory = 2048
  }
}

variable "http_port_static" {
  description = "Optional static host port for HTTP when load_balancer_mode=none."
  type        = number
  default     = 0
}

variable "grpc_port_static" {
  description = "Optional static host port for agent gRPC. Leave 0 so Nomad assigns a dynamic host port (recommended when Traefik on the same client already binds 4650). Do not set 4650 on a client that also runs the Traefik TCP entrypoint."
  type        = number
  default     = 0
}

variable "agent_grpc_advertise_addr" {
  description = "Public host:port Host Agents dial for gRPC (TCP load balancer or tunnel in front of Traefik). When empty, Nomatron defaults to the API hostname on port 443, which is wrong for HTTP(S) reverse proxies. Example: xxxxx.a.pinggy.io:12345"
  type        = string
  default     = ""
}

variable "register_grpc_service" {
  description = "Register a Nomad service for agent gRPC with Traefik TCP passthrough tags. Requires a Traefik TCP entrypoint named nomatron-grpc."
  type        = bool
  default     = false
}

variable "grpc_service_name" {
  description = "Nomad service name for agent gRPC. Use the same name on every HA alloc so Traefik load-balances them."
  type        = string
  default     = "nomatron-grpc"
}

variable "grpc_service_tags" {
  description = "Service tags for the gRPC service. When empty, Traefik TCP passthrough tags are generated for entrypoint nomatron-grpc."
  type        = list(string)
  default     = []
}

variable "traefik_grpc_port" {
  description = "TCP entrypoint port on the pack-deployed Traefik job (load_balancer_mode=traefik). Pinggy/TCP LBs should target this port on the Traefik client, not a Nomatron IP."
  type        = number
  default     = 4650
}

variable "serf_port_static" {
  description = "Optional static host port for Serf gossip. Recommended for HA. The group port label serf also interpolates NOMAD_HOST_PORT_serf (typically 7946)."
  type        = number
  default     = 7946
}

# ---------------------------------------------------------------------------
# Binary runtime (runtime=binary)
# ---------------------------------------------------------------------------

variable "binary_install_method" {
  description = "Binary install method: artifact (download release tarball) or host (use pre-installed binary on the client)."
  type        = string
  default     = "artifact"
}

variable "binary_path" {
  description = "Path to the nomatron binary on the client when binary_install_method=host."
  type        = string
  default     = "/usr/local/bin/nomatron"
}

variable "binary_arch" {
  description = "CPU architecture for artifact downloads (amd64 or arm64)."
  type        = string
  default     = "amd64"
}

# ---------------------------------------------------------------------------
# Server configuration (maps to server { } block and NOMATRON_* env vars)
# ---------------------------------------------------------------------------

variable "server" {
  description = "Nomatron server settings."
  type = object({
    port                        = number
    api_addr                    = string
    trusted_origins             = list(string) # CSRF allowlist — full origins with scheme, e.g. https://nomatron.example.com
    log_level                   = string
    log_format                  = string
    read_header_timeout_seconds = number
    read_timeout_seconds        = number
    write_timeout_seconds       = number
    idle_timeout_seconds        = number
    tls_enabled                 = bool
    tls_cert_file               = string
    tls_key_file                = string
    tls_ca_file                 = string
  })
  default = {
    port                        = 4649
    api_addr                    = ""
    trusted_origins             = []
    log_level                   = "info"
    log_format                  = "text"
    read_header_timeout_seconds = 10
    read_timeout_seconds        = 30
    write_timeout_seconds       = 60
    idle_timeout_seconds        = 120
    tls_enabled                 = false
    tls_cert_file               = ""
    tls_key_file                = ""
    tls_ca_file                 = ""
  }
}

variable "tls_secrets_keys" {
  description = "Nomad Variable or Vault data keys for origin TLS PEMs when server.tls_enabled is true and tls_cert_file/tls_key_file are empty. Written to NOMAD_SECRETS_DIR at alloc start. Set ca to \"\" to skip tls_ca_file."
  type = object({
    cert = string
    key  = string
    ca   = string
  })
  default = {
    cert = "tls_cert"
    key  = "tls_key"
    ca   = "tls_ca"
  }
}

variable "traefik_origin_insecure_skip_verify" {
  description = "When server.tls_enabled, append Traefik tags so the Traefik→Nomatron hop uses HTTPS and skips origin cert verify (private CA). Set false if Traefik trusts the origin CA."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Database configuration (database_mode=byodb)
# ---------------------------------------------------------------------------

variable "database" {
  description = "PostgreSQL connection settings. Provide connection_string or host/port/name/username/password/sslmode."
  type = object({
    connection_string          = string
    host                       = string
    port                       = number
    name                       = string
    username                   = string
    password                   = string
    sslmode                    = string
    max_open_conns             = number
    max_idle_conns             = number
    conn_max_lifetime_seconds  = number
    conn_max_idle_time_seconds = number
  })
  default = {
    connection_string          = ""
    host                       = ""
    port                       = 5432
    name                       = "nomatron"
    username                   = "nomatron"
    password                   = ""
    sslmode                    = "disable"
    max_open_conns             = 25
    max_idle_conns             = 10
    conn_max_lifetime_seconds  = 300
    conn_max_idle_time_seconds = 60
  }
}

# ---------------------------------------------------------------------------
# Provisioned Postgres (database_mode=provision)
# ---------------------------------------------------------------------------

variable "postgres" {
  description = "Provisioned Postgres settings when database_mode=provision. Not for production use. volume_path is the Nomad host volume NAME (registered on the client), not a filesystem path — see README. When count > 1, a single Postgres task is deployed and Nomatron servers connect via Nomad service discovery."
  type = object({
    image_tag    = string
    db_name      = string
    username     = string
    password     = string
    volume_path  = string
    service_name = string
    host_port    = number
    cpu          = number
    memory       = number
  })
  default = {
    image_tag    = "16"
    db_name      = "nomatron"
    username     = "nomatron"
    password     = "nomatron"
    volume_path  = "nomatron-postgres"
    service_name = "nomatron-postgres"
    host_port    = 5432
    cpu          = 500
    memory       = 1024
  }
}

# ---------------------------------------------------------------------------
# Serf / HA clustering
# ---------------------------------------------------------------------------

variable "serf" {
  description = "Serf cluster settings for HA deployments. Leave advertise_addr empty so each allocation uses NOMAD_HOST_IP_serf (the Nomad client IP from port label serf). Do not advertise bridge/CNI allocation IPs. retry_join must list reachable client IPs; that is not a substitute for NOMAD_HOST_IP_serf."
  type = object({
    node_name           = string
    bind_addr           = string
    advertise_addr      = string
    port                = number
    retry_join          = list(string)
    retry_join_interval = string
    retry_join_max      = number
    encrypt_key         = string
    tags                = map(string)
    gossip_interval_ms  = number
    gossip_nodes        = number
    probe_interval_ms   = number
    probe_timeout_ms    = number
  })
  default = {
    node_name           = ""
    bind_addr           = "0.0.0.0"
    advertise_addr      = ""
    port                = 7946
    retry_join          = []
    retry_join_interval = "30s"
    retry_join_max      = 0
    encrypt_key         = ""
    tags                = {}
    gossip_interval_ms  = 0
    gossip_nodes        = 0
    probe_interval_ms   = 0
    probe_timeout_ms    = 0
  }
}

# ---------------------------------------------------------------------------
# Licensing, telemetry, operations, bootstrap
# ---------------------------------------------------------------------------

variable "licensing" {
  description = "Nomatron licensing settings. Prefer secrets.license_key and secrets.cluster_key for sensitive values."
  type = object({
    mode                = string
    keygen_base_url     = string
    relay_base_url      = string
    trusted_account_id  = string
    trusted_public_key  = string
    trusted_product_ids = list(string)
    usage_refresh_every = string
  })
  default = {
    mode                = "connected"
    keygen_base_url     = "https://api.keygen.sh"
    relay_base_url      = ""
    trusted_account_id  = ""
    trusted_public_key  = ""
    trusted_product_ids = []
    usage_refresh_every = "15m"
  }
}

variable "telemetry" {
  description = "Nomatron telemetry settings."
  type = object({
    enabled     = bool
    http_proxy  = string
    https_proxy = string
  })
  default = {
    enabled     = true
    http_proxy  = ""
    https_proxy = ""
  }
}

variable "operations" {
  description = "Nomatron operations settings."
  type = object({
    max_inflight_per_cluster = number
  })
  default = {
    max_inflight_per_cluster = 1
  }
}

variable "bootstrap" {
  description = "Database bootstrap settings for first-time initialization."
  type = object({
    root_username      = string
    root_password      = string
    auto_init_database = bool
  })
  default = {
    root_username      = "root"
    root_password      = ""
    auto_init_database = false
  }
}

variable "secrets_backend" {
  description = "How sensitive values reach the task: pack_vars (rendered into the job spec — dev/homelab only), nomad_var (Nomad Variables at runtime — recommended for production), or vault (HashiCorp Vault KV at runtime)."
  type        = string
  default     = "pack_vars"
}

variable "secrets" {
  description = "Secrets when secrets_backend=pack_vars. Pass via -var-file at deploy time; never commit real values. For production, prefer secrets_backend=nomad_var or vault so values are not stored in the Nomad job specification."
  type = object({
    encryption_key = string
    license_key    = string
    cluster_key    = string
  })
  default = {
    encryption_key = ""
    license_key    = ""
    cluster_key    = ""
  }
}

variable "secrets_nomad_var" {
  description = "Nomad Variable path and key names when secrets_backend=nomad_var. Default path follows Nomad's job-scoped convention: nomad/jobs/<job>/<group>/<task>."
  type = object({
    path = string
    keys = object({
      encryption_key   = string
      license_key      = string
      cluster_key      = string
      db_url           = string
      serf_encrypt_key = string
      root_password    = string
    })
  })
  default = {
    path = ""
    keys = {
      encryption_key   = "encryption_key"
      license_key      = "license_key"
      cluster_key      = "cluster_key"
      db_url           = "db_url"
      serf_encrypt_key = "serf_encrypt_key"
      root_password    = "root_password"
    }
  }
}

variable "secrets_vault" {
  description = "Vault KV v2 settings when secrets_backend=vault. path is the full secret path (for example secret/data/nomatron/production). keys map Nomad env / config field names to Vault data keys."
  type = object({
    policies = list(string)
    path     = string
    keys = object({
      encryption_key   = string
      license_key      = string
      cluster_key      = string
      db_url           = string
      serf_encrypt_key = string
      root_password    = string
    })
  })
  default = {
    policies = ["nomatron"]
    path     = ""
    keys = {
      encryption_key   = "encryption_key"
      license_key      = "license_key"
      cluster_key      = "cluster_key"
      db_url           = "db_url"
      serf_encrypt_key = "serf_encrypt_key"
      root_password    = "root_password"
    }
  }
}

variable "extra_env_vars" {
  description = "Additional NOMATRON_* environment variables for the server task."
  type = list(object({
    key   = string
    value = string
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Load balancer / service registration
# ---------------------------------------------------------------------------

variable "public_hostname" {
  description = "Public hostname for Nomatron (used to derive api_addr and Traefik router rules when server.api_addr is empty)."
  type        = string
  default     = ""
}

variable "public_scheme" {
  description = "URL scheme for api_addr when derived from public_hostname (http or https)."
  type        = string
  default     = "https"
}

variable "register_service" {
  description = "Register a Nomad service for Nomatron when load_balancer_mode is service or traefik."
  type        = bool
  default     = false
}

variable "service_name" {
  description = "Nomad service name for Nomatron."
  type        = string
  default     = "nomatron"
}

variable "service_provider" {
  description = "Service registration provider: nomad (native discovery, default) or consul. Provision HA (database_mode=provision, count>1) uses nomadService or Consul service templates respectively to resolve postgres.service_name."
  type        = string
  default     = "nomad"
}

variable "service_tags" {
  description = "Service tags for load balancer integration. When empty, Traefik-friendly tags are generated from public_hostname."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Traefik deployment (load_balancer_mode=traefik)
# ---------------------------------------------------------------------------

variable "traefik" {
  description = "Traefik system job settings when load_balancer_mode=traefik."
  type = object({
    job_name     = string
    version      = string
    cpu          = number
    memory       = number
    network_mode = string
    http_port    = number
    admin_port   = number
  })
  default = {
    job_name     = "traefik"
    version      = "2.11.10"
    cpu          = 500
    memory       = 256
    network_mode = "host"
    http_port    = 80
    admin_port   = 8080
  }
}
