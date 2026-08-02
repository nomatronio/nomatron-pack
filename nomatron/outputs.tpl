Nomatron pack deployed — reference architecture profile: [[ var "deployment_profile" . ]]

Job:              [[ template "job_name" . ]]
Profile:          [[ var "deployment_profile" . ]]
Database mode:    [[ var "database_mode" . ]]
Runtime:          [[ var "runtime" . ]]
Nomatron servers: [[ var "count" . ]]
Version:          [[ var "nomatron_version" . ]]
Load balancer:    [[ var "load_balancer_mode" . ]]
Service provider: [[ var "service_provider" . ]]

API address:      [[ template "effective_api_addr" . ]]
Health check:     [[ template "effective_api_addr" . ]]/api/v1/health?bootstrap=ok
Web UI:           [[ template "effective_api_addr" . ]]/ui
Setup wizard:     [[ template "effective_api_addr" . ]]/ui/setup

[[- if eq (var "database_mode" .) "provision" ]]
Database:         provisioned Postgres (lab only — not production)[[ if gt (var "count" .) 1 ]] — 1 Postgres, [[ var "count" . ]] Nomatron servers[[ end ]]
[[- else ]]
Database:         BYODB writer — [[ if ne (var "database.host" .) "" ]][[ var "database.host" . ]]:[[ var "database.port" . ]]/[[ var "database.name" . ]][[ else ]]see database.connection_string[[ end ]]
[[- end ]]

[[- if eq (var "load_balancer_mode" .) "traefik" ]]
Traefik job:      [[ var "traefik.job_name" . ]] (HTTP port [[ var "traefik.http_port" . ]])
[[- end ]]

--- Post-deploy runbook ---

Secrets (must stay stable for this environment):
  [ ] encryption_key — same value for all redeploys sharing this database
  [ ] license_key, cluster_key — match your license / other environments
[[- if gt (var "count" .) 1 ]]
  [ ] serf.encrypt_key — identical on every Nomatron server
[[- end ]]

Database:
[[- if eq (var "database_mode" .) "byodb" ]]
  [ ] Writer endpoint reachable from every Nomatron allocation
  [ ] TLS enabled (sslmode=require or stricter)
  [ ] Pool size: count([[ var "count" . ]]) × max_open_conns < Postgres max_connections
[[- else ]]
  [ ] Lab provision only — migrate to BYODB before production
[[- end ]]
  [ ] Initialize via /ui/setup or bootstrap.auto_init_database (first boot only)

Nomatron:
  [ ] server.api_addr matches the URL users and webhooks use
[[- if ne (var "server.api_addr" .) "" ]]
  [ ] api_addr configured: [[ var "server.api_addr" . ]]
[[- else if ne (var "public_hostname" .) "" ]]
  [ ] public_hostname configured: [[ var "public_hostname" . ]]
[[- end ]]
  [ ] Health check returns ok=true after database initialized
  [ ] Register Nomad cluster(s) in the Nomatron UI

[[- if gt (var "count" .) 1 ]]
HA:
  [ ] Serf cluster formed — verify retry_join addresses match deployed nodes
  [ ] Nomad spread placed servers on distinct clients (check: nomad job status)
[[- end ]]

Upgrade: change nomatron_version and redeploy (rolling update when count > 1).
