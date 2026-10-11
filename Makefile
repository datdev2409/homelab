CLUSTER ?= 001
export TG_TF_PATH ?= tofu

.PHONY: bootstrap teardown fmt-terragrunt plan-base-env apply-base-env
bootstrap:
	@./scripts/bootstrap.sh "$(CLUSTER)"

teardown:
	@./scripts/teardown.sh "$(CLUSTER)"

# Recursively format Terragrunt HCL, excluding generated provider/cache files.
fmt-terragrunt:
	@cd infrastructure && terragrunt hcl fmt --exclude-dir=.terraform --exclude-dir=.terragrunt-cache

# direnv selects global credentials plus the requested cluster's overrides.
plan-base-env:
	@cd "infrastructure/clusters/$(CLUSTER)/base-env" && direnv exec .. sh -c ': "$${PROXMOX_VE_API_TOKEN:?Set the Proxmox token in .local/credentials/.env or the cluster override}"; exec terragrunt plan'

apply-base-env:
	@cd "infrastructure/clusters/$(CLUSTER)/base-env" && direnv exec .. sh -c ': "$${PROXMOX_VE_API_TOKEN:?Set the Proxmox token in .local/credentials/.env or the cluster override}"; exec terragrunt apply'
