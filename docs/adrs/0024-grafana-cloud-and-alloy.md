# ADR 0024: Grafana Cloud metrics with Alloy

- **Status:** Accepted
- **Date:** 2026-10-20

## Decision

Use Grafana Cloud for metrics storage and dashboards, with Grafana Alloy on
cluster 001. Argo CD owns the pinned official `k8s-monitoring` chart, including
its Alloy Operator, collector, kube-state-metrics, and node-exporter resources.
The operator manages one collector in namespace `monitoring`.

Collect Kubernetes object state, kubelet/cAdvisor, and Linux guest metrics at
60-second intervals using default metric allowlists and label `homelab-001`.
Disable separate control-plane collection for the single-node, SQLite-backed
k3s setup. Logs, traces, application-specific scrapes, and Proxmox host metrics
are outside the initial scope.

Load Cloud credentials from a separate Kubernetes Secret through environment
variables. Plaintext stays in the ignored cluster credentials folder. An initial
manual Secret may be created separately; encrypted GitOps persistence can use
the existing Sealed Secrets controller with explicit ownership transfer.

## Consequences

No local Prometheus, Grafana, or Alertmanager is required. Cloud connectivity,
retention, and account ingestion limits affect delivery and availability.
The collector WAL is ephemeral; replacing its pod can lose buffered samples.
Measure memory and ingestion after rollout; host headroom remains limited under
ADR 0022. Monitoring on this laptop cannot independently report its own complete
failure. Credentials and successful Cloud ingestion must be verified separately
from chart reconciliation.

## References

- [Component guide](../../apps/alloy/README.md)
- [Grafana chart](https://github.com/grafana/k8s-monitoring-helm)
- [ADR 0022](0022-single-node-k3s.md)
