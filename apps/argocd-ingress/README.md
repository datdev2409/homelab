# Argo CD HTTPS ingress

Traefik terminates TLS for `argocd.home.apra` using the `argocd-ingress-tls`
Secret in namespace `argocd`. This directory is included by `apps/roots/001`.
Cert-manager issues and renews the server certificate through the shared
`home-apra-ca` ClusterIssuer, managed in
[`../cert-manager/extra/`](../cert-manager/extra/README.md). The internal hostname
cannot use the public `letsencrypt-prod` issuer.

The hostname is intentionally `argocd.home.apra`, matching the requested name.
Configure local DNS or a hosts-file entry mapping it to Traefik's MetalLB IP.
Find the allocated address with:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n traefik get svc traefik-nodeport-svc
```

Open:

```text
https://argocd.home.apra
```

The route accepts HTTPS on Traefik's `websecure` entrypoint only; port 30080
does not serve this Ingress. Argo CD's backend uses Service port 80. Its
OpenTofu-owned Helm values set `configs.params.server.insecure: true` to avoid
redirecting backend HTTP requests to HTTPS. Traffic from the browser to Traefik
remains encrypted.

## Deployment and verification

Render before committing and pushing the GitOps resources:

```sh
kubectl kustomize apps/argocd-ingress
kubectl kustomize apps/roots/001
```

Review and apply the separate Argo CD Helm values change through its owner:

```sh
make plan-cluster-bootstrap CLUSTER=001
make apply-cluster-bootstrap CLUSTER=001
```

After Argo CD syncs the GitOps resources and cert-manager is running:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml wait --for=condition=Ready clusterissuer/home-apra-ca --timeout=120s
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd wait --for=condition=Ready certificate/argocd-ingress --timeout=120s
```

Export only the public CA certificate and import it into your device/browser's
trusted root certificate store:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cert-manager get secret home-apra-root-ca -o jsonpath='{.data.tls\.crt}' | base64 --decode > /tmp/home-apra-root-ca.crt
TRAEFIK_LB_IP=$(kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n traefik get svc traefik-nodeport-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl --cacert /tmp/home-apra-root-ca.crt --resolve "argocd.home.apra:443:${TRAEFIK_LB_IP}" https://argocd.home.apra/
```

Do not export or commit the CA private key. Back up the CA Secret securely;
recreating it creates a new trust root. The root lasts ten years, with renewal
starting a year before expiry. Plan CA renewal and redistribution of trust
before expiry; leaf certificates last 90 days and renew 30 days before expiry.
Cert-manager's CA issuer does not automatically reissue all leaf certificates
when its CA certificate changes.

See the [cert-manager CA documentation](https://cert-manager.io/docs/configuration/ca/)
for CA lifecycle behavior.
