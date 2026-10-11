# ADR 0005: Use the HDD for provisioning assets, backups, and archives

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

The Dell has a 125 GB SSD and a 1 TB HDD.
[ADR 0003](0003-node-topology-and-resource-allocation.md) places Kubernetes VM
root disks on the SSD, and
[ADR 0004](0004-host-filesystem-and-vm-storage-backend.md) selects ext4 and
LVM-thin for initial host storage.

SSD capacity should prioritize active VMs and application workloads. The HDD's
larger capacity is useful for files that are read mainly during provisioning or
recovery, and for inactive experimental material.

## Decision

Use the HDD to store:

- Installation ISO files.
- Ubuntu cloud images used as provisioning sources.
- Proxmox VM backup archives.
- Archived experimental data and exported environments.

Keep active application workloads on SSD-backed storage, including their
container images, writable layers, temporary files, and application data.
Application data storage capacity must be budgeted separately if it exceeds the
existing VM root disk allocations.

Keep Kubernetes VM root disks and etcd data on the SSD. The HDD will not be used
as active application storage or as the location of active VM disks in the
initial setup. Archived experimental data on the HDD must be restored or copied
to SSD-backed storage before active application use.

## Reasons

- Provisioning assets and archives can tolerate slower reads, preserving scarce
  SSD space for running environments.
- SSD-backed application storage avoids making the HDD's random-access
  performance part of normal workload operation.
- VM backup archives support recovery and restore experiments, while IaC remains
  the source for recreating disposable infrastructure.
- Less-used experimental environments can be backed up to the HDD and have
  their SSD disks removed when space is needed, after verifying recovery.

## Consequences

- Installation or cloud-image import may take longer when reading from the HDD.
  Once provisioned, VMs run from their SSD-backed disks; their provisioning
  source's location does not affect normal VM disk operation.
- Stopping a VM does not free its SSD disk allocation. Archiving and removing
  its disks is a separate lifecycle action, with recovery verified beforehand.
- The current provisioning code downloads Ubuntu cloud images to `local`.
  Implementing this decision requires configuring HDD file storage and updating
  the download target, while keeping VM disks on `local-lvm`.
- Archived VM backups may contain application data. This is consistent with the
  SSD-only policy for active application storage.
- HDD backups remain in the same laptop. They can help recover from an SSD
  failure but do not protect against loss of the whole machine. Important data
  needs a recovery copy outside the laptop.

## Deferred decisions

- HDD filesystem, mount point, Proxmox storage name, and content configuration.
- Backup schedule, retention, consistency, and restore validation procedures.
- Off-machine recovery copies for important data.
- SSD capacity allocation for future application data and alternate environments.

## References

- [Proxmox Directory storage backend](https://github.com/proxmox/pve-docs/blob/master/pve-storage-dir.adoc)
- [Proxmox VM backup and restore](https://github.com/proxmox/pve-docs/blob/master/vzdump.adoc)
- [Current provisioning configuration](../../infrastructure/vms.tf)
