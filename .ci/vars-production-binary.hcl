# Copyright (c) 2026 Nomatron Ltd
# SPDX-License-Identifier: MPL-2.0
#
# CI-only variables for community registry validation — binary/exec runtime path.
# Not for deployment — secrets are placeholders.

deployment_profile = "production"
database_mode      = "byodb"
network_mode       = "bridge"
runtime            = "binary"
count              = 1

binary_install_method = "host"
binary_path           = "/usr/bin/nomatron"
nomatron_version      = "v0.1.0-rc.45"

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

secrets = {
  encryption_key = "Y2ktcGxhY2Vob2xkZXItZW5jcnlwdGlvbi1rZXktbm90LXJlYWw="
  license_key    = "ci-placeholder-license-key"
  cluster_key    = "ci-cluster-key"
}
