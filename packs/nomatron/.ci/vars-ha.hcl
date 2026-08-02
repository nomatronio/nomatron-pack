# CI-only variables for community registry validation (nomad-pack render / nomad validate).
# Not for deployment — secrets are placeholders.

deployment_profile = "ha"
database_mode      = "byodb"
network_mode       = "bridge"
runtime            = "docker"
count              = 3

load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649

public_hostname = "nomatron.ci.example.com"
public_scheme   = "https"

database = {
  connection_string          = "postgres://nomatron:ci@db-writer.ci.example.com:5432/nomatron?sslmode=require"
  host                       = ""
  port                       = 5432
  name                       = "nomatron"
  username                   = "nomatron"
  password                   = ""
  sslmode                    = "require"
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
  tls_enabled                   = false
  tls_cert_file                 = ""
  tls_key_file                  = ""
  tls_ca_file                   = ""
}

serf = {
  node_name           = ""
  bind_addr           = "0.0.0.0"
  advertise_addr      = ""
  port                = 7946
  retry_join          = ["10.0.0.10:7946", "10.0.0.11:7946", "10.0.0.12:7946"]
  retry_join_interval = "30s"
  retry_join_max      = 0
  encrypt_key         = "Y2ktcGxhY2Vob2xkZXItc2VyZi1lbmNyeXB0LWtleS1ub3QtcmVhbA=="
  tags                = {}
  gossip_interval_ms  = 0
  gossip_nodes        = 0
  probe_interval_ms   = 0
  probe_timeout_ms    = 0
}

secrets = {
  encryption_key = "Y2ktcGxhY2Vob2xkZXItZW5jcnlwdGlvbi1rZXktbm90LXJlYWw="
  license_key    = "ci-placeholder-license-key"
  cluster_key    = "ci-cluster-key"
}
