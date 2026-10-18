# ADR 0020: Support optional OCI-backed LXC application containers

- **Status:** Accepted
- **Date:** 2026-10-18

## Context

The user requests OCI image support for LXC provisioning in `base-env`. Existing
Kubernetes VMs and cloud-image/ISO installation remain in use. The pinned
`bpg/proxmox` 0.115.0 provider supports OCI pulls and LXC application containers.

## Decision

Add optional `oci_images` and `containers` maps alongside `vms`. Pull images with
`proxmox_oci_image` and create unprivileged LXC containers with the existing
container resource. Use Proxmox VE 9.1+ host-managed networking and an unmanaged
OS type for application images. Keep registry references, sizing, and addresses
in cluster inputs; do not add live containers as part of this implementation.

Allow LXC-only instances without VM media. Retain VM resource addresses and the
cloud-image/ISO behavior from [ADR 0010](0010-vm-installation-media-and-fresh-provisioning.md).
Keep OCI application containers outside the Kubernetes Ansible inventory: these
images do not necessarily contain SSH, Python, or a system init process.

Store pulled OCI templates on HDD template storage and active root disks on SSD,
consistent with [ADR 0005](0005-hdd-usage-and-application-storage-placement.md).
Default containers to stopped with boot startup disabled. The resource budget
and three-running-VM limit in [ADR 0003](0003-node-topology-and-resource-allocation.md)
remain applicable; enabling LXC guests requires accounting for their additional
host resource usage.

## Consequences

- Application-container support is a Proxmox technology preview and requires a
  compatible host; provider validation alone cannot verify host compatibility.
- Image keys can be shared by multiple containers. Immutable references improve
  reproducibility; changing an image may replace a container.
- Validate IDs, names, and IPv4 addresses across the module's VM and LXC maps.
  Availability outside this state must be checked before deployment.
- Existing Kubernetes provisioning and Ansible workflows remain VM-based.
- Image pulls and provisioning occur only on a separately authorized apply.

## References

- [Proxmox OCI images](https://pve.proxmox.com/pve-docs/chapter-pct.html#_open_container_initiative_oci_images)
- [Pinned OCI image resource](https://github.com/bpg/terraform-provider-proxmox/blob/v0.115.0/docs/resources/oci_image.md)
- [Pinned LXC resource](https://github.com/bpg/terraform-provider-proxmox/blob/v0.115.0/docs/resources/virtual_environment_container.md)
