# ADR 0009: Repository structure and cluster lifecycle

- **Status:** Accepted
- **Date:** 2026-10-11

## Context

The repository must support reusable provisioning and rebuilding the lab from
scratch, with secrets excluded from Git. [ADR 0008](0008-argocd-bootstrap-with-opentofu-and-helm.md)
selects OpenTofu and Helm for Argo CD bootstrap after Ansible creates Kubernetes.
Cluster `001` uses Ubuntu and kubeadm; `002` is reserved for a future Talos lab.

## Decision

Adopt Terragrunt with OpenTofu. Separate reusable root configurations, cluster
inputs, GitOps configuration, and generated local artifacts:

```text
.
├── README.md
├── .gitignore
├── Makefile
├── docs/
│   ├── adrs/
│   └── guides/
│       ├── bootstrap.md
│       └── teardown.md
├── apps/
│   ├── roots/
│   │   └── 001/
│   │       ├── kustomization.yaml
│   │       ├── ingress.yaml
│   │       └── monitoring.yaml
│   ├── ingress/
│   │   ├── base/
│   │   └── overlays/001/
│   └── monitoring/
│       ├── base/
│       └── overlays/001/
├── ansible/
│   ├── ansible.cfg
│   ├── playbooks/
│   ├── roles/
│   └── inventory/001/
├── infrastructure/
│   ├── root.hcl
│   ├── root_modules/
│   │   ├── base-env/
│   │   └── cluster-bootstrap/
│   └── clusters/
│       └── 001/
│           ├── cluster.hcl
│           ├── base-env/terragrunt.hcl
│           └── cluster-bootstrap/terragrunt.hcl
├── scripts/
│   ├── bootstrap.sh
│   └── teardown.sh
└── .local/
    ├── clusters/001/
    │   ├── inventory.yml
    │   └── kubeconfig
    └── states/clusters/001/
        ├── base-env/terraform.tfstate
        └── cluster-bootstrap/terraform.tfstate
```

Ingress and monitoring illustrate the layout; this ADR does not select those
components. Create future cluster directories when implemented.

### Infrastructure and Ansible

- `root_modules/base-env` provisions VMs and exposes inventory outputs.
  Parameterize VM IDs, addresses, resources, guest images, and storage settings.
- `root_modules/cluster-bootstrap` manages Argo CD and the initial GitOps
  Application configuration, retaining the ownership boundary in ADR 0008.
- `clusters/<id>/cluster.hcl` holds shared non-secret inputs. Stage-specific
  `terragrunt.hcl` files select reusable sources and inputs. `root.hcl` holds
  shared Terragrunt settings.
- Keep separate state per cluster and stage, such as `001/base-env` and
  `001/cluster-bootstrap`. State files mirror the unit directory path at
  `.local/states/<unit-path>/terraform.tfstate`, such as
  `.local/states/clusters/001/base-env/terraform.tfstate`.
- Generate inventory from VM outputs into `.local/clusters/<id>`. Reusable
  modules must not write to sibling repository paths from Terragrunt's cache.
- Store reusable Ansible roles and playbooks under `ansible/`. Commit non-secret
  cluster variables in `ansible/inventory/<id>`; explicitly load these alongside
  generated host inventory in the workflow.
- Talos will require a separate machine-configuration stage rather than the
  Ubuntu/kubeadm playbook. Reuse VM provisioning and Argo CD bootstrap where
  practical.

### GitOps

Replace the previously proposed `gitops/` location with root-level `apps/`.
The initial root Application targets `apps/roots/<id>` in a reachable Git
repository. Its `kustomization.yaml` explicitly lists child Applications.
Each child targets its own manifests, cluster overlay, or Helm chart.

Do not recursively discover all manifests under `apps/` through the root
Application. OpenTofu owns the root Application and Argo CD installation;
Argo CD owns child Applications and their workloads. Flannel remains
Ansible-owned initially. Avoid overlapping ownership between tools.

### Secrets and generated files

Exclude `.local/`, `.terraform/`, `.terragrunt-cache/`, state and backups,
saved plans, private keys, kubeconfigs, and plaintext secret variable files
from Git. Supply credentials through local files or environment variables.
Commit non-secret inputs, examples, Helm values, and provider lockfiles.

Git exclusions do not remove already tracked files or secure local state.
Protect and back up state, which may contain credentials. If using local
state, store it outside disposable Terragrunt cache directories. The final
backend remains an implementation decision.

## Bootstrap and teardown workflow

Provide root-level Makefile entry points backed by scripts accepting a
cluster ID. Enforce the following stages:

1. Check tools, credentials, host prerequisites, and the running-VM limit.
2. Apply the selected cluster's `base-env` unit.
3. Generate inventory from VM outputs.
4. Run guest configuration and Kubernetes bootstrap, including readiness checks.
5. Fetch kubeconfig and verify Kubernetes API access.
6. Apply `cluster-bootstrap` and wait for Argo CD readiness.
7. Verify Git repository access and GitOps synchronization.

A Terragrunt dependency on VMs alone does not establish that Ansible has
created Kubernetes. Orchestration must enforce that intervening stage before
invoking providers requiring the Kubernetes API.

For teardown, handle GitOps workloads while Argo CD is running, destroy
bootstrap while Kubernetes is reachable, then destroy VMs. Specify Application
finalizers and cascading deletion during implementation. Back up any data
that must survive separately.

Document prerequisites, credentials, commands, verification, reruns, and
recovery in `docs/guides/`. Proxmox host and HDD preparation remain prerequisites.

## Reasons

- Cluster inputs reuse provisioning code without copying it.
- Separate state matches the independently managed lifecycle stages.
- Explicit orchestration accounts for the Ansible stage between OpenTofu applies.
- GitOps definitions and workloads have clear ownership.
- Secrets and generated artifacts have predictable locations outside Git.

## Consequences and deferred work

- Pin and document Terragrunt and OpenTofu versions and engine selection.
- Preserve existing state during migration; moving code must not inadvertently
  recreate VMs. Review the migration plan before applying changes.
- Adapt current relative key, inventory, and kubeconfig paths to the new layout.
- Enforce the three-running-VM limit in
  [ADR 0003](0003-node-topology-and-resource-allocation.md) when switching labs.
- Backend, credentials, exact commands, versions, and applications remain
  implementation work.
- This ADR records architecture only; it does not reorganize files, migrate
  state, provision resources, or deploy applications.

## References

- [ADR 0008: Argo CD bootstrap](0008-argocd-bootstrap-with-opentofu-and-helm.md)
- [Terragrunt configuration blocks](https://docs.terragrunt.com/reference/hcl/blocks/)
- [Argo CD cluster bootstrapping](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
