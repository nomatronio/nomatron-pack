[[- define "job_name" -]]
[[ coalesce ( var "job_name" .) (meta "pack.name" .) | quote ]]
[[- end -]]

[[ define "region" -]]
[[- if var "region" . -]]
  region = "[[ var "region" . ]]"
[[- end -]]
[[- end -]]

[[ define "constraints" -]]
[[ range $idx, $constraint := . ]]
  constraint {
    attribute = [[ $constraint.attribute | quote ]]
    [[ if $constraint.operator -]]
    operator  = [[ $constraint.operator | quote ]]
    [[ end -]]
    value     = [[ $constraint.value | quote ]]
  }
[[ end -]]
[[- end -]]

[[ define "env_vars" -]]
        [[- range $idx, $var := . ]]
        [[ $var.key ]] = [[ $var.value | quote ]]
        [[- end ]]
[[- end ]]

[[- define "validate_deployment" -]]
[[- $profile := var "deployment_profile" . -]]
[[- $count := var "count" . -]]
[[- $dbMode := var "database_mode" . -]]
[[- if and (ne $profile "quickstart") (ne $profile "production") (ne $profile "ha") -]]
[[ fail "deployment_profile must be quickstart, production, or ha." ]]
[[- end -]]
[[- if eq $profile "production" -]]
[[- if ne $dbMode "byodb" -]]
[[ fail "deployment_profile=production requires database_mode=byodb with HA PostgreSQL (managed service, Patroni leader URL, or equivalent). Use deployment_profile=quickstart for provisioned Postgres." ]]
[[- end -]]
[[- if gt $count 1 -]]
[[ fail "deployment_profile=production requires count=1. Use deployment_profile=ha for multiple Nomatron servers." ]]
[[- end -]]
[[- if and (eq (var "database.sslmode" .) "disable") (or (eq (var "database.connection_string" .) "") (not (contains "sslmode=" (var "database.connection_string" .)))) -]]
[[ fail "deployment_profile=production requires TLS to PostgreSQL: set database.sslmode=require or include sslmode=require in database.connection_string." ]]
[[- end -]]
[[- if and (eq (var "server.api_addr" .) "") (eq (var "public_hostname" .) "") -]]
[[ fail "deployment_profile=production requires server.api_addr or public_hostname so Nomatron advertises the URL users and webhooks reach." ]]
[[- end -]]
[[- end -]]
[[- if eq $profile "ha" -]]
[[- if ne $dbMode "byodb" -]]
[[ fail "deployment_profile=ha requires database_mode=byodb. For lab Nomatron HA with provisioned Postgres, use deployment_profile=quickstart with count>1 (see https://github.com/nomatronio/nomatron-pack/blob/main/examples/ha.provision-lab.vars.hcl.example)." ]]
[[- end -]]
[[- if lt $count 2 -]]
[[ fail "deployment_profile=ha requires count >= 2 (recommended: 3)." ]]
[[- end -]]
[[- if and (eq (var "database.sslmode" .) "disable") (or (eq (var "database.connection_string" .) "") (not (contains "sslmode=" (var "database.connection_string" .)))) -]]
[[ fail "deployment_profile=ha requires TLS to PostgreSQL: set database.sslmode=require or include sslmode=require in database.connection_string." ]]
[[- end -]]
[[- end -]]
[[- if eq (var "database_mode" .) "provision" -]]
[[- if ne (var "network_mode" .) "bridge" -]]
[[ fail "database_mode=provision requires network_mode=bridge so Nomatron and Postgres can share a network namespace." ]]
[[- end -]]
[[- end -]]
[[- if eq $dbMode "byodb" -]]
[[- if and (eq (var "database.connection_string" .) "") (eq (var "database.host" .) "") -]]
[[ fail "database_mode=byodb requires database.connection_string or database.host." ]]
[[- end -]]
[[- if and (eq (var "database.connection_string" .) "") (eq (var "database.password" .) "") -]]
[[ fail "database_mode=byodb requires database.password when using component fields (database.host)." ]]
[[- end -]]
[[- end -]]
[[- if gt $count 1 -]]
[[- if eq (var "serf.encrypt_key" .) "" -]]
[[ fail "serf.encrypt_key is required when count > 1. Generate one with: nomatron keygen" ]]
[[- end -]]
[[- if eq (len (var "serf.retry_join" .)) 0 -]]
[[ fail "serf.retry_join is required when count > 1." ]]
[[- end -]]
[[- end -]]
[[- $provider := var "service_provider" . -]]
[[- if and (ne $provider "nomad") (ne $provider "consul") -]]
[[ fail "service_provider must be nomad or consul." ]]
[[- end -]]
[[- if eq (var "secrets.encryption_key" .) "" -]]
[[ fail "secrets.encryption_key is required. Generate one with: openssl rand -base64 32" ]]
[[- end -]]
[[- end -]]

