# Cluster 001 variables

Commit only non-secret inventory and cluster-specific variables here. Existing shared
configuration remains in `ansible/group_vars/all.yml` during migration.

OpenTofu writes generated hosts to `inventory.yml` in this directory. This file
contains host addresses and SSH usernames, not credentials, and may be committed.
Keep credentials and SSH private keys in `.local/credentials/`.

Run Ansible from `ansible/`; its default inventory selects this cluster. Pass
`-i inventory/<cluster-id>/inventory.yml` explicitly when selecting another cluster.
