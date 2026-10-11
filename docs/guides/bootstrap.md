# Bootstrap cluster 001

## Current status

The repository structure and configurable `base-env` module are implemented.
Argo CD bootstrap and full lifecycle automation remain pending. `make bootstrap
CLUSTER=001` deliberately exits with an explanation before changing resources.

## Prerequisites

- Prepared Proxmox host, SSD VM storage, and HDD directory storage from the ADRs.
- Reachable LAN, reserved VM addresses, and at most three running lab VMs.
- Pinned OpenTofu, Terragrunt, Ansible, Helm, and kubectl tool versions.
- Proxmox API credentials, SSH key, and reachable Git repository credentials
  where required, stored outside Git.
- Protected state location and backups independent of disposable VMs.

Configure direnv with global `.local/credentials/.env` and per-cluster
`.local/credentials/<id>/.env`, following [credential setup](credentials.md).
Make provisioning targets select the correct cluster environment automatically.

## Intended stages

1. Apply `infrastructure/clusters/001/base-env` for a fresh deployment.
2. Verify OpenTofu created `ansible/inventory/001/inventory.yml` during apply.
3. Run `ansible/playbooks/site.yml`, explicitly loading inventory, shared vars,
   cluster vars, and SSH credentials. Verify all expected nodes, CoreDNS, and CNI.
4. Run `ansible/playbooks/get-kubeconfig.yml` with `local_kube_dir` set to the
   absolute `.local/clusters/001` directory and `local_kubeconfig` set to its
   `kubeconfig` file. Restrict credentials and generated files to private access.
5. Verify API access; apply `infrastructure/clusters/001/cluster-bootstrap`.
6. Verify Argo CD readiness, Git repository access, and child synchronization.

Do not use a VM-only Terragrunt dependency as proof that Kubernetes exists.
Exact commands will be documented with the implemented modules and pinned tools.

## Existing cluster 001

The user migrated cluster 001 state to the new Terragrunt unit. The legacy
root-level OpenTofu configuration has been removed; its local artifacts are
archived under `.local/archives/`. State is now at `.local/states/001/base-env/terraform.tfstate`. Reinitialize
with `direnv exec .. terragrunt init -reconfigure` from the base-env unit after
the backend path relocation. Use the new unit and its existing state for
this cluster rather than starting a second state owner.

Review a plan before applying. The migrated state may retain legacy resource
addresses, including the old generated-inventory resource. Resolve any
unexpected deletion or replacement before apply. Active state was not modified
by repository cleanup.

For reruns, verify the same cluster ID and state are selected. If VMs are partly
replaced, assess node membership before rerunning kubeadm. Recovery and partial
replacement commands must be documented during implementation.
