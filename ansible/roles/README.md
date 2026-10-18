# Reusable roles

Configuration currently lives in `../tasks/` and `../playbooks/`.
The single-node k3s entry point is `../playbooks/site.yml` (importing `k3s.yml`);
the legacy three-node entry point is `kubeadm.yml`. Extract tasks into roles
without changing cluster behavior when implementing the lifecycle workflow.
