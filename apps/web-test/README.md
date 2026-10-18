# Web ingress and certificate test

Cluster 001 serves `test.datnguyen.me` through Traefik. The `web-test`
Argo CD Application deploys a Deployment, ClusterIP Service, Ingress, and
explicit cert-manager Certificate into namespace `web-test`.

The backend is `traefik/whoami:v1.11.0`, a small HTTP diagnostic server. It runs
as a non-root user on port 8080 without a Kubernetes API token, with requests
of 10m CPU and 16 MiB memory. Shared manifests are in `base/`; the hostname,
Ingress, and Certificate live in `overlays/001/`.

The Certificate uses `letsencrypt-prod` and writes `web-test-tls` in the workload
namespace. The Ingress references this same Secret. It has no cert-manager
issuer annotation because the Certificate is managed explicitly.

Argo CD's default Ingress health check requires a LoadBalancer address, which
Traefik does not publish to Ingress status in this setup. The Ingresses exclude that check
from Application health using `argocd.argoproj.io/ignore-healthcheck`; Deployment
and Certificate health remain checked. Verify actual routing using the
requests below.

## Deployment and checks

```sh
kubectl kustomize apps/web-test/overlays/001
kubectl kustomize apps/roots/001
```

Commit and push to `main`, then verify:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application web-test
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n web-test get deployment,svc,ingress,certificate
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n web-test wait --for=condition=Ready certificate/web-test --timeout=180s
```

DNS-01 issuance requires the Cloudflare DNS API token Secret referenced by the
ClusterIssuer. No public HTTP challenge endpoint is required.

## Verify the origin certificate

Configure local DNS or a hosts-file entry mapping `test.datnguyen.me` to
Traefik's MetalLB IP `192.168.1.30`. After issuance, open
`https://test.datnguyen.me` or verify directly without a DNS override:

```sh
curl --resolve test.datnguyen.me:443:192.168.1.30 https://test.datnguyen.me/
```

Port-forward Traefik's HTTPS Service in a separate terminal:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n traefik port-forward svc/traefik 8443:443
curl --noproxy '*' --resolve test.datnguyen.me:8443:127.0.0.1 https://test.datnguyen.me:8443/
```

This verifies the certificate served by Traefik with hostname validation and
the backend response. Do not use `-k`; it would skip certificate verification.

## Public Cloudflare route

Cloudflare's published hostname must route `test.datnguyen.me` to
`http://traefik.traefik.svc.cluster.local:80`, preserving the Host header.
Alternatively, use `https://traefik.traefik.svc.cluster.local:443` with Origin
Server Name `test.datnguyen.me` for verified TLS to Traefik.

The TLS Ingress uses the `websecure` entrypoint. To support the HTTP tunnel
origin, the manifest also creates a plain HTTP Ingress on `web` for the same
hostname. Public HTTPS alone verifies Cloudflare's edge
certificate; the direct origin test above verifies cert-manager's certificate.

```sh
curl https://test.datnguyen.me/
```

## Teardown

Remove the child Application from the root to cascade-delete the test workload
and Certificate. Cert-manager certificate Secrets are not necessarily removed
when their Certificate is deleted; remove namespace `web-test` separately if
retiring the test entirely. Remove the Cloudflare hostname route separately.
