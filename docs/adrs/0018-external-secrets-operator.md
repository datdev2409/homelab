# ADR 0018: Install External Secrets Operator through Argo CD and Helm

- **Status:** Accepted
- **Date:** 2026-10-13

## Decision

Install External Secrets Operator (ESO) on cluster 001 using its official Helm
chart as an Argo CD child Application. Pin the chart version and follow the
shared values and cluster override layout. Use namespace `external-secrets`,
enable chart-managed CRDs, and use Argo CD server-side apply for the large CRDs.

Run one replica each of the operator, validating webhook, and certificate
controller. Initial combined requests are 100m CPU and 256 MiB memory, with
512 MiB combined memory limits. No persistent storage is required. Argo CD
owns the installation and CRDs; ESO owns Secrets generated from ExternalSecrets.
OpenTofu and Ansible ownership remain as defined in ADR 0008.

Use AWS Systems Manager Parameter Store in `ap-southeast-1` through
ClusterSecretStore `aws-parameterstore`. Authenticate through OIDC using a dedicated service
account `external-secrets/aws-secretsmanager` annotated with role
`arn:aws:iam::803537989070:role/homelab-secrets-reader`. The cluster's service
account issuer must be registered as an AWS IAM OIDC provider, and the role
must trust this service account's subject and the `sts.amazonaws.com` audience.
Issuer publication and AWS IAM configuration are prerequisites outside this
Application; their readiness has not been verified.

The shared store is available to consumers across namespaces. Its IAM policy
must scope access to intended parameters. Keep ExternalSecrets with their
consuming application's cluster-specific manifests. The Cloudflared consumer
reads SSM parameter `/homelab/cloudflared-tunnel-token` into its Kubernetes
Secret.
Store plaintext credentials outside Git.

This complements [ADR 0017](0017-sealed-secrets.md). Existing Sealed Secrets
consumers are not migrated. Each target Secret must have only one controller
owner; Sealed Secrets may supply separate provider authentication Secrets.

## Consequences

- Applications can synchronize Secrets from an external backend once provider
  authentication and store resources are configured.
- ESO and its webhook must be ready before dependent custom resources sync.
- Secret reconciliation depends on backend availability and authorization.
- Kubernetes Secrets remain readable by authorized cluster users.
- Removing CRDs can delete their custom resources and owned Secrets. Review
  consumers before teardown and restore provider access during rebuilds.
- Resource budgets should be measured and revisited as secret usage grows.

See the [installation guide](../../apps/external-secrets/README.md).

## References

- [Official ESO installation](https://external-secrets.io/latest/introduction/getting-started/)
- [ADR 0008: Argo CD bootstrap ownership](0008-argocd-bootstrap-with-opentofu-and-helm.md)
