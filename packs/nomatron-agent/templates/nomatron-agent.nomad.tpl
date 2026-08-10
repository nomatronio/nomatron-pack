[[ template "validate_deployment" . ]]

job [[ template "job_name" . ]] {
  [[ template "region" . ]]
  datacenters = [[ var "datacenters" . | toStringList ]]
  namespace   = [[ var "namespace" . | quote ]]
  type        = "service"

[[ template "job_placement" . ]]

  group "agent" {
    count = [[ var "count" . ]]

[[ template "group_vault_block" . ]]

    update {
      max_parallel      = 1
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
    }

    restart {
      attempts = 10
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    task "nomatron-agent" {
      [[- if eq (var "runtime" .) "docker" ]]
      driver = "docker"

      config {
        image = "ghcr.io/nomatronio/nomatron-releases/nomatron-agent:[[ var "nomatron_agent_version" . ]]"
        args  = ["--config", "${NOMAD_TASK_DIR}/agent.hcl"]
      }
      [[- else if eq (var "binary_install_method" .) "artifact" ]]
      driver = "exec"

      artifact {
        source      = "https://github.com/nomatronio/nomatron-releases/releases/download/[[ var "nomatron_agent_version" . ]]/nomatron-agent_[[ trimPrefix "v" (var "nomatron_agent_version" .) ]]_linux_[[ var "binary_arch" . ]].tar.gz"
        destination = "local/bin"
      }

      config {
        command = "[[ template "binary_artifact_command" . ]]"
        args    = ["--config", "${NOMAD_TASK_DIR}/agent.hcl"]
      }
      [[- else ]]
      driver = "exec"

      config {
        command = [[ var "binary_path" . | quote ]]
        args    = ["--config", "${NOMAD_TASK_DIR}/agent.hcl"]
      }
      [[- end ]]

      template {
        destination = "local/agent.hcl"
        change_mode = "restart"
        data        = <<EOF
server_addrs = [[ var "server_addrs" . | toStringList ]]
http_base_urls = [[ var "http_base_urls" . | toStringList ]]

agent_id = [[ var "agent_id" . | quote ]]
[[ template "agent_token_hcl" . ]]

heartbeat_interval = [[ var "heartbeat_interval" . | quote ]]

log_level  = [[ var "log_level" . | quote ]]
log_format = [[ var "log_format" . | quote ]]

capabilities = [[ var "capabilities" . | toStringList ]]

control_plane_tls_enabled              = [[ var "control_plane_tls_enabled" . ]]
control_plane_tls_insecure_skip_verify = [[ var "control_plane_tls_insecure_skip_verify" . ]]

cluster {
  cluster_id  = [[ var "cluster.cluster_id" . | quote ]]
  address     = [[ var "cluster.address" . | quote ]]
[[ template "cluster_acl_token_hcl" . ]]
  tls_enabled = [[ var "cluster.tls_enabled" . ]]
  skip_verify = [[ var "cluster.skip_verify" . ]]
}
[[- range $idx, $cluster := var "additional_clusters" . ]]

cluster {
  cluster_id  = [[ $cluster.cluster_id | quote ]]
  address     = [[ $cluster.address | quote ]]
  acl_token   = [[ $cluster.acl_token | quote ]]
  tls_enabled = [[ $cluster.tls_enabled ]]
  skip_verify = [[ $cluster.skip_verify ]]
}
[[- end ]]
EOF
      }

      resources {
        cpu    = [[ var "agent_resources.cpu" . ]]
        memory = [[ var "agent_resources.memory" . ]]
      }
    }
  }
}
