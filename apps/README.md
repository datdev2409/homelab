# GitOps applications

The bootstrap root Application targets `apps/roots/001`. Its Kustomization
lists only child Application definitions. Each child targets its own manifests,
overlay, or Helm chart; do not recursively scan all of `apps/`.

Ingress and monitoring directories are layout examples. No controller or chart
has been selected, and the root currently includes no children. Argo CD
installation is managed by OpenTofu, not by this directory.
