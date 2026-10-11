# ADR 0008: Bootstrap Argo CD with OpenTofu and the Helm provider

- **Status:** Accepted
- **Date:** 2026-10-11

## Context

The homelab uses OpenTofu to provision Proxmox VMs and Ansible to configure
Ubuntu, containerd, and the kubeadm cluster. Application configuration will
live under `gitops/` and be reconciled by Argo CD.

Argo CD must be installed and connected to Git after Kubernetes becomes
available. The user prefers managing this bootstrap declaratively through
OpenTofu and the Helm provider.

## Decision

Use a separate OpenTofu root configuration for cluster bootstrap, with its
own state, apart from the existing VM provisioning configuration. The Helm
provider manages the Argo CD Helm release, including installation,
configuration, and upgrades. Pin provider and chart versions and commit
non-secret Helm values and provider lockfiles.

Use the following responsibility boundary:

| Tool | Ownership |
| --- | --- |
| OpenTofu VM configuration | Proxmox VMs, disks, networking, cloud-init, and generated Ansible inventory |
| Ansible | Guest OS configuration, containerd, kubeadm, and the existing Flannel installation |
| OpenTofu bootstrap configuration | Argo CD Helm release and the initial declarative connection to Git |
| Argo CD | Platform add-ons and application workloads under `gitops/` |

Argo CD does not manage its own installation initially. Avoid overlapping
ownership of its installation, bootstrap objects, or Flannel between tools.

## Lifecycle

1. Apply the VM provisioning configuration.
2. Run Ansible and complete its Kubernetes readiness checks.
3. Fetch the cluster kubeconfig using the existing Ansible playbook.
4. Apply the bootstrap configuration against the reachable Kubernetes API.
5. Install Argo CD, wait for readiness, and establish Git repository access
   and the initial Application configuration.
6. Allow Argo CD to reconcile the platform and workloads from Git.

For a clean teardown, handle GitOps-managed workloads while Argo CD is still
running, then destroy the bootstrap configuration before destroying the VMs.
The bootstrap provider requires the Kubernetes API to remain reachable.
Deleting an Application does not necessarily delete its workloads; finalizer
and cascading-deletion behavior must be specified in the implementation.

## Reasons

- Keeps Argo CD installation represented as declarative OpenTofu resources
  with a reviewable plan and state tracking.
- Helm values provide a structured way to configure the installation.
- Separates VM provisioning from resources that require an already running
  Kubernetes API, matching the intervening Ansible stage.
- Gives Argo CD a recovery path through OpenTofu without depending on Argo CD
  to restore its own installation.

## Alternatives considered

- **Ansible with Helm:** Fits the existing cluster setup workflow, but the
  user prefers OpenTofu ownership of Argo CD bootstrap.
- **Ansible with manifests or Kustomize:** Offers declarative Kubernetes
  configuration, but does not provide the selected OpenTofu release lifecycle.

## Consequences and deferred work

- Rebuilding requires ordered stages; a single VM-level apply cannot also
  configure Kubernetes before Ansible creates it.
- Bootstrap state requires backup and protection. Credentials or secrets
  supplied to providers and resources may be retained in state; marking a
  variable sensitive does not remove it from state.
- Keep kubeconfig and plaintext credentials outside committed files.
- Specify the bootstrap directory, state backend, chart/provider versions,
  resource requests, and UI access in implementation work.
- Specify Git repository URL, revision, path, and private-repository access
  before enabling reconciliation. Argo CD reads a reachable Git repository,
  rather than watching the local workspace folder.
- Choose the initial Application pattern separately. A root Application
  managing child Applications is a possible approach.
- Choose how OpenTofu creates bootstrap Application resources after the
  Argo CD CRDs exist. Account for CRD availability during planning if using
  a Kubernetes manifest provider; a separate Helm release containing the
  bootstrap objects is another option.
- This ADR records architecture only; it does not install Argo CD or change
  the running cluster.

## Implementation notes

The reusable `infrastructure/root_modules/cluster-bootstrap` now installs Argo CD
using Helm provider 3.3.0. Cluster 001 pins chart 10.10.2 and passes its ignored
kubeconfig explicitly. Helm waits for readiness and hook jobs, with atomic
rollback on failure. The module's `argocd/values.yaml` defaults to non-HA operation and
ClusterIP UI access through port-forwarding; CRDs are retained on uninstall.
Clusters can override individual nested values through the `argocd_values`
input. Helm layers module defaults, optional values files, then input overrides.

Repository layout and the `apps/roots/<id>` GitOps entry point follow ADR 0009.
Use `kubectl_manifest` from `alekc/kubectl` 2.4.1 to apply bootstrap Applications
from encoded YAML. Configure an `applications` list containing `application_name`,
`repo_url`, `ref`, and `path`, with optional `project`, `prune`, and `self_heal`.
Names must be unique; resources use `for_each` keyed by name so list reordering
preserves their identities. Empty lists install Argo CD alone. Both providers
use the same explicit kubeconfig and optional context. Every manifest depends
on the ready Helm release, disables schema
validation for the new CRD, and uses provider apply retries for discovery delays.
The user reported successful Argo CD bootstrap on cluster 001 on 2026-10-11;
Git synchronization and teardown still require separate verification.

Cluster 001 tracks `main` at `apps/roots/001` with automated prune and self-heal,
protecting against empty-source pruning. OpenTofu owns the root Application;
Argo CD owns explicitly listed children. The root has no cascading-deletion
finalizer, so teardown must clean up children/workloads separately before Helm
uninstall. Git credentials for private repositories remain separate local
configuration. Operational instructions are in the [module guide](../../infrastructure/root_modules/cluster-bootstrap/README.md).

## References

- [Argo CD Helm installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#helm)
- [Argo CD declarative setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Helm provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [ADR 0002: Kubernetes distribution](0002-kubernetes-distribution.md)
- [ADR 0007: Kubernetes VM operating system](0007-kubernetes-vm-operating-system.md)
