CLUSTER ?= 001
ADD_TO_SUDO ?= false
export TG_TF_PATH ?= tofu

.PHONY: bootstrap teardown fmt-terragrunt plan-base-env apply-base-env plan-cluster-bootstrap apply-cluster-bootstrap plan-cloudflare apply-cloudflare port-forward-argocd generate-seal-secret setup-cloudflared setup-users setup-k3s
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

# Seal a Secret manifest beside its input; prompt for omitted file paths.
generate-seal-secret:
	@bash ./scripts/generate-seal-secret.sh "$(SECRET_FILE)" "$(CERT_FILE)"

# Standalone Ubuntu LXC connector; use the selected cluster's private token.
setup-cloudflared:
	@test -f "ansible/inventory/$(CLUSTER)/inventory.yml" || { echo "Apply base-env first to generate ansible/inventory/$(CLUSTER)/inventory.yml" >&2; exit 1; }
	@cd ansible && direnv exec "../infrastructure/clusters/$(CLUSTER)" sh -c ': "$${CLOUDFLARED_TUNNEL_TOKEN:?Set CLOUDFLARED_TUNNEL_TOKEN in the selected cluster private environment}"; exec ansible-playbook -i "inventory/$$1/inventory.yml" playbooks/cloudflared.yml' sh "$(CLUSTER)"

# Prompt for a shared login; optionally add it to sudo with ADD_TO_SUDO=true.
setup-users:
	@test -f "ansible/inventory/$(CLUSTER)/inventory.yml" || { echo "Apply base-env first to generate ansible/inventory/$(CLUSTER)/inventory.yml" >&2; exit 1; }
	@cd ansible && ansible-playbook -i "inventory/$(CLUSTER)/inventory.yml" playbooks/setup-users.yml -e 'login_add_to_sudo=$(ADD_TO_SUDO)'

# Bootstrap only Kubernetes on the provisioned VM, then fetch its kubeconfig.
setup-k3s:
	@test -f "ansible/inventory/$(CLUSTER)/inventory.yml" || { echo "Apply base-env first to generate ansible/inventory/$(CLUSTER)/inventory.yml" >&2; exit 1; }
	@cd ansible && ansible-playbook -i "inventory/$(CLUSTER)/inventory.yml" playbooks/site.yml
