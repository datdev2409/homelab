# Grafana Cloud monitoring

Argo CD Application `alloy` installs Grafana's `k8s-monitoring` chart **4.5.3**
in namespace `monitoring`. Shared values load before `override/001/values.yaml`.
See [ADR 0024](../../docs/adrs/0024-grafana-cloud-and-alloy.md).

The enabled components are:

| Component | Purpose |
| --- | --- |
| Alloy collector (one replica, v1.20.0) | Scrape and forward metrics to Grafana Cloud |
| Alloy Operator | Manage the collector's Kubernetes workload |
| kube-state-metrics | Expose Kubernetes object state, including pods and deployments |
| node-exporter (one pod per Linux node) | Expose Linux guest CPU, memory, filesystem, and network metrics |

The chart also installs the Alloy CRD, ConfigMap, Services, service accounts,
and RBAC. The operator watches only its own namespace. Kubernetes workload,
kubelet/cAdvisor, and Linux guest metrics use a 60-second interval, the chart's
default metric allowlists, and cluster label `homelab-001`. Guest metrics do
not include the Proxmox host or other guests. Separate control-plane collection
is disabled for the current SQLite-backed k3s setup.

No local Grafana, Prometheus, Alertmanager, log or trace collection, cost
monitoring, or ingress is enabled. Cloud dashboards, alerts, and notification
destinations are configured separately. The collector uses ephemeral WAL storage;
pod replacement can lose buffered samples during a Cloud/network outage.

On one Linux node, the configured workloads request 160m CPU and 288 MiB memory
in total, excluding operator-created sidecars. Collector memory is limited to
512 MiB; the `small` preset also sets a 500m CPU limit. Measure actual usage and
Grafana Cloud active series after deployment; these are initial budgets.

## Credentials

The collector requires Secret `grafana-cloud` in namespace `monitoring` with:

| Key | Value |
| --- | --- |
| `GRAFANA_CLOUD_PROMETHEUS_URL` | Stack's Prometheus remote-write URL ending in `/api/prom/push` |
| `GRAFANA_CLOUD_PROMETHEUS_USERNAME` | Prometheus instance ID |
| `GRAFANA_CLOUD_ACCESS_TOKEN` | Stack-scoped Cloud Access Policy token with `metrics:write` |

Fill in the protected, Git-ignored
`.local/credentials/001/grafana-cloud.secret.yaml` template locally. Never put
credentials in Helm values, command arguments, or Git. The dashboard URL and a
Grafana service-account token are not the remote-write credentials.

For an initial manual Secret, after filling in the local template:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml create namespace monitoring --dry-run=client -o yaml | kubectl --kubeconfig .local/config/001/kubeconfig.yaml apply -f -
kubectl --kubeconfig .local/config/001/kubeconfig.yaml create -f .local/credentials/001/grafana-cloud.secret.yaml
```

The manual Secret is outside Argo CD ownership and must be restored after a
rebuild. For encrypted GitOps persistence, use the existing
[Sealed Secrets workflow](../sealed-secrets/README.md), then add the encrypted
manifest as a separate cluster-specific source in the Alloy Application.
Transfer ownership explicitly if the manual Secret already exists. Do not let
multiple secret controllers manage this Secret. After credential rotation,
restart the collector because it reads credentials through environment variables.

## Validation and rollout

```sh
helm pull k8s-monitoring --repo https://grafana.github.io/helm-charts --version 4.5.3 --destination /tmp
helm lint /tmp/k8s-monitoring-4.5.3.tgz -f apps/alloy/values.yaml -f apps/alloy/override/001/values.yaml
helm template alloy /tmp/k8s-monitoring-4.5.3.tgz --namespace monitoring --include-crds -f apps/alloy/values.yaml -f apps/alloy/override/001/values.yaml > /tmp/homelab-alloy-rendered.yaml
kubectl kustomize apps/roots/001
```

Push to `main` for the root Application to reconcile the child. Argo CD owns
this chart; do not install a second Helm release. The collector cannot start
until the Secret exists. Check without printing Secret contents:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application alloy
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n monitoring get alloys,pods
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n monitoring rollout status deployment/alloy-alloy-operator
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n monitoring rollout status deployment/alloy-kube-state-metrics
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n monitoring rollout status daemonset/alloy-node-exporter
```

Check recent samples in Grafana Cloud Explore with
`up{cluster="homelab-001"}` and `kube_node_info{cluster="homelab-001"}`.
Pod readiness alone does not verify Cloud ingestion. Review ingestion usage and
account limits. A monitor outside this laptop is required for whole-host outages.

The Application has a cascading-deletion finalizer. Remove Alloy instances
while the operator is still running before removing the operator or its CRD.
Helm uninstall hooks are disabled because Argo CD prunes resources directly.

## Sources

- [Official chart](https://github.com/grafana/k8s-monitoring-helm)
- [Grafana Cloud setup](https://grafana.com/docs/grafana-cloud/observe-and-act/monitor-infrastructure/kubernetes-monitoring/configuration/helm-chart-config/)
