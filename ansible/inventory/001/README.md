# Cluster 001 variables

Commit only non-secret inventory and cluster-specific variables here. Existing shared
k3s configuration is in `ansible/group_vars/k3s.yml`;
`ansible/group_vars/all.yml` contains legacy kubeadm settings.

OpenTofu writes generated hosts to `inventory.yml` in this directory. This file
contains host addresses and SSH usernames, not credentials, and may be committed.
Keep credentials and SSH private keys in `.local/credentials/`.

Run Ansible from `ansible/`; its default inventory selects this cluster. Pass
`-i inventory/<cluster-id>/inventory.yml` explicitly when selecting another cluster.

Cluster 001 uses one `control_plane` host (`cp-01`) and an empty `workers`
group. Run `make setup-k3s CLUSTER=001` from the repository root after provisioning.
