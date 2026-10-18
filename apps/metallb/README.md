# MetalLB

Argo CD deploys official MetalLB chart **0.16.1** (MetalLB **v0.16.1**) into
`metallb-system`. Shared values disable both FRR backends for Layer 2 operation;
cluster 001 overrides live in `override/001/values.yaml`.
See [ADR 0023](../../docs/adrs/0023-metallb-lan-load-balancers.md).

The controller and speaker each request 100m CPU and 128 MiB memory, with a
256 MiB memory limit. K3s ServiceLB must remain disabled. MetalLB's speaker
uses host networking, so the namespace has privileged Pod Security labels.

## Address allocation

No address pool is configured yet. Before adding an `IPAddressPool` and
`L2Advertisement`, reserve unused addresses on 192.168.1.0/24 outside DHCP and
all other static assignments. Put cluster-specific configuration under
`override/001/` and add it as a manifest source in the child Application.
An installation without a pool is idle and does not advertise LAN addresses.

Existing Traefik ClusterIP and NodePort Services remain unchanged. After a
pool is configured, change the chart-owned Traefik Service to `LoadBalancer`
through `apps/traefik/override/001/values.yaml` to use a LAN IP on ports 80/443.
Update local DNS to that IP; keep Cloudflare Tunnel's ClusterIP origin.

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
```

Deleting the child Application cascades to its resources and interrupts all
MetalLB LoadBalancer traffic. Review dependent Services before removal.

## Sources

- [Installation](https://metallb.io/installation/)
- [Address pools and Layer 2 advertisements](https://metallb.io/configuration/)
- [K3s compatibility](https://metallb.io/configuration/k3s/)
