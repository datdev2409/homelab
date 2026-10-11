# ADR 0006: Retain the existing Proxmox root volume

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

[ADR 0004](0004-host-filesystem-and-vm-storage-backend.md) selects ext4 and
LVM-thin. [ADR 0005](0005-hdd-usage-and-application-storage-placement.md)
places ISOs, Ubuntu cloud images, VM backups, and archives on the HDD while
keeping active application storage on the SSD.

The reported SSD volume group is approximately 118.24 GiB. The host's LVM output
confirms the following current allocations:

| Allocation | Size |
| --- | --- |
| Root volume | Approximately 39.56 GiB |
| Swap | 8 GiB |
| Thin-pool data | Approximately 53.93 GiB |
| Thin-pool metadata | 1 GiB |
| Metadata repair spare | 1 GiB |
| Unallocated volume-group space | 14.75 GiB |

The host filesystem previously reported approximately 8.5 GiB used. Shrinking
the ext4 root filesystem would require offline maintenance and careful
filesystem and logical-volume resizing.

## Decision

Retain the existing Proxmox root logical volume at approximately 39.56 GiB.
Do not shrink the filesystem or logical volume. Keep provisioning assets and
backup archives on the HDD as accepted in ADR 0005.

Keep the current swap and thin-pool allocations unchanged for now. Any future
thin-pool expansion from unallocated volume-group space is a separate decision.

This revision replaces the previously accepted 24 GiB root target. That target
was documented but not implemented through this repository.

## Reasons

- Keeping the existing allocation avoids offline maintenance and the complexity
  and data-loss risk of shrinking the installed root filesystem.
- The existing root volume provides comfortable capacity for host updates,
  kernels, logs, and temporary files.
- The volume group already has 14.75 GiB unallocated, allowing future VM-pool
  expansion to be considered without shrinking root.

## Alternative considered

A 24 GiB root volume would release approximately 15.56 GiB for other LVM
allocations. It is not selected because resizing the installed root filesystem
is more complex than desired for the current lab. The existing allocation is
preferred for operational simplicity.

## Capacity consequences

- No additional VM-pool capacity is released from root. The pool remains
  approximately 53.93 GiB until a separate expansion is performed.
- Using all currently unallocated space would yield a pool of approximately
  68.68 GiB and leave no volume-group free-space reserve. This is a capacity
  calculation, not an approved allocation.
- Thin-provisioned virtual disks may advertise more combined capacity than the
  physical pool, but actual allocated blocks must fit within it. Stopped VMs
  continue to consume allocated disk space.

## Validation and deferred work

- This decision requires documentation only; no host disk changes are needed.
- Monitor root usage and thin-pool data and metadata usage as workloads grow.
- Before any future pool expansion, recheck volume-group free space and choose
  how much reserve to retain.

## References

- [Proxmox installation and LVM sizing](https://github.com/proxmox/pve-docs/blob/master/pve-installation.adoc)
- [ext4 resizing documentation](https://manpages.debian.org/bookworm/e2fsprogs/resize2fs.8.en.html)
