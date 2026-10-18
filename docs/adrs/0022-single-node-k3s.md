# ADR 0022: Single-node k3s for cluster 001

- **Status:** Accepted
- **Date:** 2026-10-18
- **Supersedes for cluster 001:** [ADR 0002](0002-kubernetes-distribution.md)
  and the three-node topology/allocation in [ADR 0003](0003-node-topology-and-resource-allocation.md)

## Decision

Use one Ubuntu 24.04 VM, `cp-01` at `192.168.1.101`, running a k3s server
and workloads. This follows the user's single-node plan and the existing
cluster inputs: 8 vCPU, 14336 MiB RAM, and a 100 GiB root disk. Keep the
three-running-VM ceiling for other experiments.

Ansible owns Linux preparation, a pinned checksum-verified k3s binary, its
configuration, and systemd service. Use bundled containerd, Flannel, CoreDNS,
metrics server, local-path storage, and default SQLite. Do not run the legacy
kubeadm/containerd tasks on this VM. Disable bundled Traefik and ServiceLB;
Argo CD retains ownership of Traefik per ADR 0016. OpenTofu continues to own
VM provisioning and Argo CD bootstrap; inventory ownership is unchanged.

## Consequences

All Kubernetes capacity shares one node with no failover. The server accepts
ordinary workloads without a control-plane scheduling taint. Multiple workload
replicas provide no node redundancy. SQLite and local-path volumes require
separate backups before replacing the VM.

The user's 14 GiB VM plus 512 MiB connector allocation supersedes the previous
13 GiB guest budget and leaves about 1.5 GiB nominally outside guests on the
16 GiB host. Verify actual Proxmox overhead and memory pressure before running
representative workloads. The 100 GiB disk also requires checking available
SSD capacity. This change does not provision or resize live resources.

Bootstrap requires a fresh VM or an installation already managed by this
playbook. Refuse implicit version changes; upgrades and kubeadm migration
require separate procedures. Preserve the legacy kubeadm playbook for reference.
Full provisioning/bootstrap/teardown orchestration remains guarded.

## References

- [k3s configuration](https://docs.k3s.io/installation/configuration)
- [Server options](https://docs.k3s.io/cli/server)
- [Cluster access](https://docs.k3s.io/cluster-access)
