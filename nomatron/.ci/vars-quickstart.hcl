# CI-only variables for community registry validation (nomad-pack render / nomad validate).
# Not for deployment — secrets are placeholders.

deployment_profile = "quickstart"
database_mode      = "provision"
network_mode       = "bridge"
runtime            = "docker"

postgres = {
  image_tag   = "16"
  db_name     = "nomatron"
  username    = "nomatron"
  password    = "nomatron"
  volume_path = "nomatron-postgres"
  cpu         = 500
  memory      = 1024
}

secrets = {
  encryption_key = "Y2ktcGxhY2Vob2xkZXItZW5jcnlwdGlvbi1rZXktbm90LXJlYWw="
  license_key    = "ci-placeholder-license-key"
  cluster_key    = "ci-cluster-key"
}