[[- define "nomatron_service_tags" -]]
[[- if gt (len (var "service_tags" .)) 0 -]]
[[ var "service_tags" . | toStringList ]]
[[- else -]]
[[- $hostname := var "public_hostname" . -]]
[[- if eq $hostname "" -]]
[[- $hostname = "nomatron.example.com" -]]
[[- end -]]
[[- $tags := list
  "traefik.enable=true"
  (printf "traefik.http.routers.nomatron.rule=Host(`%s`)" $hostname)
  "traefik.http.services.nomatron.loadbalancer.server.port=4649"
-]]
[[ $tags | toStringList ]]
[[- end -]]
[[- end -]]

[[- define "nomatron_server_env" -]]
        NOMATRON_ENCRYPTION_KEY = [[ var "secrets.encryption_key" . | quote ]]
        NOMATRON_LICENSE_KEY    = [[ var "secrets.license_key" . | quote ]]
        NOMATRON_CLUSTER_KEY    = [[ var "secrets.cluster_key" . | quote ]]
[[- if ne (var "bootstrap.root_username" .) "" ]]
        NOMATRON_ROOT_USERNAME  = [[ var "bootstrap.root_username" . | quote ]]
[[- end ]]
[[- if ne (var "bootstrap.root_password" .) "" ]]
        NOMATRON_ROOT_PASSWORD  = [[ var "bootstrap.root_password" . | quote ]]
[[- end ]]
[[- template "env_vars" (var "extra_env_vars" .) -]]
[[- end -]]

