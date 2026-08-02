# CI fixture — production profile with Nomad Variables backend (no secrets in job spec).

deployment_profile = "production"
database_mode      = "byodb"
network_mode       = "bridge"
runtime            = "docker"
count              = 1

secrets_backend = "nomad_var"

secrets_nomad_var = {
  path = "nomad/jobs/nomatron/nomatron-server/nomatron"
}

load_balancer_mode = "none"
register_service   = false
http_port_static   = 4649

public_hostname = "nomatron.ci.example.com"
public_scheme   = "https"

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
  tls_enabled                   = false
  tls_cert_file                 = ""
  tls_key_file                  = ""
  tls_ca_file                   = ""
}
