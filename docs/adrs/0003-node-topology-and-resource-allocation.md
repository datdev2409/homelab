# ADR 0003: Retain the three-node topology and current VM allocations

- **Status:** Accepted
- **Date:** 2026-10-10

Cluster 001 is superseded by [ADR 0022](0022-single-node-k3s.md).

## Context

[ADR 0001](0001-host-platform.md) selects Proxmox VE as the persistent host.
[ADR 0002](0002-kubernetes-distribution.md) selects upstream Kubernetes
bootstrapped with kubeadm. The Dell has 16 GB RAM and a 125 GB SSD, alongside
a 1 TB HDD.

The existing provisioning code defines one control-plane VM and two worker VMs.
The lab will primarily run ephemeral workloads with little persistent data.
Compact VM disks also leave more SSD capacity for other, stopped experimental
VMs, such as a separate K3s cluster. Only three lab VMs will run at a time.

Proxmox documents a minimum of 2 GB RAM for its OS and services, in addition to
guest memory. Ceph and ZFS require additional memory. The initial resource budget
therefore targets a modest host footprint; the storage backend remains a
separate decision.

## Decision

Retain the existing three-node Kubernetes topology and VM resource allocations:

| VM | Role | vCPU | RAM | Root disk on SSD |
| --- | --- | --- | --- | --- |
| `cp-01` | Control plane | 3 | 5120 MiB (5 GiB) | 16 GiB |
| `worker-01` | Worker | 2 | 4096 MiB (4 GiB) | 16 GiB |
| `worker-02` | Worker | 2 | 4096 MiB (4 GiB) | 16 GiB |
| **Total** | | **7** | **13 GiB** | **48 GiB** |

The vCPUs share the physical processor; they are not dedicated physical cores.
The nominal RAM budget leaves approximately 3 GiB outside guest allocations.
That remainder must accommodate Proxmox, virtualization overhead, and host
activity; it is not a guaranteed amount of free memory.

Keep at most three lab VMs running at once, within the 13 GiB guest RAM budget.
Additional experimental VMs may remain provisioned but stopped. Stop the active
lab VMs before starting an alternate cluster, and ensure host boot behavior
respects this limit.

## Reasons

- Two workers support experiments with scheduling, node draining, and worker
  replacement while keeping a separate control plane.
- The current allocations preserve guest capacity while budgeting approximately
  3 GiB for the host and virtualization overhead.
- Keeping 16 GiB root disks limits this cluster's disk allocation to 48 GiB,
  preserving more SSD capacity for alternate environments.
- The expected workload profile favors disposable environments over large local
  datasets, making compact root disks a reasonable starting point.
- The existing provisioning code already matches these allocations.

## Alternatives considered

### Reduce control-plane resources and enlarge root disks

The proposed alternative used 2 vCPU and 3 GiB RAM for the control plane,
4 GiB RAM per worker, and root disks of 20/25/25 GiB. This would leave more
host memory headroom and reduce guest disk pressure, but allocate 70 GiB of SSD
capacity to this cluster. Retaining the current configuration better matches the
goal of keeping multiple experimental environments on disk.

### Use fewer nodes or multiple control planes

One worker would consume fewer resources but limit worker maintenance and
placement experiments. Multiple control planes would support quorum experiments
but consume more resources and still share one physical failure domain.

## Consequences and validation

- Proxmox's documented minimum is a baseline, not a cap on actual host usage.
  Measure host and guest memory under representative workloads and during
  provisioning and backup activity; revisit allocations if pressure develops.
- The control plane's extra RAM supports cluster services. With kubeadm's default
  control-plane scheduling taint retained, it does not increase ordinary
  application capacity. Worker allocations also include the guest OS and
  Kubernetes services.
- A base Ubuntu installation of approximately 5 GB is a planning estimate, not
  a verified free-space measurement for the chosen image. Validate guest disk
  usage after bootstrap and representative workloads.
- Ephemeral workloads still use disk for container images, writable layers,
  logs, and temporary volumes. Monitor free space, inodes, and Kubernetes disk
  pressure, and revisit disk sizes if cleanup cannot maintain adequate capacity.
- Six 16 GiB root disks would allocate 96 GiB before host partitions, downloaded
  images, cloud-init disks, snapshots, and other overhead. A second three-VM
  environment is a capacity goal, not a guarantee; confirm the actual datastore
  budget in the storage decision.
- The current provisioning code starts every defined VM and enables host-boot
  startup. Before adding an alternate VM set, lifecycle configuration must be
  adapted to enforce the three-running-VM limit. This ADR does not implement
  that workflow.
- The single control plane and shared laptop remain availability limitations.
  Persistent application data recovery requires a separate strategy.

## Deferred decisions

- SSD/HDD partitioning, storage backend, and usable datastore capacity.
- Guest OS/image selection and image pinning.
- Alternate environment lifecycle and startup automation.
- Persistent storage, backup, and recovery.

## References

- [Current VM provisioning configuration](../../infrastructure/vms.tf)
- [Proxmox VE hardware requirements](https://proxmox.com/en/products/proxmox-virtual-environment/requirements)
- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Kubernetes local ephemeral storage](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage)
