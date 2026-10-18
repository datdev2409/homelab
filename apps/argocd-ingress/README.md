# Argo CD HTTPS ingress

Traefik terminates TLS for **argocd.datnguyen.me** using Secret
`argocd-ingress-tls` in namespace `argocd`. This directory is included by
`apps/roots/001`. Cert-manager issues and renews the certificate through
ClusterIssuer `letsencrypt-prod`, using Cloudflare DNS-01. The public
certificate requires no private CA installation on clients.

Configure LAN DNS or a hosts-file entry mapping `argocd.datnguyen.me` to
Traefik's pinned MetalLB IP **192.168.1.30**, then open:

```text
https://argocd.datnguyen.me
```

DNS-01 requires working Cloudflare DNS credentials for `datnguyen.me`; it does
not require exposing Traefik to the internet. Public access through Cloudflare
Tunnel requires a separate published hostname route and Access policy.

The Ingress accepts HTTPS on Traefik's `websecure` entrypoint only. Argo CD's
backend uses Service port 80. Its OpenTofu-owned Helm values set
`configs.params.server.insecure: true` to avoid backend HTTPS redirects.

## Deployment and verification

Render before committing and pushing the GitOps resources:

```sh
kubectl kustomize apps/argocd-ingress
kubectl kustomize apps/roots/001
```

For a fresh installation, review and apply Argo CD Helm values through their
owner with `make plan-cluster-bootstrap CLUSTER=001` and
`make apply-cluster-bootstrap CLUSTER=001`.

After Argo CD syncs, check certificate issuance:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get clusterissuer letsencrypt-prod
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get certificate,certificaterequest,order,challenge
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd wait --for=condition=Ready certificate/argocd-ingress --timeout=120s
curl --resolve argocd.datnguyen.me:443:192.168.1.30 https://argocd.datnguyen.me/api/version
```

The previous `argocd.home.apra` route is replaced. Its private `home-apra-ca`
ClusterIssuer remains available for other internal workloads.
