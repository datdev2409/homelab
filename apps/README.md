# GitOps applications

The bootstrap root Application targets `apps/roots/001`. Its Kustomization
lists only child Application definitions. Each child targets its own manifests,
overlay, or Helm chart; do not recursively scan all of `apps/`.

Cluster 001's first child is
[Cloudflared](cloudflared/README.md), the connector for a remotely managed
Cloudflare Tunnel. Its encrypted token is reconciled through Sealed Secrets.
Argo CD installation is managed by OpenTofu, not by this directory.

[cert-manager](cert-manager/README.md) installs the certificate controller,
webhook, CA injector, and CRDs on cluster 001. Issuers and workload Certificates
are configured separately.

[Traefik](traefik/README.md) provides ingress through a ClusterIP Service that
Cloudflare Tunnel can use as an origin. Workload Ingress resources explicitly
select class `traefik`.

[Sealed Secrets](sealed-secrets/README.md) installs the controller for encrypted
GitOps credentials. Generate SealedSecrets with the target cluster's public
certificate and keep private sealing-key backups outside Git.
