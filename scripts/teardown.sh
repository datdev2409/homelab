#!/usr/bin/env bash
set -euo pipefail

cluster_id="${1:-001}"
if [[ "$cluster_id" != "001" ]]; then
  printf 'Cluster %s is not implemented.\n' "$cluster_id" >&2
  exit 1
fi

cat >&2 <<'MESSAGE'
Teardown scaffold: no resources have been changed.
Teardown behavior must be implemented before enabling it.
Required stages:
  1. Back up data and handle GitOps workloads while Argo CD is running.
  2. Destroy cluster-bootstrap while the Kubernetes API is reachable.
  3. Destroy base-env last.
See docs/guides/teardown.md.
MESSAGE
exit 1
