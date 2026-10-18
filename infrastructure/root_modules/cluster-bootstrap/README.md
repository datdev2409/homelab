# cluster-bootstrap

Installs Argo CD with OpenTofu and the Helm provider after Ansible creates a
working Kubernetes cluster. OpenTofu owns this Helm release; Argo CD will own
GitOps child Applications and workloads. The `alekc/kubectl` provider applies
each bootstrap Application using `kubectl_manifest` after the Helm release is ready.

## Configuration

- Helm provider: pinned to **3.3.0**, the latest verified version on 2026-10-11.
- Kubectl provider: `alekc/kubectl` **2.4.1**, the latest stable version verified
  on 2026-10-11 (3.0 releases are currently prereleases).
- Cluster 001 chart: **10.10.2** (Argo CD **v3.5.4**), requiring Kubernetes >=1.25.
- `kubeconfig_path`: required absolute path to an ignored kubeconfig.
- `kubeconfig_context`: optional; otherwise use the current context in that file.
- `argocd_chart_version`: required exact chart version, selected per cluster.
- `argocd_namespace` and `argocd_release_name`: default `argocd`.
- `argocd_values`: nested Helm values overrides; defaults to `{}`.
- `values_files`: optional ordered absolute paths for additional Helm values.
- `helm_timeout_seconds`: default 600 seconds.
- `applications`: list of objects with `application_name`, `repo_url`, `ref`, and
  `path`. Optional `project` defaults to `default`; `prune` and `self_heal` both
  default to `true`. An empty list installs Argo CD without bootstrap Applications.

Reusable Helm defaults live in this module's `argocd/values.yaml`, loaded using
`path.module` so they also work inside Terragrunt's source cache. Cluster settings
and overrides live in `clusters/<id>/cluster.hcl`. Values are applied in this
order: module defaults, optional `values_files` in list order, then
`argocd_values`. Helm merges nested maps, preserving unspecified defaults;
later scalar and list values replace earlier ones. Any additional values-file
paths must be absolute.

For example, add the following inside `cluster_bootstrap` in `cluster.hcl` to
override only the server's memory request and enable notifications:

```hcl
argocd_values = {
  server = {
    resources = {
      requests = {
        memory = "192Mi"
      }
    }
  }
  notifications = {
    enabled = true
  }
}
```

Omit `argocd_values` to use the module defaults unchanged.

It uses the shared local backend at
`.local/states/<id>/cluster-bootstrap/terraform.tfstate` and receives no Proxmox
token input. Both providers use the same kubeconfig and optional context. Commit
both module and Terragrunt-unit provider lockfiles.

The module defaults use single replicas, standalone Redis, and ClusterIP access.
Dex and notifications are disabled. Component memory requests total 768 MiB,
excluding hook jobs; requests are scheduling reservations, not usage caps.
No persistent volumes are requested. Keep workloads and VM disks on SSD.

Helm waits for readiness and hook jobs. Atomic installation and upgrade behavior
rolls back failed operations; the timeout is configurable for slow image pulls.
The chart installs CRDs and retains them on uninstall. The namespace created by
Helm can also remain after uninstall. Destroy is therefore not a full cluster
wipe; removing CRDs later requires ensuring no dependent Applications remain.

## Bootstrap Applications

Configure any number of Applications in `cluster_bootstrap.applications` in
`clusters/<id>/cluster.hcl`. For example:

```hcl
applications = [
  {
    application_name = "root-001"
    repo_url         = "https://github.com/datdev2409/homelab.git"
    ref              = "main"
    path             = "apps/roots/001"
  },
  {
    application_name = "extra-bootstrap"
    repo_url         = "https://github.com/example/platform.git"
    ref              = "v1.0.0"
    path             = "clusters/001"
    prune            = false
    self_heal        = false
  }
]
```

`ref` maps to Argo CD's `targetRevision` and may be a branch, tag, or commit.
Keep OpenTofu-owned bootstrap Applications out of child Application manifests
and avoid having two Applications manage the same workloads. The `applications`
output reports names and namespaces, keyed by `application_name`.

