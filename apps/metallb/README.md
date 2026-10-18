# MetalLB

Argo CD deploys official MetalLB chart **0.16.1** (MetalLB **v0.16.1**) into
`metallb-system`. Shared values disable both FRR backends for Layer 2 operation;
cluster 001 overrides live in `override/001/values.yaml`.
See [ADR 0023](../../docs/adrs/0023-metallb-lan-load-balancers.md).

The controller and speaker each request 100m CPU and 128 MiB memory, with a
256 MiB memory limit. K3s ServiceLB must remain disabled. MetalLB's speaker
uses host networking, so the namespace has privileged Pod Security labels.

## Address allocation

Cluster 001's `lan` IPAddressPool allocates **192.168.1.30–192.168.1.50**
(21 addresses). Keep this user-selected range reserved outside DHCP and other
static assignments. `override/001/extra/address-pool.yaml` defines the pool
and its L2Advertisement, deployed by the child Application's third source.
Both use sync wave 1 so the chart's controller and webhook start first.
LoadBalancer Services automatically receive an address from this pool.

Traefik's additional `traefik-nodeport-svc` Service uses type `LoadBalancer`
and selects the `lan` pool. It exposes its allocated LAN IP on ports 80/443
and retains NodePorts 30080/30443. Update local DNS to the allocated IP;
Cloudflare Tunnel continues to use the chart-owned ClusterIP Service.

## Validation and deployment

```sh
helm pull metallb --repo https://metallb.github.io/metallb --version 0.16.1 --destination /tmp
helm lint /tmp/metallb-0.16.1.tgz -f apps/metallb/values.yaml -f apps/metallb/override/001/values.yaml
helm template metallb /tmp/metallb-0.16.1.tgz --namespace metallb-system --include-crds -f apps/metallb/values.yaml -f apps/metallb/override/001/values.yaml
kubectl kustomize apps/roots/001
```

Commit and push to `main`, then let the root Application reconcile the child.
Verify the live installation:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application metallb
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n metallb-system rollout status deployment/metallb-controller
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n metallb-system rollout status daemonset/metallb-speaker
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n metallb-system get pods
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n metallb-system get ipaddresspools,l2advertisements
```

Deleting the child Application cascades to its resources and interrupts all
MetalLB LoadBalancer traffic. Review dependent Services before removal.

## Sources

- [Installation](https://metallb.io/installation/)
- [Address pools and Layer 2 advertisements](https://metallb.io/configuration/)
- [K3s compatibility](https://metallb.io/configuration/k3s/)
