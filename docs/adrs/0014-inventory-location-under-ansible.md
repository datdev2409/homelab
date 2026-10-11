# ADR 0014: Keep non-secret generated inventory under Ansible

- **Status:** Accepted
- **Date:** 2026-10-11
- **Amends:** [ADR 0013](0013-opentofu-managed-ansible-inventory.md) inventory destination and Git exclusion

## Decision

Write generated inventory to `ansible/inventory/<cluster-id>/inventory.yml`
instead of `.local/config/clusters/<cluster-id>/inventory.yml`. Reuse the existing
Ansible inventory directory rather than creating a separate local config tree.

Terragrunt passes the absolute destination into the reusable base-env module.
OpenTofu continues managing the file during apply through
`local_file.ansible_inventory`. The object and filename outputs remain available.

The inventory contains host addresses, roles, and SSH usernames, not secrets,
and may be committed to Git. Credentials, private keys, kubeconfig, and state
remain outside Git under `.local/`.

## Consequences

- Ansible's default inventory selects `inventory/001/inventory.yml` when run
  from `ansible/`. Select other clusters explicitly with `-i`.
- Existing 0600 file and 0700 new-directory permissions remain unchanged.
- An apply reconciles the local-file resource to the new destination; no live
  apply or state edit is performed as part of this code change.
- Destroy still removes the managed local inventory file. Review the resulting
  Git change before committing.
- Keep inventory free of token values, passwords, and private-key contents.
