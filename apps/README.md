# GitOps applications

The bootstrap root Application targets `apps/roots/001`. Its Kustomization
lists only child Application definitions. Each child targets its own manifests,
overlay, or Helm chart; do not recursively scan all of `apps/`.

Ingress and monitoring directories are layout examples. No controller or chart
has been selected. Cluster 001's first child is
[Cloudflared](cloudflared/README.md), the connector for a remotely managed
Cloudflare Tunnel. Its token is supplied through a separate Kubernetes Secret.
Argo CD installation is managed by OpenTofu, not by this directory.

[cert-manager](cert-manager/README.md) installs the certificate controller,
webhook, CA injector, and CRDs on cluster 001. Issuers and workload Certificates
are configured separately.
