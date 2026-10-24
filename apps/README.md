# GitOps applications

[Authentik](authentik/README.md) provides an identity provider on cluster 001
at `auth.datnguyen.me`, with PostgreSQL, persistent file storage, and sealed
credentials. DNS/tunnel routing and application SSO integrations are separate.

[Alloy](alloy/README.md) forwards cluster 001 metrics to Grafana Cloud through
the Kubernetes Monitoring chart. Its separate Cloud credential Secret is required
before the collector can start.

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

[MetalLB](metallb/README.md) provides LAN LoadBalancer support in Layer 2 mode.
Cluster 001 uses the reserved pool `192.168.1.30–192.168.1.50` outside DHCP.

[Sealed Secrets](sealed-secrets/README.md) installs the controller for encrypted
GitOps credentials. Generate SealedSecrets with the target cluster's public
certificate and keep private sealing-key backups outside Git.

[External Secrets Operator](external-secrets/README.md) installs the controller,
webhook, certificate controller, and CRDs for synchronizing Secrets from external
providers. Its AWS Systems Manager Parameter Store ClusterSecretStore uses OIDC in
`ap-southeast-1`; AWS trust setup and consumer resources are configured
separately. Existing Sealed Secrets consumers retain their current owner.
