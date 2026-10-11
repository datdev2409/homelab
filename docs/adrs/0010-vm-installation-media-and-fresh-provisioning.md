# ADR 0010: Support cloud images and installer ISOs for fresh VM provisioning

- **Status:** Accepted
- **Date:** 2026-10-11

## Context

The user requests configurable cloud-image and installer-ISO support in
`base-env`, including local uploads. The user will provision from scratch and
does not require preserving existing provisioning state through migration.

## Decision

Support two explicit installation modes for a shared media artifact per
base-env deployment:

- `cloud_image`: import a preinstalled OS disk and configure it with cloud-init.
- `installer_iso`: create a blank disk, attach the ISO as a CD-ROM, and boot
  the installer. Installation and guest configuration are separate steps.

Accept exactly one HTTPS download URL or absolute local file path. Store
source media on HDD using the corresponding `import` or `iso` content type;
keep active VM disks on SSD. Support optional checksums, with SHA256 required
for local uploads by the provider.

Keep cluster 001 on Ubuntu cloud images by default, consistent with
[ADR 0007](0007-kubernetes-vm-operating-system.md). ISO support is an alternative
installation capability and does not automatically provide Ubuntu autoinstall
or Talos machine configuration. ISO guests must be configured to match the
desired inventory before Ansible runs.

Expose per-VM disk-first boot and installer-detachment settings for the
post-installation phase.

## Fresh provisioning

Use fresh state for the new configuration; do not implement legacy resource
address compatibility or automatically adopt existing VMs. This supersedes
the state-migration requirement in
[ADR 0009](0009-repository-structure-and-cluster-lifecycle.md) for this deployment.
Existing legacy files and live resources are not deleted by this decision.
VM IDs and addresses must be available before applying the new configuration.

## Consequences

- Cloud images retain the automated guest-initialization workflow.
- ISO mode provisions installation hardware, not a fully configured guest OS.
  Unattended installation remains separate work.
- Changing modes or image sources on existing VMs requires reviewing disk and
  VM replacement effects in the plan.
- Local media paths are resolved on the OpenTofu runner, not the Proxmox host.
- Exact artifact pinning and checksums remain cluster configuration choices.
- No live provisioning or destruction occurs while implementing this module.

## References

- [Provider file uploads](https://github.com/bpg/terraform-provider-proxmox/blob/v0.115.0/docs/resources/virtual_environment_file.md)
- [Provider VM configuration](https://github.com/bpg/terraform-provider-proxmox/blob/v0.115.0/docs/resources/virtual_environment_vm.md)
