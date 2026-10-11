# ADR 0013: Write Ansible inventory through OpenTofu

- **Status:** Accepted
- **Date:** 2026-10-11
- **Amends:** [ADR 0009](0009-repository-structure-and-cluster-lifecycle.md) inventory generation and location

## Decision

Have base-env manage a `local_file.ansible_inventory` resource that writes YAML
to `.local/config/clusters/<id>/inventory.yml` during apply, after VM provisioning.
Retain the inventory object output and expose the generated file path as an output.

Terragrunt passes an absolute `inventory_path` input derived from the repository
root and cluster ID. The reusable module does not derive paths from its cache
location. This replaces manual export of inventory outputs into the location
previously proposed in ADR 0009.

Keep inventory files private (0600), newly created parent directories private
(0700), and all generated files excluded from Git through `.local/`.

## Consequences

- Applying base-env produces inventory without a separate export command.
- Ansible must use the new file explicitly; its existing default inventory
  configuration is not changed by this decision.
- Destroying the local-file resource deletes the inventory. A missing file on
  another runner is recreated on apply.
- The inventory describes desired guest addresses. ISO-mode guests must finish
  installation and networking/SSH configuration before Ansible can use it.
- Directory/file generation runs on the OpenTofu runner, not the Proxmox host.
- No VM provisioning or state changes are performed while implementing this code.

## References

- [Local file provider resource](https://github.com/hashicorp/terraform-provider-local/blob/v2.9.1/docs/resources/file.md)
