# Cluster 001 variables

Commit only non-secret cluster-specific variables here. Existing shared
configuration remains in `ansible/group_vars/all.yml` during migration.

Generated hosts belong in `.local/clusters/001/inventory.yml`. The new workflow
must load this inventory together with shared and cluster-specific variables
explicitly, rather than relying on inventory-relative discovery.
