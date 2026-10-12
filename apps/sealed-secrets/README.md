# Sealed Secrets

Argo CD installs official Helm chart **2.20.0**, with controller **0.40.0**,
into namespace `sealed-secrets` on cluster 001. Shared values load before
`override/001/values.yaml`. The root explicitly includes the child Application.
See [ADR 0017](../../docs/adrs/0017-sealed-secrets.md).

One controller requests 50m CPU and 64 MiB memory, with a 128 MiB memory limit.
Measure usage as secrets grow. Default health probes and container security
settings remain enabled. The Service is ClusterIP, with no ingress or persistent
volume. Cluster-wide RBAC lets the controller reconcile workload namespaces.
The broad proxy RoleBinding is disabled; administrators can use the Kubernetes
API proxy. Other users need explicit `services/proxy` access.

Argo CD owns the controller, RBAC, and SealedSecret CRD. The controller owns
generated sealing-key Secrets and the Secrets produced from SealedSecrets.
Store encrypted manifests with their consuming application's cluster-specific
resources, rather than in this controller's Helm values.

## Validation and deployment

Render locally without contacting the cluster:

```sh
helm pull sealed-secrets --repo https://bitnami.github.io/sealed-secrets --version 2.20.0 --destination /tmp
helm lint /tmp/sealed-secrets-2.20.0.tgz -f apps/sealed-secrets/values.yaml -f apps/sealed-secrets/override/001/values.yaml
helm template sealed-secrets /tmp/sealed-secrets-2.20.0.tgz --namespace sealed-secrets --include-crds -f apps/sealed-secrets/values.yaml -f apps/sealed-secrets/override/001/values.yaml
kubectl kustomize apps/roots/001
```

Commit and push to `main` to enable reconciliation. Server-side apply handles
the CRD. Wait for readiness before adding encrypted resources; child Application
listing order does not ensure their deployments are ready.

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application sealed-secrets
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n sealed-secrets rollout status deployment/sealed-secrets-controller
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get crd sealedsecrets.bitnami.com
```

## Seal credentials

Install `kubeseal` using the [upstream instructions](https://github.com/bitnami/sealed-secrets#kubeseal), preferably matching controller version 0.40.0.
Fetch the public certificate after controller readiness:

```sh
umask 077
mkdir -p .local/credentials/001
kubeseal --kubeconfig .local/config/001/kubeconfig.yaml --controller-name sealed-secrets-controller --controller-namespace sealed-secrets --fetch-cert > .local/credentials/001/sealed-secrets-cert.pem
```

For example, seal cert-manager's Cloudflare DNS API token from its private
token file. The pipeline writes only ciphertext to disk. Run in Bash or Zsh
with pipe failure checking enabled:

```sh
set -o pipefail
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cert-manager create secret generic cloudflare-api-token-secret --from-file=api-token=.local/credentials/001/cloudflare-dns-api-token --dry-run=client -o json |
  kubeseal --cert .local/credentials/001/sealed-secrets-cert.pem --scope strict --format yaml > .local/credentials/001/cloudflare-api-token-sealed.yaml
kubeseal --kubeconfig .local/config/001/kubeconfig.yaml --controller-name sealed-secrets-controller --controller-namespace sealed-secrets --validate < .local/credentials/001/cloudflare-api-token-sealed.yaml
```

After successful sealing and validation, create `apps/cert-manager/extra/001/`
and copy the encrypted output there as `cloudflare-api-token-sealed.yaml`.
The existing recursive Git source includes it. Keep namespace `cert-manager`,
name `cloudflare-api-token-secret`, and key `api-token`. Strict scope binds the
name and namespace; changing either requires resealing. Never commit plaintext
Secret manifests, token files, or private sealing keys.

For Cloudflared, use namespace `cloudflare`, name `cloudflared-tunnel-token`, and key
`token`. Its Application deploys the cluster 001 encrypted manifest from
`apps/cloudflared/extra/` through a separate Git source. The `ref: values`
source alone does not deploy manifests. Additional clusters need their own
manifest paths and ciphertext sealed with their controller certificates.

If a manually created Secret already exists, explicitly transfer ownership
before deploying the SealedSecret. For the DNS token, this live operation is:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cert-manager annotate secret cloudflare-api-token-secret sealedsecrets.bitnami.com/managed=true --overwrite
```

Check the SealedSecret's `Synced` condition after reconciliation without printing
Secret contents. Rotate credentials by resealing the new token and committing
the ciphertext. Restart workloads reading Secrets as environment variables,
including Cloudflared. Key renewal does not rotate those credentials.

## Key backup, rebuild, and teardown

Before rebuilding or deleting the namespace, back up all sealing-key Secrets.
This command reads private keys directly into an ignored file; never print it:

```sh
umask 077
mkdir -p .local/credentials/001
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n sealed-secrets get secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > .local/credentials/001/sealed-secrets-keys.secret.yaml
chmod 600 .local/credentials/001/sealed-secrets-keys.secret.yaml
```

Keep a protected backup outside the disposable cluster. Refresh it after key
renewal (the upstream default is every 30 days), retaining older keys for older
ciphertext. The public certificate alone cannot decrypt secrets.

Restore the backup into namespace `sealed-secrets` before starting the
controller and syncing dependent SealedSecrets. If the controller is already
running, restart it after restoring keys. Refresh the local public certificate
afterward. Without the original keys, reseal the original credentials using
the replacement cluster's certificate.

The Application has a cascading-deletion finalizer. Removing it can delete the
CRD and every SealedSecret; their owned Secrets can be garbage-collected too.
Back up keys and review dependent workloads before teardown. Runtime-generated
keys are not chart-rendered resources, but namespace deletion removes them.

## Sources

- [Official chart](https://github.com/bitnami/sealed-secrets/tree/main/helm/sealed-secrets)
- [Usage, ownership, scopes, and recovery](https://github.com/bitnami/sealed-secrets)