[[- define "postgres_task" -]]
    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:[[ var "postgres.image_tag" . ]]"
        ports = ["db"]
      }

      volume_mount {
        volume      = "postgres-data"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }

      env {
        POSTGRES_DB       = [[ var "postgres.db_name" . | quote ]]
        POSTGRES_USER     = [[ var "postgres.username" . | quote ]]
        POSTGRES_PASSWORD = [[ var "postgres.password" . | quote ]]
        PGDATA            = "/var/lib/postgresql/data"
      }

      resources {
        cpu    = [[ var "postgres.cpu" . ]]
        memory = [[ var "postgres.memory" . ]]
      }

      service {
        name     = [[ var "postgres.service_name" . | quote ]]
        port     = "db"
        provider = [[ var "service_provider" . | quote ]]
        tags     = ["postgres", "nomatron-internal"]
[[- if and (eq (var "database_mode" .) "provision") (gt (var "count" .) 1) ]]
        address_mode = "host"
[[- end ]]

        check {
          name     = "postgres-tcp"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
[[- end -]]

[[- define "nomatron_server_task" -]]
    task "nomatron" {
      driver = [[ if eq (var "runtime" .) "docker" -]]"docker"[[- else -]]"exec"[[- end ]]

[[- if eq (var "runtime" .) "docker" ]]
      config {
        image = "ghcr.io/nomatronio/nomatron-releases/nomatron:[[ var "nomatron_version" . ]]"
        ports = ["http", "grpc", "serf"]
        args  = ["server", "--config", "${NOMAD_TASK_DIR}/config/nomatron.hcl"]
      }
[[- else if eq (var "binary_install_method" .) "artifact" ]]
      artifact {
        source      = "https://github.com/nomatronio/nomatron-releases/releases/download/[[ var "nomatron_version" . ]]/nomatron_[[ trimPrefix "v" (var "nomatron_version" .) ]]_linux_[[ var "binary_arch" . ]].tar.gz"
        destination = "local/bin"
      }

      config {
        command = "${NOMAD_ALLOC_DIR}/local/bin/nomatron"
        args    = ["server", "--config", "${NOMAD_TASK_DIR}/config/nomatron.hcl"]
      }
[[- else ]]
      config {
        command = [[ var "binary_path" . | quote ]]
        args    = ["server", "--config", "${NOMAD_TASK_DIR}/config/nomatron.hcl"]
      }
[[- end ]]

      resources {
        cpu    = [[ var "nomatron_resources.cpu" . ]]
        memory = [[ var "nomatron_resources.memory" . ]]
      }

      template {
        data = <<EOH
server {
  port = [[ var "server.port" . ]]
  api_addr = [[ if ne (var "server.api_addr" .) "" ]][[ var "server.api_addr" . | quote ]][[ else if ne (var "public_hostname" .) "" ]][[ printf "%s://%s" (var "public_scheme" .) (var "public_hostname" .) | quote ]][[ else ]][[ printf "http://127.0.0.1:%v" (var "server.port" .) | quote ]][[ end ]]
  log_level = [[ var "server.log_level" . | quote ]]
  log_format = [[ var "server.log_format" . | quote ]]
  read_header_timeout_seconds = [[ var "server.read_header_timeout_seconds" . ]]
  read_timeout_seconds = [[ var "server.read_timeout_seconds" . ]]
  write_timeout_seconds = [[ var "server.write_timeout_seconds" . ]]
  idle_timeout_seconds = [[ var "server.idle_timeout_seconds" . ]]
[[- if gt (len (var "server.trusted_origins" .)) 0 ]]
  trusted_origins = [[ var "server.trusted_origins" . | toStringList ]]
[[- end ]]
[[- if var "server.tls_enabled" . ]]
  tls_enabled = true
[[- if ne (var "server.tls_cert_file" .) "" ]]
  tls_cert_file = [[ var "server.tls_cert_file" . | quote ]]
[[- end ]]
[[- if ne (var "server.tls_key_file" .) "" ]]
  tls_key_file = [[ var "server.tls_key_file" . | quote ]]
[[- end ]]
[[- if ne (var "server.tls_ca_file" .) "" ]]
  tls_ca_file = [[ var "server.tls_ca_file" . | quote ]]
[[- end ]]
[[- else ]]
  tls_enabled = false
[[- end ]]
}

database {
  connection_string = [[ if and (eq (var "database_mode" .) "provision") (gt (var "count" .) 1) ]][[ if eq (var "service_provider" .) "consul" ]][[ printf "postgres://%s:%s@{{ with service %s }}{{ with index . 0 }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}/%s?sslmode=disable" (var "postgres.username" .) (var "postgres.password" .) (var "postgres.service_name" . | quote) (var "postgres.db_name" .) | quote ]][[ else ]][[ printf "postgres://%s:%s@{{ with nomadService %s }}{{ with index . 0 }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}/%s?sslmode=disable" (var "postgres.username" .) (var "postgres.password" .) (var "postgres.service_name" . | quote) (var "postgres.db_name" .) | quote ]][[ end ]][[ else if eq (var "database_mode" .) "provision" ]][[ printf "postgres://%s:%s@127.0.0.1:5432/%s?sslmode=disable" (var "postgres.username" .) (var "postgres.password" .) (var "postgres.db_name" .) | quote ]][[ else if ne (var "database.connection_string" .) "" ]][[ var "database.connection_string" . | quote ]][[ else ]][[ printf "postgres://%s:%s@%s:%v/%s?sslmode=%s" (var "database.username" .) (var "database.password" .) (var "database.host" .) (var "database.port" .) (var "database.name" .) (var "database.sslmode" .) | quote ]][[ end ]]
[[- if gt (var "database.max_open_conns" .) 0 ]]
  max_open_conns = [[ var "database.max_open_conns" . ]]
[[- end ]]
[[- if gt (var "database.max_idle_conns" .) 0 ]]
  max_idle_conns = [[ var "database.max_idle_conns" . ]]
[[- end ]]
[[- if gt (var "database.conn_max_lifetime_seconds" .) 0 ]]
  conn_max_lifetime_seconds = [[ var "database.conn_max_lifetime_seconds" . ]]
[[- end ]]
[[- if gt (var "database.conn_max_idle_time_seconds" .) 0 ]]
  conn_max_idle_time_seconds = [[ var "database.conn_max_idle_time_seconds" . ]]
[[- end ]]
}

serf {
  node_name = "[[- if ne (var "serf.node_name" .) "" -]][[ var "serf.node_name" . ]][[- else -]]{{ env "NOMAD_ALLOC_ID" }}[[- end -]]"
  bind_addr = [[ var "serf.bind_addr" . | quote ]]
  port = [[ var "serf.port" . ]]
[[- if ne (var "serf.advertise_addr" .) "" ]]
  advertise_addr = [[ var "serf.advertise_addr" . | quote ]]
[[- end ]]
[[- if gt (var "count" .) 1 ]]
[[- if ne (var "serf.encrypt_key" .) "" ]]
  encrypt_key = [[ var "serf.encrypt_key" . | quote ]]
[[- end ]]
[[- if gt (len (var "serf.retry_join" .)) 0 ]]
  retry_join = [[ var "serf.retry_join" . | toStringList ]]
[[- end ]]
[[- if ne (var "serf.retry_join_interval" .) "" ]]
  retry_join_interval = [[ var "serf.retry_join_interval" . | quote ]]
[[- end ]]
[[- if ge (var "serf.retry_join_max" .) 0 ]]
  retry_join_max = [[ var "serf.retry_join_max" . ]]
[[- end ]]
[[- end ]]
}

operations {
  max_inflight_per_cluster = [[ var "operations.max_inflight_per_cluster" . ]]
}

licensing {
  mode = [[ var "licensing.mode" . | quote ]]
  keygen_base_url = [[ var "licensing.keygen_base_url" . | quote ]]
[[- if ne (var "licensing.relay_base_url" .) "" ]]
  relay_base_url = [[ var "licensing.relay_base_url" . | quote ]]
[[- end ]]
[[- if ne (var "licensing.trusted_account_id" .) "" ]]
  trusted_account_id = [[ var "licensing.trusted_account_id" . | quote ]]
[[- end ]]
[[- if ne (var "licensing.trusted_public_key" .) "" ]]
  trusted_public_key = [[ var "licensing.trusted_public_key" . | quote ]]
[[- end ]]
[[- if gt (len (var "licensing.trusted_product_ids" .)) 0 ]]
  trusted_product_ids = [[ var "licensing.trusted_product_ids" . | toStringList ]]
[[- end ]]
[[- if ne (var "licensing.usage_refresh_every" .) "" ]]
  usage_refresh_every = [[ var "licensing.usage_refresh_every" . | quote ]]
[[- end ]]
}

telemetry {
  enabled = [[ var "telemetry.enabled" . ]]
[[- if ne (var "telemetry.http_proxy" .) "" ]]
  http_proxy = [[ var "telemetry.http_proxy" . | quote ]]
[[- end ]]
[[- if ne (var "telemetry.https_proxy" .) "" ]]
  https_proxy = [[ var "telemetry.https_proxy" . | quote ]]
[[- end ]]
}
EOH
        destination = "local/config/nomatron.hcl"
        change_mode = "restart"
      }

      env {
        NOMATRON_ENCRYPTION_KEY = [[ var "secrets.encryption_key" . | quote ]]
        NOMATRON_LICENSE_KEY    = [[ var "secrets.license_key" . | quote ]]
        NOMATRON_CLUSTER_KEY    = [[ var "secrets.cluster_key" . | quote ]]
        NOMATRON_DB_URL         = [[ if and (eq (var "database_mode" .) "provision") (gt (var "count" .) 1) ]][[ if eq (var "service_provider" .) "consul" ]][[ printf "postgres://%s:%s@{{ with service %s }}{{ with index . 0 }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}/%s?sslmode=disable" (var "postgres.username" .) (var "postgres.password" .) (var "postgres.service_name" . | quote) (var "postgres.db_name" .) | quote ]][[ else ]][[ printf "postgres://%s:%s@{{ with nomadService %s }}{{ with index . 0 }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}/%s?sslmode=disable" (var "postgres.username" .) (var "postgres.password" .) (var "postgres.service_name" . | quote) (var "postgres.db_name" .) | quote ]][[ end ]][[ else if eq (var "database_mode" .) "provision" ]][[ printf "postgres://%s:%s@127.0.0.1:5432/%s?sslmode=disable" (var "postgres.username" .) (var "postgres.password" .) (var "postgres.db_name" .) | quote ]][[ else if ne (var "database.connection_string" .) "" ]][[ var "database.connection_string" . | quote ]][[ else ]][[ printf "postgres://%s:%s@%s:%v/%s?sslmode=%s" (var "database.username" .) (var "database.password" .) (var "database.host" .) (var "database.port" .) (var "database.name" .) (var "database.sslmode" .) | quote ]][[ end ]]
[[ if ne (var "bootstrap.root_username" .) "" ]]
        NOMATRON_ROOT_USERNAME  = [[ var "bootstrap.root_username" . | quote ]]
[[ end ]]
[[ if ne (var "bootstrap.root_password" .) "" ]]
        NOMATRON_ROOT_PASSWORD  = [[ var "bootstrap.root_password" . | quote ]]
[[ end ]]
[[ template "env_vars" (var "extra_env_vars" .) ]]
      }
    }
[[- end -]]

[[- define "effective_api_addr" -]]
[[- if ne (var "server.api_addr" .) "" -]]
[[ var "server.api_addr" . ]]
[[- else if ne (var "public_hostname" .) "" -]]
[[ var "public_scheme" . ]]://[[ var "public_hostname" . ]]
[[- else -]]
http://127.0.0.1:[[ var "server.port" . ]]
[[- end -]]
[[- end -]]

[[- define "nomatron_service_block" -]]
      service {
        name     = [[ var "service_name" . | quote ]]
        port     = "http"
        tags     = [[ template "nomatron_service_tags" . ]]
        provider = [[ var "service_provider" . | quote ]]

        check {
          name     = "nomatron-health"
          type     = "http"
          path     = "/api/v1/health?bootstrap=ok"
          interval = "10s"
          timeout  = "3s"
        }
      }
[[- end -]]
