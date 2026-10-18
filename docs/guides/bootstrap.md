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
3. Run `make setup-k3s CLUSTER=001` to bootstrap the single k3s node and fetch
   its kubeconfig. This uses the generated inventory, shared SSH key, and pinned
   `ansible/group_vars/k3s.yml` settings. Verify the node, CoreDNS, and storage.
4. To refresh the kubeconfig later, run `ansible/playbooks/get-kubeconfig.yml`. The selected inventory directory
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

For another k3s cluster, select its `inventory/<id>/inventory.yml`; the same
playbook writes `.local/config/<id>/kubeconfig.yaml` automatically. You can also
pass `-e cluster_id=002` to explicitly set the destination ID. Always select the
matching inventory to fetch from the correct cluster. Cluster 002's planned
Talos provisioning and kubeconfig retrieval remain unimplemented.

## Single-node k3s bootstrap

After provisioning the Ubuntu VM, run from the repository root:

```sh
make setup-k3s CLUSTER=001
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get nodes
```

The inventory must contain exactly one `control_plane` host and no workers.
`cp-01` at `192.168.1.101` runs both the server and workloads. The standalone
`cloudflared` system container is excluded. The playbook requires Ubuntu 24.04
amd64, working SSH/Python and passwordless sudo; for a sudo password, run from
`ansible/` with `--ask-become-pass`:

```sh
ansible-playbook -i inventory/001/inventory.yml playbooks/site.yml --ask-become-pass
```

`site.yml` runs `k3s.yml`, then `get-kubeconfig.yml`. The server uses a
checksum-verified release binary, bundled containerd, Flannel, CoreDNS, metrics
server, local-path storage, and the default single-server SQLite datastore.
The release and CIDRs are pinned in `ansible/group_vars/k3s.yml`; check those
networks against your LAN/VPN routes before running. Traefik and ServiceLB are
disabled because Argo CD owns ingress and Cloudflare Tunnel supplies access.
Allow TCP 6443 from the workstation to the VM; the VM needs internet access for
APT, GitHub release downloads, and container images.

Cloud-init must finish before installation. Deprecation-only warnings (such as
the generated `user` string warning) are shown and accepted; other cloud-init
errors stop bootstrap.

Reruns preserve cluster data and only restart k3s when managed files change.
The playbook refuses kubeadm nodes, k3s agents, unmanaged k3s data directories,
and installed k3s versions that differ from the pin. Use a fresh VM for a move
from kubeadm; migration, reset, and upgrades are separate procedures. The old
three-node playbook is retained as `playbooks/kubeadm.yml`; its kubeconfig can
be fetched with `-e remote_kubeconfig=/etc/kubernetes/admin.conf`.

The fetched kubeconfig uses the inventory IP instead of loopback and is written
privately (directory 0700, file 0600). Refresh it after certificate renewal.
Local-path volumes and SQLite live on the VM disk; recreating the VM loses them
unless separately backed up. This topology has no node failover.

Syntax checks are supported without contacting guests. Ansible `--check` cannot
prove first-install readiness because the service and generated kubeconfig do
not yet exist. `make bootstrap` still stops at its lifecycle guard; use the
separate provisioning, k3s, and Argo CD targets in order.

## Login username and password

Run `make setup-users CLUSTER=001` to create or update the same Linux login
account on every host in the selected inventory, including system containers.
It prompts for a username (default `ubuntu`) and a hidden password with
confirmation. Existing accounts receive the new password; new accounts receive
a home directory and Bash shell. Each run sets the password using a fresh
SHA-512 salt, so reruns report a password change even for the same input.
Password tasks suppress logs and diffs.
Pass `ADD_TO_SUDO=true` to also add the account to the Ubuntu `sudo` group:

```sh
make setup-users CLUSTER=001 ADD_TO_SUDO=true
```

The default, `ADD_TO_SUDO=false`, leaves existing group memberships unchanged;
it does not revoke sudo access from an existing account. Other supplementary
groups are preserved when adding `sudo`. For direct playbook runs, use
`-e login_add_to_sudo=true` to enable this option.

Separate SSH/Python and privilege checks run first with visible errors, so
connection failures can be diagnosed without exposing the password.

Hosts need Python 3 and working SSH access through their existing inventory
users and key, with root or sudo privileges. Install `passlib` in the controller's
Ansible Python environment for password hashing. SSH password login follows the
host's existing sshd configuration; the `sudo` group uses the host's existing
sudoers policy. This playbook does not configure passwordless sudo.

To preview changes or target specific hosts, run from `ansible/`:

```sh
ansible-playbook -i inventory/001/inventory.yml playbooks/setup-users.yml --check
ansible-playbook -i inventory/001/inventory.yml playbooks/setup-users.yml --limit cloudflared
```

Add `--ask-become-pass` if the existing SSH account requires a sudo password.
Enter the new login password at the prompt; keep it out of command arguments,
inventory, and committed variable files. The inventory's connection username
continues to select the existing provisioning account.

For SSH troubleshooting, run from `ansible/`:

```sh
ansible all -i inventory/001/inventory.yml -m ansible.builtin.ping
```

Run from this directory so Ansible loads `ansible.cfg`, including the shared
private-key path. The new login credentials only take effect after a successful
playbook run; connection failures require working provisioning credentials first.

## Standalone cloudflared LXC

After provisioning and starting the Ubuntu LXC, run
`make setup-cloudflared CLUSTER=001` to install its standalone connector. This is
independent of k3s and the Kubernetes HTTP connector. The playbook uses the
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
replaced, assess node membership before rerunning bootstrap. Recovery and partial
replacement commands must be documented during implementation.
