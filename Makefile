CLUSTER ?= 001
export TG_TF_PATH ?= tofu

.PHONY: bootstrap teardown fmt-terragrunt plan-base-env apply-base-env plan-cluster-bootstrap apply-cluster-bootstrap plan-cloudflare apply-cloudflare port-forward-argocd generate-seal-secret
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

# Run after Ansible and kubeconfig retrieval; no Proxmox token is required.
plan-cluster-bootstrap:
	@cd "infrastructure/clusters/$(CLUSTER)/cluster-bootstrap" && direnv exec .. terragrunt plan

apply-cluster-bootstrap:
	@cd "infrastructure/clusters/$(CLUSTER)/cluster-bootstrap" && direnv exec .. terragrunt apply

# Account-wide Cloudflare resources use global credentials and their own state.
plan-cloudflare:
	@cd infrastructure/cloudflare && direnv exec ../.. sh -c ': "$${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN in .local/credentials/.env}"; exec terragrunt plan'

apply-cloudflare:
	@cd infrastructure/cloudflare && direnv exec ../.. sh -c ': "$${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN in .local/credentials/.env}"; exec terragrunt apply'

# Open https://localhost:8080; stop the port-forward with Ctrl-C.
port-forward-argocd:
	@kubectl --kubeconfig ".local/config/$(CLUSTER)/kubeconfig.yaml" -n argocd port-forward svc/argocd-server 8080:443

# Prompt for the Secret name, namespace, and .env path; write encrypted YAML.
generate-seal-secret:
	@bash ./scripts/generate-seal-secret.sh "$(CLUSTER)"
