include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  cluster = read_terragrunt_config("../cluster.hcl").locals
}

terraform {
  source = "../../../root_modules//cluster-bootstrap"
}

# Ansible and Kubernetes readiness checks must precede this independent unit.
inputs = merge(local.cluster.cluster_bootstrap, {
  kubeconfig_path = "${include.root.locals.repository_root}/.local/config/${local.cluster.cluster_id}/kubeconfig.yaml"
})
