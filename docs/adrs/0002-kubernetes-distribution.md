# ADR 0002: Bootstrap upstream Kubernetes with kubeadm

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

[ADR 0001](0001-host-platform.md) selects a persistent Proxmox VE host with
disposable Kubernetes virtual machines. The Dell has 16 GB RAM and limited SSD
capacity, so cluster services and workloads must fit within a modest resource
budget.

The primary goal is to learn Kubernetes cluster operations, including bootstrap,
node joining, networking, troubleshooting, and upgrades. Provisioning must be
repeatable through IaC. The existing Ansible playbooks already use kubeadm to
bootstrap Kubernetes, configure containerd, and install Flannel.

The alternatives considered are upstream Kubernetes bootstrapped with kubeadm
and K3s. Kubeadm is a bootstrap tool; K3s is a packaged Kubernetes distribution.

## Decision

Use upstream Kubernetes bootstrapped with kubeadm for the homelab's Kubernetes
VMs. Automate node preparation and cluster bootstrap through the repository's
Ansible playbooks as part of the IaC rebuild workflow.

This decision selects the Kubernetes installation approach. It does not approve
the existing code's package versions, node topology, resource allocations, or
add-on choices; those require separate decisions.

## Reasons

- Kubeadm provides direct practice with runtime configuration, control-plane
  bootstrap, node joining, and separately installed cluster components.
- Explicit component configuration supports the goal of understanding and
  troubleshooting how Kubernetes fits together.
- The existing Ansible implementation already uses kubeadm, reducing the changes
  needed to establish the lab.
- Proxmox simplifies host management while kubeadm keeps Kubernetes operations
  as the main learning exercise.

## Alternative considered

### K3s

K3s is a fully compliant Kubernetes distribution designed for a smaller baseline
footprint and simpler installation. It packages containerd and several common
networking, ingress, and storage components. These defaults can be disabled or
replaced.

K3s supports normal Kubernetes workloads and is suitable for learning scheduling,
RBAC, storage, GitOps, and application troubleshooting. Its packaged installation
can reduce provisioning steps and component management work.

K3s is not selected because the current priority is direct practice with upstream
Kubernetes bootstrap and component operations. Choosing it would also require
replacing the existing kubeadm installation and bootstrap tasks. No fixed memory
saving is assumed without measurements under comparable workloads.

## Consequences

- More installation steps and independently managed components must be maintained
  than with a packaged K3s installation.
- Kubernetes packages, runtime, and add-on versions must be pinned and coordinated
  for repeatable rebuilds and compatible upgrades.
- Pod networking must be installed separately; ingress and storage integrations
  also require explicit selection and configuration.
- Bootstrap automation does not constitute an upgrade procedure. Upgrades need
  their own documented and validated workflow.
- Resource allocations must leave capacity for Proxmox and application workloads;
  actual cluster usage must be measured.
- Destroying and recreating nodes does not restore persistent application data.
  Data recovery remains a separate concern.

## Deferred decisions

- Kubernetes version and upgrade policy.
- Node topology, guest operating system, and resource allocations.
- Container runtime configuration and version.
- Pod networking, ingress, and service exposure.
- Persistent storage and backup/restore strategy.
- Detailed provisioning workflow, credentials, and state management.

## References

- [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [K3s overview](https://docs.k3s.io/)
- [K3s requirements](https://docs.k3s.io/installation/requirements)
- [K3s datastore options](https://docs.k3s.io/datastore)
