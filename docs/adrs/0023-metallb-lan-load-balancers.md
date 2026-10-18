# ADR 0023: MetalLB for LAN load balancers

- **Status:** Accepted
- **Date:** 2026-10-18
- **Amends:** [ADR 0016](0016-traefik-ingress-controller.md)

## Decision

Deploy MetalLB through an Argo CD child Application in `metallb-system` using
the official Helm chart, pinned to 0.16.1. Use Layer 2 mode on the existing
192.168.1.0/24 LAN. Disable both FRR backends; no BGP router configuration is
needed. K3s ServiceLB remains disabled per ADR 0022.

Use the existing shared Helm values and per-cluster override layout. Argo CD
owns MetalLB, its CRDs, and subsequent address pools and advertisements.
Install the controller and speaker independently of pool configuration; add
only addresses confirmed reserved outside DHCP and other static assignments.
Keep cluster-specific address pools under `apps/metallb/override/001/`.
Cluster 001 uses the user-selected inclusive range 192.168.1.30–192.168.1.50;
keep these addresses reserved outside DHCP and other static assignments.

MetalLB provides an optional LAN exposure mechanism for LoadBalancer Services,
including Traefik. Cloudflare Tunnel remains available. Installing MetalLB
does not change existing Service types or allocate addresses without a pool.

## Consequences

One controller and one speaker per node request 200m CPU and 256 MiB memory
on the current single-node cluster. Each has a 256 MiB memory limit. The
speaker uses host networking and elevated network capabilities; its namespace
uses the privileged Pod Security level required by the chart.

LAN clients can reach advertised LoadBalancer IPs without a NodePort suffix.
Local DNS must point to the chosen address. Layer 2 advertisements depend on
the Proxmox bridge and LAN permitting ARP traffic for the assigned addresses.
With one node, MetalLB cannot provide node failover.

## References

- [MetalLB installation](https://metallb.io/installation/)
- [Layer 2 configuration](https://metallb.io/configuration/)
- [K3s ServiceLB compatibility](https://metallb.io/configuration/k3s/)
