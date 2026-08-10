Nomatron Network Agent pack deployed

Job : [[ template "job_name" . ]]
Runtime : [[ var "runtime" . ]]
Version : [[ var "nomatron_agent_version" . ]]
Namespace : [[ var "namespace" . ]]
Count : [[ var "count" . ]]
Agent ID : [[ var "agent_id" . ]]

Primary Nomad API : [[ var "cluster.address" . ]]
Primary cluster ID : [[ var "cluster.cluster_id" . ]]
Secrets backend : [[ var "secrets_backend" . ]]
[[- if eq (var "secrets_backend" .) "nomad_var" ]]
Nomad Variable : [[ var "secrets_nomad_var.path" . ]]
[[- else if eq (var "secrets_backend" .) "vault" ]]
Vault path : [[ var "secrets_vault.path" . ]]
[[- end ]]

--- Post-deploy ---

[] Confirm the allocation can reach the Nomatron control plane (gRPC 4650 and HTTP API)
[] Confirm the allocation can reach the private Nomad API at [[ var "cluster.address" . ]]
[] In the Nomatron UI, verify the Network Agent shows as connected / healthy
[] Prefer one agent per cluster trust boundary unless additional_clusters is intentional

Upgrade : change nomatron_agent_version and redeploy.
