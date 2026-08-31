# CI render fixture for packs/nomatron-agent
namespace = "default"
node_pool = "default"

nomatron_agent_version = "v0.1.0-rc.20"
runtime                = "docker"

server_addrs   = ["nomatron.example.com:4650"]
http_base_urls = ["https://nomatron.example.com"]

agent_id = "00000000-0000-0000-0000-000000000001"

cluster = {
  cluster_id  = "00000000-0000-0000-0000-000000000002"
  address     = "https://nomad.internal.example.com:4646"
  acl_token   = "ci-acl-token"
  tls_enabled = false
  skip_verify = false
}

secrets = {
  agent_token = "ci-agent-token"
}
