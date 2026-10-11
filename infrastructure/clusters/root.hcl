# Shared backend and credential loading. No secret values are committed here.
locals {
  repository_root = dirname(dirname(get_parent_terragrunt_dir()))
  unit_path       = path_relative_to_include()
  state_path      = "${local.repository_root}/.local/states/${local.unit_path}/terraform.tfstate"

  # Keep credentials out of generated provider files. Only Proxmox units consume
  # this exposed map; cluster-bootstrap does not receive the API token.
  proxmox_api_token = get_env("PROXMOX_VE_API_TOKEN", get_env("TF_VAR_virtual_environment_api_token", ""))
  proxmox_credentials = {
    virtual_environment_api_token = local.proxmox_api_token == "" ? null : local.proxmox_api_token
  }
}

generate "backend" {
  path      = "backend.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      backend "local" {
        path = ${jsonencode(local.state_path)}
      }
    }
  EOF
}
