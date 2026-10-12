# ADR 0017: Manage encrypted GitOps credentials with Sealed Secrets

- **Status:** Accepted
- **Date:** 2026-10-12

## Decision

Install Sealed Secrets using its official Helm chart as an Argo CD child
Application on cluster 001. Follow the existing shared values and cluster
override layout. Use namespace `sealed-secrets` and controller name
`sealed-secrets-controller`. Start with one controller requesting 50m CPU and
64 MiB memory; no persistent volume is required.

Argo CD owns controller installation, RBAC, and the SealedSecret CRD. The
controller generates and owns sealing keys and reconciles encrypted
SealedSecrets into Kubernetes Secrets. Commit ciphertext with the consuming
application's cluster-specific manifests, using strict name-and-namespace
scope. Original credentials and key backups stay in protected storage outside
Git. OpenTofu and Ansible ownership remain as defined in ADR 0008.

This adds an optional GitOps credential workflow to ADR 0015's separately
supplied Cloudflared Secret. Existing credential Secrets are not migrated
automatically; adoption requires explicit ownership transfer and real encrypted
manifests generated using the target cluster's public certificate.

## Consequences

- Credentials can be reconciled from Git without storing plaintext in Git.
- Kubernetes Secrets remain readable by authorized cluster users; sealing
  protects the committed representation.
- Controller installation must precede deployment of dependent SealedSecrets.
- Disposable cluster recovery requires a protected backup of all sealing keys,
  or resealing original credentials for the replacement cluster.
- Key renewal and credential rotation are separate operations.
- Removing the CRD can delete SealedSecrets and their owned Secrets. Review
  dependent applications and back up keys before teardown.

See the [controller and credential guide](../../apps/sealed-secrets/README.md).

## References

- [Official Sealed Secrets project](https://github.com/bitnami/sealed-secrets)
- [ADR 0008: Argo CD bootstrap ownership](0008-argocd-bootstrap-with-opentofu-and-helm.md)
- [ADR 0015: Cloudflare Tunnel](0015-cloudflare-tunnel-for-workload-access.md)