Cluster 001 creates `root-001` in `argocd`, reading
`https://github.com/datdev2409/homelab.git`, revision `main`, path `apps/roots/001`.
OpenTofu owns this root Application; keep its manifest outside the GitOps root.
Argo CD detects the committed Kustomization and reconciles explicitly listed
child Applications. The first child is `cloudflared`; its connector needs
a separately supplied tunnel token Secret. See the
[Cloudflared guide](../../../apps/cloudflared/README.md) before pushing its
manifests and enabling reconciliation.

`kubectl_manifest.applications` uses `for_each`, keyed by `application_name`.
Names must be unique. Reordering the list preserves resource addresses; renaming
an application replaces its resource. Every instance depends on
`helm_release.argocd`. Schema
validation is disabled for this custom resource to accommodate installation of
its CRD in the same apply; provider apply retries cover short discovery delays.
The cluster API and kubeconfig must already exist before planning. Subsequent
refreshes still need the API and existing CRD; dependency ordering does not
repair a lost cluster. The user reported successful Argo CD bootstrap on cluster
001 on 2026-10-11; Git synchronization and teardown still require separate
verification.

Automatic sync uses each application's `prune` and `self_heal` settings;
empty-source pruning is protected by `allowEmpty: false`. No cascading-deletion
finalizer is attached to bootstrap Applications. Destroying them leaves their
child Applications and workloads, which must be
handled before uninstalling Argo CD. Child Applications select their own
cascading-deletion policy.

A private Git repository requires an Argo CD repository credential Secret or
secret Helm values configured separately. Your workstation's Git SSH key is not
automatically available to Argo CD. Keep credentials under `.local/credentials/`;
do not embed them in `repo_url`. Push the GitOps source before expecting sync.
Manifest creation does not prove Git access or successful synchronization.

## Workflow

First run Ansible, fetch the kubeconfig to `.local/config/<id>/kubeconfig.yaml`,
restrict it to mode 0600, and verify the expected cluster is reachable:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get nodes
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n kube-system get pods
make plan-cluster-bootstrap CLUSTER=001
make apply-cluster-bootstrap CLUSTER=001
```

Review the plan before accepting apply. A VM dependency alone cannot establish
that Kubernetes is ready. Full `make bootstrap` remains a guarded scaffold.
For initial provider setup, run from the unit directory:

```sh
cd infrastructure/clusters/001/cluster-bootstrap
direnv exec .. terragrunt init
```

## UI and verification

From the repository root, check pods and start a local HTTP port-forward:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get pods
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application root-001
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd describe application root-001
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd port-forward svc/argocd-server 8080:80
```

Open `http://localhost:8080`. The module defaults disable backend TLS because
Traefik terminates HTTPS; a direct port-forward uses HTTP. For HTTPS access,
use the [Argo CD Ingress](../../../apps/argocd-ingress/README.md).
The initial username is `admin`. Retrieve the generated password locally in a
separate terminal; do not commit or paste its output into logs:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

Do not put admin passwords or Git credentials in committed Helm values. If
secret values are supplied later, keep their files under `.local/credentials/`
and protect state and Helm release secrets; values can be stored in both.

## Teardown

Handle GitOps workloads first, then destroy this unit while the API is reachable:

```sh
cd infrastructure/clusters/001/cluster-bootstrap
direnv exec .. terragrunt destroy
```

The dependency deletes bootstrap Applications before uninstalling the Helm
release. It does not cascade into GitOps children. Review the destroy plan and
clean up child Applications/workloads first. Destroy VMs last. Retained CRDs and namespace disappear
when the disposable cluster is destroyed. The orchestration script is not yet
implemented.

## Sources

- [Kubectl manifest resource](https://registry.terraform.io/providers/alekc/kubectl/2.4.1/docs/resources/kubectl_manifest)
- [Helm provider](https://registry.terraform.io/providers/hashicorp/helm/3.3.0/docs)
- [Official Argo CD chart](https://github.com/argoproj/argo-helm/tree/argo-cd-10.10.2/charts/argo-cd)
- [Argo CD getting started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
