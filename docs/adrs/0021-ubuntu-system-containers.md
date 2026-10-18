# ADR 0021: Provision Ubuntu system containers for standalone services

- **Status:** Accepted
- **Date:** 2026-10-18
- **Amends:** [ADR 0020](0020-oci-backed-lxc-provisioning.md)

## Context

The user selects an Ubuntu LXC system container for installing cloudflared as a
persistent service. A minimal Ubuntu OCI application image does not supply the
same system initialization workflow. Existing OCI support remains useful.

## Decision

Extend `base-env` with an `lxc_templates` map for HTTPS rootfs archives (or HTTP
with a required checksum) and a
`source` field in `containers`: `template` or the compatible default `oci`.
System guests use their selected OS setup, an unprivileged container with
nesting for modern systemd, static LAN networking, and the shared root SSH key.
OCI guests keep their application entrypoint and host-managed networking.

Configure one Ubuntu 24.04 container named `cloudflared` in cluster 001, using
CT ID 204 and 192.168.1.204/24, one core, 512 MiB RAM, and an 8 GiB SSD root disk.
Store the versioned Proxmox Ubuntu LXC template on HDD template storage with its
catalog SHA512 checksum. Generic Canonical cloud-image rootfs archives can include
device nodes that fail extraction in an unprivileged user namespace; use the
Proxmox system template while retaining unprivileged isolation.
Leave the guest stopped and boot startup disabled until ID,
address availability, and additional host capacity have been verified.

Include system containers in a separate `system_containers` Ansible group with
root SSH. Scope the kubeadm preparation play to `control_plane:workers` so it
cannot configure this container as a Kubernetes node. Preserve VM resource
addresses, sizing, and source media.

## Consequences

- [ADR 0003](0003-node-topology-and-resource-allocation.md)'s three-running-VM
  limit and host memory constraints remain unchanged; LXC adds resource usage.
- Provisioning creates the Ubuntu host. Ansible installation of cloudflared and
  secure tunnel-token delivery are separate work, not part of this base-env edit.
- No OCI technology-preview features are required for system-template guests.
- The existing Kubernetes HTTP tunnel connector remains managed by Argo CD.
- No live resources, tokens, or state are modified by this implementation.

## References

- [Pinned LXC resource](https://github.com/bpg/terraform-provider-proxmox/blob/v0.115.0/docs/resources/virtual_environment_container.md)
- [Pinned template download resource](https://github.com/bpg/terraform-provider-proxmox/blob/v0.115.0/docs/resources/download_file.md)
- [Proxmox appliance catalog and checksums](http://download.proxmox.com/images/aplinfo-pve-9.dat)
