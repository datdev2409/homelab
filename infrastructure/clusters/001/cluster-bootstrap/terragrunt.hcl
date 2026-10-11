include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../root_modules//cluster-bootstrap"
}

# The source is not implemented. The orchestration must run Ansible and verify
# Kubernetes readiness before this unit; a dependency on VMs alone is insufficient.
