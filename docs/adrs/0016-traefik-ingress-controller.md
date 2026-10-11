# ADR 0016: Traefik ingress controller

- **Status:** Accepted
- **Date:** 2026-10-11

## Decision

Deploy Traefik on cluster 001 through an Argo CD child Application using the
official Helm chart. Follow the shared values and cluster override layout in
ADR 0015. Argo CD owns the controller, its CRDs, and IngressClass `traefik`.
Workloads explicitly select `spec.ingressClassName: traefik`; the class is not
marked as the cluster default. Enable Kubernetes Ingress and Traefik CRD
providers; defer Gateway API installation.

Use a ClusterIP Service for HTTP and HTTPS. Cloudflare Tunnel remains the
external access mechanism from ADR 0015 and can route to Traefik's HTTP
Service while preserving the requested hostname. Direct routes to workload
Services remain supported. Configure published hostname routes in Cloudflare
separately. This amends ADR 0015's statement that ingress is unselected.

Run two replicas with preferred placement on separate workers and a disruption
budget retaining one available replica. Requests total 200m CPU and 256 MiB
memory. No host ports or persistent volumes are needed. Cert-manager owns
certificate issuance through separately configured Issuers; Traefik consumes
the resulting TLS Secrets. Disable the dashboard and built-in ACME issuance.

## Consequences

- Several hostnames can share a single tunnel origin Service.
- LAN clients need a port-forward or a separately selected service exposure
  mechanism to access Traefik directly.
- Application routes and issuer configuration are separate GitOps resources.
- Controller replicas share the physical Proxmox host's failure domain.

See the [Traefik guide](../../apps/traefik/README.md).

## References

- [Official Traefik Helm chart](https://github.com/traefik/traefik-helm-chart)
- [Kubernetes setup](https://doc.traefik.io/traefik/setup/kubernetes/)
