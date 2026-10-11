#!/usr/bin/env bash
set -euo pipefail

cluster_id="${1:-001}"
if [[ "$cluster_id" != "001" ]]; then
  printf 'Cluster %s is not implemented.\n' "$cluster_id" >&2
  exit 1
fi

cat >&2 <<'MESSAGE'
Bootstrap scaffold: no resources have been changed.
Before enabling this workflow, implement
cluster-bootstrap, and configure tools, credentials, and Git repository access.
Required stages:
  1. Check prerequisites and the three-running-VM limit.
  2. Apply base-env; verify the generated inventory file.
  3. Run Ansible and verify Kubernetes readiness.
  4. Fetch kubeconfig into .local/clusters/001/kubeconfig.
  5. Apply cluster-bootstrap; verify Argo CD and GitOps synchronization.
See docs/guides/bootstrap.md.
MESSAGE
exit 1
