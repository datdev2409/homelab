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

## Authentik sign-in

Cluster 001 configures direct OIDC through OpenTofu-owned Helm values in
`infrastructure/clusters/001/cluster.hcl`; Dex remains disabled. The issuer is
`https://auth.datnguyen.me/application/o/argocd/`, with scopes `openid`, `profile`,
and `email`, and the `groups` ID-token claim requested.

The existing Authentik application slug is `argocd`, with confidential provider
`Provider for argocd`. Keep its signing key and default OpenID, email, and profile
scope mappings. Register strict redirect URIs:

- `https://argocd.datnguyen.me/auth/callback`
- `http://localhost:8085/auth/callback` for CLI SSO

Membership in **ArgoCD Admins** grants `role:admin`; **ArgoCD Viewers** grants
`role:readonly`. Other users receive no default role. The initial `akadmin`
account belongs to ArgoCD Admins. Manage memberships in Authentik and log in
again after membership changes. Argo CD's local admin remains enabled for recovery.

The sealed manifest `authentik-client-secret-sealed.yaml` creates the separate
Secret `argocd-authentik`, labeled `app.kubernetes.io/part-of: argocd`, whose
`clientSecret` key is referenced by `$argocd-authentik:clientSecret` in the OIDC
configuration. Helm and OpenTofu receive only this reference. Private originals
are kept under `.local/credentials/001/argocd-authentik-provider.json` and
`.local/credentials/001/argocd-authentik.secret.json`. Rotate the provider secret
and reseal the consumer together. Never add the plaintext client secret to HCL.

The Authentik provider is stored in its PostgreSQL database, configured through
Authentik separately from the GitOps chart. Restore it from a database backup or
recreate it with these settings and the protected client credentials after a
rebuild. Both the browser and Argo CD server must resolve and trust the Authentik
HTTPS hostname.

Apply the sealed manifest through GitOps before applying the bootstrap Helm
configuration. Review `make plan-cluster-bootstrap CLUSTER=001`, then use
`make apply-cluster-bootstrap CLUSTER=001`. Open Argo CD and choose **Log in via
Authentik**. CLI access uses `argocd login argocd.datnguyen.me --sso --grpc-web`.
Verify a complete browser login and the resulting permissions before disabling
any recovery account.

References: [Argo CD OIDC configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/),
[Authentik OAuth2 provider](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/).
