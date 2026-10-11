# Traefik

Cluster 001 deploys Traefik **v3.7.14** using official Helm chart **41.7.1**.
`apps/roots/001/traefik.yaml` loads shared `values.yaml`, followed by
`override/001/values.yaml`. Argo CD owns the controller, chart CRDs, Service,
and IngressClass. Architecture is recorded in [ADR 0016](../../docs/adrs/0016-traefik-ingress-controller.md).

Two replicas prefer separate worker nodes, with a disruption budget retaining
one ready pod. Total requests are 200m CPU and 256 MiB memory. Each pod has a
256 MiB memory limit. Monitoring and the dashboard are disabled. The chart's
security settings and health probes remain enabled. No persistent storage is
requested. The Gateway API provider is disabled; use Kubernetes Ingress or
Traefik IngressRoute resources.

## Access and routing

The `traefik` Service in namespace `traefik` is ClusterIP and exposes ports
80 and 443. Configure Cloudflare published hostname routes to use:

```text
http://traefik.traefik.svc.cluster.local:80
```

Preserve the public Host header so Traefik can match the hostname in the
Ingress. If an HTTP Host Header override is configured in Cloudflare, it must
match the intended Ingress hostname. Configure Cloudflare Access for private
applications. Tunnel hostname routes are managed separately from this chart.
Ingress status may have no external address with this ClusterIP setup.

Create workload Ingress resources alongside their applications, for example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: apps
spec:
  ingressClassName: traefik
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example
            port:
              number: 8080
```

The backend Service must exist in the Ingress namespace. For IngressRoute
resources, use annotation `kubernetes.io/ingress.class: traefik`. Cross-namespace
CRD references are disabled. For TLS at Traefik, configure a cert-manager
Issuer and reference its certificate Secret in the Ingress `spec.tls` section.
No built-in Traefik ACME resolver is configured. Do not globally redirect HTTP
to HTTPS when the tunnel uses this HTTP origin; edge redirects belong in
Cloudflare unless origin TLS is configured as well.

For temporary local access:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n traefik port-forward svc/traefik 8081:80 8443:443
curl -H 'Host: app.example.com' http://localhost:8081/
```

## Validation and deployment

```sh
helm pull traefik --repo https://traefik.github.io/charts --version 41.7.1 --destination /tmp
helm lint /tmp/traefik-41.7.1.tgz -f apps/traefik/values.yaml -f apps/traefik/override/001/values.yaml
helm template traefik /tmp/traefik-41.7.1.tgz --namespace traefik --include-crds -f apps/traefik/values.yaml -f apps/traefik/override/001/values.yaml
kubectl kustomize apps/roots/001
```

Commit and push to `main` to enable root Application reconciliation. Server-side
apply handles large CRDs. Verify rollout and synchronization:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application traefik
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n traefik rollout status deployment/traefik
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n traefik get pods -o wide
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get ingressclass traefik
```

The Application has a cascading-deletion finalizer. Removing it interrupts
ingress routing and can delete chart CRDs and their custom resources. Review
dependent routes before teardown.

## Sources

- [Official Helm chart](https://github.com/traefik/traefik-helm-chart)
- [Kubernetes Ingress provider](https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-ingress/)
