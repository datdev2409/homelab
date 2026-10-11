# cert-manager

Argo CD deploys cert-manager into the `cert-manager` namespace on cluster 001.
The child Application uses the official OCI Helm chart at
`quay.io/jetstack/charts`, pinned to **v1.21.2**. This release supports
Kubernetes 1.33–1.36, including cluster 001's Kubernetes 1.35.

Shared settings live in `values.yaml`; `override/001/values.yaml` is loaded
last. The root Kustomization explicitly includes
`apps/roots/001/cert-manager.yaml`. OpenTofu continues to own Argo CD and the
root Application; Argo CD owns cert-manager and its CRDs.

A third Git source deploys Kubernetes manifests from `extra/`, recursively.
Add ClusterIssuer manifests there; see the [extra resources guide](extra/README.md)
for sync ordering and credential references. The `ref: values` source remains
dedicated to Helm values.

CRDs are enabled in the chart. Server-side apply avoids the client-side apply
annotation size limit on large CRDs. The controller, webhook, and CA injector
each run one replica, requesting 125m CPU and 320 MiB memory in total. The
startup API check adds a temporary Job. These are initial homelab allocations;
measure usage as certificate volume grows. Prometheus integration is disabled
until monitoring is installed. No persistent volumes are required.

## Validation and deployment

Render the pinned chart and the root locally:

```sh
helm pull oci://quay.io/jetstack/charts/cert-manager --version v1.21.2 --destination /tmp
helm lint /tmp/cert-manager-v1.21.2.tgz -f apps/cert-manager/values.yaml -f apps/cert-manager/override/001/values.yaml
helm template cert-manager /tmp/cert-manager-v1.21.2.tgz --namespace cert-manager -f apps/cert-manager/values.yaml -f apps/cert-manager/override/001/values.yaml
kubectl kustomize apps/roots/001
```

Commit and push to `main` to enable root Application reconciliation. Check the
live deployment with:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application cert-manager
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cert-manager get deployments,pods
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get crd -l app.kubernetes.io/name=cert-manager
```

`extra/cluster-issuer.yaml` defines the `letsencrypt-prod` ClusterIssuer with
Cloudflare DNS-01. Supply the separate DNS API token Secret before requesting
workload certificates; see the [setup instructions](extra/README.md).
A Cloudflared tunnel token is not a Cloudflare DNS API token and cannot be used
for DNS-01 validation. Workload Certificates are configured separately.

## Teardown

The Application has a cascading-deletion finalizer. Review dependent
Certificates and Issuers before removing it: deleting CRDs deletes their
custom resources cluster-wide. `crds.keep` adds Helm's retention annotation;
do not rely on Helm uninstall behavior when Argo CD performs deletion.
Back up required certificate Secrets and issuer credentials separately.

## Sources

- [Official Helm installation](https://cert-manager.io/docs/installation/helm/)
- [Supported releases](https://cert-manager.io/docs/releases/)
- [Cloudflare DNS-01 configuration](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
