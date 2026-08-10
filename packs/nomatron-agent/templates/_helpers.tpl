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

[[- define "job_placement" -]]
  node_pool   = [[ var "node_pool" . | quote ]]

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }
[[- if gt (len (var "constraints" .)) 0 ]]
  [[ template "constraints" (var "constraints" .) ]]
[[- end ]]
[[- end -]]

[[- define "validate_deployment" -]]
[[- $runtime := var "runtime" . -]]
[[- if and (ne $runtime "docker") (ne $runtime "binary") -]]
[[ fail "runtime must be docker or binary." ]]
[[- end -]]
[[- if eq (len (var "server_addrs" .)) 0 -]]
[[ fail "server_addrs is required (Nomatron gRPC host:port, typically :4650)." ]]
[[- end -]]
[[- if eq (len (var "http_base_urls" .)) 0 -]]
[[ fail "http_base_urls is required (Nomatron HTTP base URL, typically https://host:4649)." ]]
[[- end -]]
[[- if eq (var "agent_id" .) "" -]]
[[ fail "agent_id is required (Network Agent UUID from Nomatron)." ]]
[[- end -]]
[[- if eq (var "cluster.cluster_id" .) "" -]]
[[ fail "cluster.cluster_id is required." ]]
[[- end -]]
[[- if eq (var "cluster.address" .) "" -]]
[[ fail "cluster.address is required (private Nomad API URL reachable from the task)." ]]
[[- end -]]
[[- $secretsBackend := var "secrets_backend" . -]]
[[- if and (ne $secretsBackend "pack_vars") (ne $secretsBackend "nomad_var") (ne $secretsBackend "vault") -]]
[[ fail "secrets_backend must be pack_vars, nomad_var, or vault." ]]
[[- end -]]
[[- if eq $secretsBackend "pack_vars" -]]
[[- if eq (var "secrets.agent_token" .) "" -]]
[[ fail "secrets.agent_token is required when secrets_backend=pack_vars." ]]
[[- end -]]
[[- else if eq $secretsBackend "nomad_var" -]]
[[- if eq (var "secrets_nomad_var.path" .) "" -]]
[[ fail "secrets_backend=nomad_var requires secrets_nomad_var.path." ]]
[[- end -]]
[[- else if eq $secretsBackend "vault" -]]
[[- if eq (var "secrets_vault.path" .) "" -]]
[[ fail "secrets_backend=vault requires secrets_vault.path." ]]
[[- end -]]
[[- end -]]
[[- if and (eq $runtime "binary") (eq (var "binary_install_method" .) "host") (eq (var "binary_path" .) "") -]]
[[ fail "binary_install_method=host requires binary_path." ]]
[[- end -]]
[[- end -]]

[[- define "group_vault_block" -]]
[[- if eq (var "secrets_backend" .) "vault" ]]
    vault {
      policies = [[ var "secrets_vault.policies" . | toStringList ]]
    }
[[- end ]]
[[- end -]]

[[- define "agent_token_hcl" -]]
[[- $path := var "secrets_nomad_var.path" . -]]
[[- $kToken := coalesce (var "secrets_nomad_var.keys.agent_token" .) "agent_token" -]]
[[- $vPath := var "secrets_vault.path" . -]]
[[- $vToken := coalesce (var "secrets_vault.keys.agent_token" .) "agent_token" -]]
[[- if eq (var "secrets_backend" .) "pack_vars" ]]
agent_token = [[ var "secrets.agent_token" . | quote ]]
[[- else if eq (var "secrets_backend" .) "nomad_var" ]]
agent_token = {{ with nomadVar "[[ $path ]]" }}{{ index . "[[ $kToken ]]" | toJSON }}{{ end }}
[[- else if eq (var "secrets_backend" .) "vault" ]]
agent_token = {{ with secret "[[ $vPath ]]" }}{{ .Data.data.[[ $vToken ]] | toJSON }}{{ end }}
[[- end ]]
[[- end -]]

[[- define "cluster_acl_token_hcl" -]]
[[- $path := var "secrets_nomad_var.path" . -]]
[[- $kAcl := coalesce (var "secrets_nomad_var.keys.nomad_acl_token" .) "nomad_acl_token" -]]
[[- $vPath := var "secrets_vault.path" . -]]
[[- $vAcl := coalesce (var "secrets_vault.keys.nomad_acl_token" .) "nomad_acl_token" -]]
[[- if eq (var "secrets_backend" .) "pack_vars" ]]
  acl_token   = [[ var "cluster.acl_token" . | quote ]]
[[- else if eq (var "secrets_backend" .) "nomad_var" ]]
  acl_token   = {{ with nomadVar "[[ $path ]]" }}{{ index . "[[ $kAcl ]]" | toJSON }}{{ end }}
[[- else if eq (var "secrets_backend" .) "vault" ]]
  acl_token   = {{ with secret "[[ $vPath ]]" }}{{ .Data.data.[[ $vAcl ]] | toJSON }}{{ end }}
[[- end ]]
[[- end -]]

[[- define "binary_artifact_command" -]]
local/bin/nomatron-agent
[[- end -]]
