# ADR 0004: Use ext4 and LVM-thin for initial host storage

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

[ADR 0001](0001-host-platform.md) selects Proxmox VE.
[ADR 0003](0003-node-topology-and-resource-allocation.md) retains three 16 GiB
VM root disks on the SSD and allocates 13 GiB of the laptop's 16 GB RAM to guests.
The remaining memory must support Proxmox, virtualization overhead, and host
activity.

The initial storage backend should be simple to operate and support compact,
disposable VM environments. ZFS is of interest as a future learning topic, but
its additional memory requirements are a poor fit for the current resource
budget.

## Decision

Use ext4 for the Proxmox host root filesystem and LVM-thin for VM disks on the
SSD. Use the conventional Proxmox storage names `local` for host directory
storage and `local-lvm` for the VM thin pool, matching the existing provisioning
configuration.

The host filesystem stores Proxmox files; LVM-thin supplies block volumes for
VM disks. This choice does not determine the filesystem inside each guest.

Keep the VM disk sizes and topology accepted in ADR 0003. Exact SSD volume sizes,
and host swap allocation remain separate installation decisions. HDD usage and
active application storage placement are recorded in
[ADR 0005](0005-hdd-usage-and-application-storage-placement.md).

## Reasons

- Ext4 is a familiar Linux filesystem with a straightforward operating model.
- LVM-thin supports thin-provisioned VM disks, snapshots, and clones without
  introducing ZFS pool management to the initial lab.
- Thin provisioning supports keeping additional experimental VMs on disk while
  only one three-VM environment runs at a time.
- The existing provisioning code targets `local-lvm` for VM disks and `local`
  for the downloaded Ubuntu cloud image.
- The initial focus remains Kubernetes operations within the current memory
  budget.

## Alternative considered: ZFS

ZFS combines filesystem and volume management, with checksums, compression,
snapshots, clones, and replication. Redundant configurations can repair corrupt
data using a valid copy and can tolerate certain disk failures.

ZFS also introduces additional memory budgeting and operational concepts such
as pools, datasets, cache sizing, and scrubs. It is not selected for the initial
host because the current guest allocations leave limited host memory headroom.
This is a suitability decision for this configuration, not a claim that ZFS
cannot run on a machine with 16 GB RAM.

## Consequences

- Host directory storage and the VM thin pool have separate capacity limits.
  Installation sizing must account for both.
- Thin disks allocate physical space as blocks are written. Their advertised
  sizes are not the same as their current physical consumption.
- Stopped VMs retain their allocated disk blocks. Monitor thin-pool data and
  metadata usage, including snapshot growth.
- Snapshots on the same SSD do not protect against losing that SSD. Backup and
  recovery remain separate decisions.
- No provisioning-code changes or disk formatting are required to record this
  decision; installation and storage configuration are future work.

## Future experiment: ZFS

Revisit ZFS when more host memory is available through a hardware upgrade,
reduced guest allocations, or a separate experimental environment. Size and
measure the memory budget before adopting it, and keep such experiments within
the three-running-VM limit from ADR 0003 when using this laptop.

Potential learning topics include checksums and scrubs, snapshots and clones,
compression, replication, and redundant pool layouts. A single SSD does not
provide disk-failure redundancy merely by using ZFS.

## References

- [Proxmox installation and LVM sizing](https://github.com/proxmox/pve-docs/blob/master/pve-installation.adoc)
- [Proxmox LVM-thin backend](https://github.com/proxmox/pve-docs/blob/master/pve-storage-lvmthin.adoc)
- [ZFS on Proxmox](https://github.com/proxmox/pve-docs/blob/master/local-zfs.adoc)
- [Proxmox hardware requirements](https://proxmox.com/en/products/proxmox-virtual-environment/requirements)
