# ---------------------------------------------------------------------------
# Top-level deployment knobs
# ---------------------------------------------------------------------------

variable "runtime" {
  description = "Network Agent runtime: docker (container image) or binary (exec driver)."
  type        = string
  default     = "docker"
}

variable "nomatron_agent_version" {
  description = "Nomatron agent release version tag (for example v0.1.0-rc.20). Used for container image and binary artifact URLs."
  type        = string
  default     = "v0.1.0-rc.20"
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
  description = "Nomad namespace for the job. Prefer a dedicated namespace such as nomatron-agents."
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
  description = "Number of Network Agent instances. Start with 1 per private network / cluster trust boundary."
  type        = number
  default     = 1
}

variable "constraints" {
  description = "Job-level constraints. Place the agent where it can reach the private Nomad API and Nomatron control plane."
  type = list(object({
    attribute = string
    operator  = string
    value     = string
  }))
  default = []
}

variable "agent_resources" {
  description = "CPU and memory for the Network Agent task."
  type = object({
    cpu    = number
    memory = number
  })
  default = {
    cpu    = 500
    memory = 256
  }
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
  description = "Path to the nomatron-agent binary on the client when binary_install_method=host."
  type        = string
  default     = "/usr/local/bin/nomatron-agent"
}

variable "binary_arch" {
  description = "CPU architecture for artifact downloads (amd64 or arm64)."
  type        = string
  default     = "amd64"
}

# ---------------------------------------------------------------------------
# Agent configuration (maps to agent.hcl)
# ---------------------------------------------------------------------------

variable "server_addrs" {
  description = "Nomatron control-plane gRPC addresses (host:port), typically port 4650."
  type        = list(string)
  default     = []
}

variable "http_base_urls" {
  description = "Nomatron HTTP API base URLs (scheme://host[:port]), typically port 4649."
  type        = list(string)
  default     = []
}

variable "agent_id" {
  description = "Network Agent UUID from Nomatron."
  type        = string
  default     = ""
}

variable "heartbeat_interval" {
  description = "Agent heartbeat interval."
  type        = string
  default     = "15s"
}

variable "log_level" {
  description = "Agent log level."
  type        = string
  default     = "info"
}

variable "log_format" {
  description = "Agent log format: text or json."
  type        = string
  default     = "text"
}

variable "capabilities" {
  description = "Agent capabilities advertised to the control plane."
  type        = list(string)
  default     = ["nomad_proxy", "job_events"]
}

variable "control_plane_tls_enabled" {
  description = "Enable TLS when connecting to the Nomatron control plane."
  type        = bool
  default     = false
}

variable "control_plane_tls_insecure_skip_verify" {
  description = "Skip TLS verification for the Nomatron control plane (lab only). Maps to control_plane_tls_insecure_skip_verify in agent.hcl."
  type        = bool
  default     = false
}

variable "cluster" {
  description = "Primary Nomad cluster the agent connects to."
  type = object({
    cluster_id  = string
    address     = string
    acl_token   = string
    tls_enabled = bool
    skip_verify = bool
  })
  default = {
    cluster_id  = ""
    address     = ""
    acl_token   = ""
    tls_enabled = false
    skip_verify = false
  }
}

variable "additional_clusters" {
  description = "Optional extra Nomad clusters served by the same agent process. Prefer separate agents unless clusters share a network and ownership boundary."
  type = list(object({
    cluster_id  = string
    address     = string
    acl_token   = string
    tls_enabled = bool
    skip_verify = bool
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------

variable "secrets_backend" {
  description = "How sensitive values reach the task: pack_vars (rendered into the job — lab only), nomad_var (Nomad Variables — recommended), or vault (HashiCorp Vault KV)."
  type        = string
  default     = "pack_vars"
}

variable "secrets" {
  description = "Sensitive values when secrets_backend=pack_vars."
  type = object({
    agent_token = string
  })
  default = {
    agent_token = ""
  }
}

variable "secrets_nomad_var" {
  description = "Nomad Variable path and key names when secrets_backend=nomad_var."
  type = object({
    path = string
    keys = object({
      agent_token     = string
      nomad_acl_token = string
    })
  })
  default = {
    path = "nomad/jobs/nomatron-agent/agent/nomatron-agent"
    keys = {
      agent_token     = "agent_token"
      nomad_acl_token = "nomad_acl_token"
    }
  }
}

variable "secrets_vault" {
  description = "Vault KV path, policies, and key names when secrets_backend=vault."
  type = object({
    path     = string
    policies = list(string)
    keys = object({
      agent_token     = string
      nomad_acl_token = string
    })
  })
  default = {
    path     = "secret/data/nomatron/agent"
    policies = ["nomatron-agent"]
    keys = {
      agent_token     = "agent_token"
      nomad_acl_token = "nomad_acl_token"
    }
  }
}
