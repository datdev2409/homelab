# ADR 0015: Publish workloads through Cloudflare Tunnel

- **Status:** Accepted
- **Date:** 2026-10-11
- **Amended by:** [ADR 0019](0019-cloudflare-account-resources-with-opentofu.md),
  adding a separate account-level OpenTofu unit for Cloudflare resource adoption.

## Decision

Use a remotely managed Cloudflare Tunnel with a dedicated `cloudflared`
Deployment inside each cluster. Argo CD fetches the community-maintained
HelmForge `cloudflared` chart directly from its Helm repository.
The Application manifest lives in `apps/roots/<id>/cloudflared.yaml`, explicitly
listed in that root's Kustomization. Shared values and cluster overrides live
under `apps/cloudflared/`. A second
Git source supplies shared `values.yaml` followed by
`override/<id>/values.yaml` for cluster-specific overrides. The chart supports existing token Secrets,
so no chart copy or local template patches are maintained. Helm repository,
chart name, version, values revision, and destination namespace are configured
directly in one Application. No generator or config file is needed. Argo CD owns the
connector, ServiceAccount, and disruption budget. Configure Cloudflare tunnels, published
hostnames, DNS, and Access policies separately in the Cloudflare dashboard.
[ADR 0019](0019-cloudflare-account-resources-with-opentofu.md) provides a separate
account-level OpenTofu unit for adopting Cloudflare resources. Until imports and
adoption are complete, the existing resources remain managed separately.

Start with explicit hostname routes to Kubernetes ClusterIP Services. An
ingress controller is optional; [ADR 0016](0016-traefik-ingress-controller.md)
adds Traefik as an alternative tunnel origin. Use a separate tunnel
and token per cluster; do not attach independent clusters to the same tunnel.

Run two fixed replicas with preferred placement on separate worker nodes.
Pin image versions, use readiness checks, and retain one ready replica during
voluntary disruptions. The shared physical host remains a failure domain.

Supply the tunnel token through a separately managed Kubernetes Secret.
Keep local token files under `.local/credentials/<id>/`; commit only a Secret
reference. Before exposing private dashboards, configure Cloudflare Access.

## Consequences

- Home router port forwarding and a public origin IP are unnecessary.
- Tunnel availability depends on outbound connectivity and the target Service.
- Rebuilding requires recreating the token Secret before connector pods start.
- Removing the Application cascades to its connector resources. Cloudflare
  tunnel and DNS cleanup remain separate operations.
- Adding the child to Git does not prove the tunnel is connected or a hostname
  is reachable. Verify connector readiness and application access after sync.

See the [Cloudflared guide](../../apps/cloudflared/README.md) for setup.

## References

- [Cloudflare Kubernetes guide](https://developers.cloudflare.com/tunnel/guides/kubernetes/)
- [ADR 0009: Repository structure](0009-repository-structure-and-cluster-lifecycle.md)
