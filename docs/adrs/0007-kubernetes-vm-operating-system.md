# ADR 0007: Use Ubuntu Server 24.04 LTS for Kubernetes VMs

- **Status:** Accepted
- **Date:** 2026-10-11

## Context

[ADR 0001](0001-host-platform.md) selects Proxmox VE as the physical host.
[ADR 0002](0002-kubernetes-distribution.md) selects upstream Kubernetes
bootstrapped with kubeadm. The VM operating system must support repeatable
provisioning and direct administration while learning Kubernetes operations.

The existing code imports an Ubuntu 24.04 amd64 cloud image and explicitly
requires Ubuntu 24.04 in Ansible. Node configuration uses cloud-init, SSH,
APT, and systemd. The lab's current VM root disk allocations are 16 GiB per
node, as recorded in
[ADR 0003](0003-node-topology-and-resource-allocation.md).

## Decision

Use Ubuntu Server 24.04 LTS, amd64, without a desktop environment, on all
three Kubernetes VMs. Retain the cloud-image provisioning approach and the
existing cloud-init and Ansible node configuration workflow.

Keep direct SSH and shell access for VM administration and troubleshooting.
Capture intentional managed configuration changes in code so that nodes can
be recreated, rather than relying on manual changes.

This selects the guest OS. It does not change the Proxmox host OS, VM resource
allocations, or the accepted kubeadm approach.

## Reasons

- Ubuntu provides familiar Linux administration tools and direct control over
  VM packages, services, configuration, and diagnostics.
- SSH and shell access make it easier to inspect and troubleshoot nodes while
  learning Linux and Kubernetes operations.
- The existing provisioning and Ansible code already targets Ubuntu 24.04,
  avoiding an additional OS adaptation effort for the initial cluster.
- The LTS release and official cloud images provide a suitable foundation for
  the lab's repeatable provisioning workflow.

## Alternatives considered

### Debian 13

Debian provides a stable general-purpose Linux base and cloud-init-enabled cloud
images. It remains a useful future experiment, but would require adapting and
validating the Ubuntu-specific OS checks, packages, and runtime configuration.

### Rocky Linux 9

Rocky provides an enterprise Linux environment for learning DNF and SELinux.
It would require larger changes to the APT-based Ansible tasks and validation
of its security and networking configuration.

### Talos Linux

Talos provides a minimal, immutable Kubernetes-focused OS with declarative
machine configuration and API-driven administration. Its API server,
controller manager, and scheduler run as static pods, so it still supports
learning Kubernetes control-plane architecture.

Talos would replace the current guest administration and Kubernetes bootstrap
workflow with Talos configuration and lifecycle management. Ubuntu is preferred
for the initial cluster because conventional SSH, shell, and package management
offer easier administration and more direct control over the VMs.

Keep Talos as a future alternate-cluster experiment for declarative node
management and immutable infrastructure. Revisit ADR 0002 if Talos is selected
for the primary cluster. Alternate experiments must respect the running-VM
limit in ADR 0003.

## Consequences and deferred work

- A general-purpose OS requires deliberate package, service, and update
  management. Direct access can introduce drift unless changes are captured
  in provisioning code.
- The current Ubuntu image URL uses `noble/current`, whose contents can change.
  Select and pin a dated image and checksum before claiming exact image-level
  rebuild reproducibility; this ADR does not choose that artifact.
- Store source cloud images on the HDD and keep active guest disks and
  application workloads on the SSD, as recorded in
  [ADR 0005](0005-hdd-usage-and-application-storage-placement.md).
- Measure disk usage after node bootstrap and representative workloads.
  Container images, logs, and temporary data must fit the existing disk budget.
- Kubernetes, runtime, add-on versions, and OS update policy remain separate
  configuration decisions.
- No provisioning-code changes or VM rebuilds are performed by this ADR.

## References

- [Ubuntu release lifecycle](https://ubuntu.com/about/release-cycle)
- [Ubuntu 24.04 cloud images](https://cloud-images.ubuntu.com/noble/)
- [Talos overview](https://docs.siderolabs.com/talos/v1.14/overview/what-is-talos)
- [Talos control plane](https://docs.siderolabs.com/talos/v1.14/learn-more/control-plane)
