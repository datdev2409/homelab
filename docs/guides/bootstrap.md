# Bootstrap cluster 001

## Current status

The repository structure and configurable `base-env` module are implemented.
Argo CD Helm installation and the kubectl-managed root Application are implemented;
full lifecycle automation remains pending. `make bootstrap
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
4. Run `ansible/playbooks/get-kubeconfig.yml`. The selected inventory directory
   determines the cluster ID and repository root; the default destination is
   `.local/config/<cluster-id>/kubeconfig.yaml`. The playbook sets directory mode
   0700 and file mode 0600.
5. Verify API access; apply `infrastructure/clusters/001/cluster-bootstrap`.
6. Verify Argo CD readiness, Git repository access, and child synchronization.

Do not use a VM-only Terragrunt dependency as proof that Kubernetes exists.
For the implemented Argo CD installation, verify the kubeconfig and cluster
readiness, then run `make plan-cluster-bootstrap CLUSTER=001` and
`make apply-cluster-bootstrap CLUSTER=001`. See the
[bootstrap module guide](../../infrastructure/root_modules/cluster-bootstrap/README.md)
for pinned versions, configuration, UI access, and teardown. Inspect `root-001`
sync status and conditions after apply. Push the GitOps source and configure
private Git credentials separately if needed. The first child is Cloudflared;
prepare its tunnel token Secret before enabling it. See the
[Cloudflared guide](../../apps/cloudflared/README.md).

From `ansible/`, retrieve the kubeconfig for cluster 001 with:

```sh
ansible-playbook -i inventory/001/inventory.yml playbooks/get-kubeconfig.yml
```

For another kubeadm cluster, select its `inventory/<id>/inventory.yml`; the same
playbook writes `.local/config/<id>/kubeconfig.yaml` automatically. You can also
pass `-e cluster_id=002` to explicitly set the destination ID. Always select the
matching inventory to fetch from the correct cluster. Cluster 002's planned
Talos provisioning and kubeconfig retrieval remain unimplemented.

## Standalone cloudflared LXC

After provisioning and starting the Ubuntu LXC, run
`make setup-cloudflared CLUSTER=001` to install its standalone connector. This is
independent of kubeadm and the Kubernetes HTTP connector. The playbook uses the
generated inventory and the private `CLOUDFLARED_TUNNEL_TOKEN` environment value.
See the [standalone connector guide](cloudflared-lxc.md) for prerequisites,
rotation, version pinning, and verification.

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
