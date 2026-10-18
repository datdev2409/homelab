locals {
  repository_root  = dirname(dirname(get_terragrunt_dir()))
  environemnt_vars = read_terragrunt_config("env.hcl")
}

terraform {
  source = "../root_modules//cloudflare"
}

# Account-wide state survives any individual Kubernetes cluster teardown.
generate "backend" {
  path      = "backend.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      backend "local" {
        path = ${jsonencode("${local.repository_root}/.local/states/cloudflare/terraform.tfstate")}
      }
    }
  EOF
}

inputs = merge(
  local.environemnt_vars.inputs
)
