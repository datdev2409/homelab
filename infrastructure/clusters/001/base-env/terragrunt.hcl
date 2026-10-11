include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  cluster = read_terragrunt_config("../cluster.hcl")
}

terraform {
  source = "../../../root_modules//base-env"
}

inputs = merge(local.cluster.locals.base_env, include.root.locals.proxmox_credentials, {
  ssh_public_key = get_env("HOMELAB_SSH_PUBLIC_KEY", "")
  inventory_path = "${include.root.locals.repository_root}/.local/config/clusters/${local.cluster.locals.cluster_id}/inventory.yml"
})

generate "import" {
  path              = "zz_import.tf"
  if_exists         = "overwrite_terragrunt"
  comment_prefix    = "#"
  disable_signature = false
  contents          = <<EOF
# Terragrunt will write this raw HCL content into the target file
moved {
  from = proxmox_virtual_environment_download_file.ubuntu
  to = proxmox_virtual_environment_download_file.media[0]
}

EOF
}
