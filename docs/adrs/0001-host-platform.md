# ADR 0001: Use Proxmox VE as the homelab host platform

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

The homelab will use a Dell Inspiron 5570 with the following hardware:

| Component | Specification |
| --- | --- |
| CPU | Intel Core i7-8550U |
| RAM | 16 GB |
| Storage | 125 GB SSD and 1 TB HDD |
| Graphics | AMD Radeon R7 M460, 4 GB |
| Current operating system | Windows 10 |

The primary goal is to learn Kubernetes cluster operations, including node
provisioning, networking, upgrades, failures, and rebuilding. Configuration,
provisioning code, and documentation will live in this repository. Kubernetes
nodes and declared workloads must be reproducible through infrastructure as code
(IaC), with data recovery handled separately.

The Dell can become a dedicated lab machine, replacing Windows. The host itself
will remain installed during routine cluster destruction and recreation. Existing
provisioning code already targets Proxmox and uses Ansible to configure Kubernetes
nodes.

## Decision

Install Proxmox VE directly on the Dell, replacing Windows, and operate it as a
single persistent virtualization host. Run Kubernetes nodes in separate,
disposable virtual machines managed through IaC.

Use the built-in browser interface and VM consoles for visibility and
troubleshooting. Keep IaC authoritative for managed VM configuration; intentional
changes to that configuration must be captured in code.

This decision selects only the host platform. It does not select a Proxmox
version or installation procedure.

## Reasons

- Proxmox provides an integrated platform, reducing the amount of host management
  tooling that must be assembled and maintained.
- Its built-in browser interface simplifies daily management and provides VM
  console access when a guest's SSH or networking is unavailable.
- Integrated networking, storage, and backup management tools support future lab
  experiments without requiring a separate management system.
- The existing provisioning code already targets Proxmox, reducing the changes
  needed to establish the lab.

## Alternative considered

### Ubuntu Server with KVM/libvirt

Ubuntu Server with KVM/libvirt can also run separate Kubernetes VMs and support
IaC provisioning. It offers direct control over host packages, networking,
storage, and services, and a minimal installation can run fewer management
components.

It would require more work to configure and maintain host networking, storage
pools, access permissions, management tools, and backup workflows. The existing
Proxmox provisioning layer would also need to be replaced.

Both options use KVM/QEMU for virtual machines. Proxmox is preferred for its
integrated management experience, allowing more of the initial learning effort
to focus on Kubernetes operations. No measured performance advantage is assumed
for either option.

## Consequences

- The lab must follow Proxmox platform conventions and maintain the host and its
  management services in addition to the Kubernetes VMs.
- Host resource use must be included when sizing VMs for the available 16 GB RAM
  and SSD capacity.
- Routine destroy-and-recreate workflows affect the Kubernetes VMs and declared
  workloads, not the Proxmox installation.
- Recreating configuration does not restore persistent application data. Backup
  and recovery behavior requires a separate decision.
- All VMs share one physical failure domain. Multiple Kubernetes nodes on this
  laptop do not provide hardware high availability.
- Host installation prerequisites and persistent host configuration must be
  documented, with automation added where appropriate.

## Deferred decisions

- Kubernetes distribution and node topology.
- Node CPU, memory, and disk allocations.
- Host and cluster networking.
- SSD/HDD layout and application storage.
- Backup, restore, and persistent data handling.
- Detailed provisioning workflow, credentials, and state management.

## References

- [Proxmox VE features](https://www.proxmox.com/en/products/proxmox-virtual-environment/features)
- [Proxmox VE hardware requirements](https://proxmox.com/en/products/proxmox-virtual-environment/requirements)
- [Ubuntu Server: libvirt](https://ubuntu.com/server/docs/how-to/virtualisation/libvirt/)
