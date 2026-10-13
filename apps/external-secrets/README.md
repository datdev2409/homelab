# External Secrets Operator

Argo CD installs official Helm chart **2.12.0**, with operator **v2.12.0**,
into namespace `external-secrets` on cluster 001. Shared values load before
`override/001/values.yaml`. The root explicitly includes the child Application.
See [ADR 0018](../../docs/adrs/0018-external-secrets-operator.md).

The operator, validating webhook, and certificate controller each run one
replica. Together they request 100m CPU and 256 MiB memory, with combined memory
limits of 512 MiB. These are starting budgets; measure usage as secrets grow.
The chart's security and probe defaults remain in effect. No ingress or
persistent volume is required, and ServiceMonitor creation is disabled.
The chart's certificate controller manages webhook TLS; it does not use the
separate cert-manager installation.

Argo CD owns the deployments, RBAC, and ESO CRDs through the Helm chart.
Server-side apply handles the large CRDs. ESO owns Secrets generated from
ExternalSecrets. The separate Git source deploys an AWS Secrets Manager
ClusterSecretStore and dedicated OIDC service account from `extra/`.
It also deploys ExternalSecret `homelab-secrets`, which extracts the configured
AWS secret into Secret `external-secrets/homelab-secrets`.
See the [store, consumer, and AWS trust setup](extra/README.md).
Keep plaintext credentials outside Git.

Existing Sealed Secrets resources retain their current owner. Do not let ESO
and Sealed Secrets reconcile the same target Secret. Put namespaced
SecretStore and ExternalSecret manifests with their consuming application's
cluster resources and explicitly include them in that application's sources.
Prefer namespaced SecretStores; use a ClusterSecretStore only when shared
access is intended. Wait for ESO readiness before syncing consumers; root
Kustomization listing order does not guarantee deployment readiness.

## Validation and deployment

Render locally without contacting the cluster:

```sh
helm pull external-secrets --repo https://charts.external-secrets.io --version 2.12.0 --destination /tmp
helm lint /tmp/external-secrets-2.12.0.tgz -f apps/external-secrets/values.yaml -f apps/external-secrets/override/001/values.yaml
helm template external-secrets /tmp/external-secrets-2.12.0.tgz --namespace external-secrets --include-crds -f apps/external-secrets/values.yaml -f apps/external-secrets/override/001/values.yaml
kubectl kustomize apps/roots/001
```

After committing and pushing to `main`, the root Application can reconcile ESO.
Check installation readiness without printing Secret contents:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application external-secrets
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n external-secrets rollout status deployment/external-secrets
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n external-secrets rollout status deployment/external-secrets-webhook
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n external-secrets rollout status deployment/external-secrets-cert-controller
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get crd externalsecrets.external-secrets.io secretstores.external-secrets.io clustersecretstores.external-secrets.io
```

The Application has a cascading-deletion finalizer. Removing it can delete
ESO CRDs and their custom resources; generated Secrets with owner references
can also be garbage-collected. Review consumers before teardown. Rebuilding
requires restoring provider authentication and reconciling stores and consumers
after ESO is ready.

## Sources

- [Official installation guide](https://external-secrets.io/latest/introduction/getting-started/)
- [Pinned chart defaults](https://github.com/external-secrets/external-secrets/blob/helm-chart-2.12.0/deploy/charts/external-secrets/values.yaml)
