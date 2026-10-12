# Cloudflared

Argo CD deploys the connector for a remotely managed Cloudflare Tunnel.
`apps/roots/001/cloudflared.yaml` defines one Application, `cloudflared`. It uses the
published HelmForge chart pinned to **1.5.17**, and this repository for shared
`values.yaml` followed by `override/001/values.yaml`. The root Kustomization
explicitly includes the Application; values files are not Kubernetes resources.

Cloudflare manages the tunnel, hostname routes, DNS, and Access policies
separately. This application does not create Cloudflare resources or publish
a workload by itself.

## Layout

```text
apps/cloudflared/
├── values.yaml             # Shared defaults
├── override/001/values.yaml # Cluster-specific overrides
├── extra/                  # Encrypted token manifest for cluster 001
└── README.md
```

## Helm configuration

The chart is fetched directly from `https://repo.helmforge.dev`. No chart source
or templates are kept in this repository. Update `values.yaml` for shared
defaults and `override/<id>/values.yaml` for cluster-specific settings. Helm
loads the override file last, merging nested maps and replacing scalar and
list values. The cluster 001 override starts empty, preserving the defaults.
For example, change the replica count for cluster 001 by adding:

```yaml
# override/001/values.yaml
replicaCount: 3
```

Set the Helm repository, chart name, pinned chart version, values Git revision,
and destination namespace directly in `apps/roots/001/cloudflared.yaml`. No generator or
separate config file is needed. Review chart upgrades by rendering before
deployment.

```yaml
tunnel:
  quickTunnel:
    enabled: false
  existingSecret: cloudflared-tunnel-token
  existingSecretKey: token
```

The existing Secret's name and key must match these values. Quick tunnels are
explicitly disabled. The Git source has `ref: values` and no `path`, so it
supplies both Helm values files without deploying
additional manifests. A third Git source deploys manifests from `extra/`,
including the cluster 001 SealedSecret. The chart creates no token Secret with
these settings.

Validate locally without contacting the cluster (the first command downloads
the pinned public chart into a temporary directory):

```sh
helm pull cloudflared --repo https://repo.helmforge.dev --version 1.5.17 --destination /tmp
helm template cloudflared /tmp/cloudflared-1.5.17.tgz --namespace cloudflare -f apps/cloudflared/values.yaml -f apps/cloudflared/override/001/values.yaml
kubectl kustomize apps/roots/001
```

## Deployment

The Helm values pin `cloudflare/cloudflared:2026.10.0` and runs two replicas with
preferred placement on separate nodes. Normal kubeadm control-plane taints keep
these pods on the workers. Requests total 200m CPU and 256 MiB memory; each pod
has a 256 MiB memory limit. These are starting allocations; measure usage under
your traffic. A disruption budget retains one ready replica during voluntary
evictions. Both pods still share the same physical Proxmox host.

The connector only needs outbound connectivity and access to cluster DNS and
the target Services. It needs no NodePort, LoadBalancer, inbound Service, router
port-forward, or Kubernetes API token. `/ready` checks tunnel connectivity;
there is no liveness probe to restart pods during a Cloudflare connectivity
outage. Keep the replica count fixed instead of attaching an autoscaler.

## Tunnel credentials

Cluster 001 deploys into the `cloudflare` namespace, as selected in its
Application destination. Create the token Secret in that same namespace.

Create a remotely managed tunnel named `homelab-001` in Cloudflare. Save only its
token in `.local/credentials/001/cloudflared-token`, without a trailing newline,
and set file mode 0600 and directory mode 0700. Do not commit the token, include
it in command arguments, or paste it into logs. The connector uses a tunnel
token, not the Cloudflare account API token.

To generate encrypted YAML interactively, put the tunnel token in a private
`.env` file as `token=<your tunnel token>` (use the lowercase key `token`), then
run `make generate-seal-secret`. Enter name `cloudflared-tunnel-token`, namespace
`cloudflare`, and the `.env` path. Copy the generated encrypted YAML to
`apps/cloudflared/extra/cloudflare-token-sealed.yaml`, commit and push, wait for
synchronization, then restart Cloudflared to refresh its token environment
variable. See the [generic sealing guide](../sealed-secrets/README.md#seal-credentials).

Before enabling the Application, run these commands locally from the repository
root. These commands modify the cluster; they are setup instructions, not part
of the repository validation workflow:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml create namespace cloudflare --dry-run=client -o yaml | kubectl --kubeconfig .local/config/001/kubeconfig.yaml apply -f -
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cloudflare create secret generic cloudflared-tunnel-token --from-file=token=.local/credentials/001/cloudflared-token
```

The Application now deploys `extra/cloudflare-token-sealed.yaml`, which the
Sealed Secrets controller decrypts into `cloudflared-tunnel-token`. Wait for that
controller before syncing this application. The manual creation commands above
are an alternative setup path; an existing Secret must be explicitly adopted
as described in the Sealed Secrets guide. Pods cannot start until the Secret
exists. Rotate the token by resealing it and updating the encrypted manifest,
then restart the Deployment so the environment variable is refreshed. After
rebuilding, restore the sealing keys or reseal using the new certificate.

The [Sealed Secrets guide](../sealed-secrets/README.md) describes an optional
encrypted GitOps workflow and adoption of an existing token Secret. Keep the
strictly sealed name `cloudflared-tunnel-token` and namespace `cloudflare` unchanged.

Commit and push the manifests when ready to enable reconciliation. The root
Application tracks `main` and creates this child Application, which
automatically syncs its resources.

## Publish a workload

In Cloudflare, add a published application route to `homelab-001`, for example:

| Hostname | Service URL |
| --- | --- |
| `app.example.com` | `http://app.apps.svc.cluster.local:8080` |

Replace the hostname, Service name, namespace, and port with your workload's
actual settings. The Service may stay ClusterIP; no ingress controller is
required for direct Service routing. Add Cloudflare Access authentication for
private dashboards before publishing them. A tunnel alone does not restrict
who can visit a published hostname.

Check the deployment and then test the hostname from outside your LAN:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application cloudflared
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cloudflare rollout status deployment/cloudflared
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cloudflare get pods -o wide
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cloudflare logs deployment/cloudflared --tail=50
```

## Additional clusters and teardown

For cluster 002, add `override/002/values.yaml` and a separate Application
under `apps/roots/002/`, included only by that cluster's root Kustomization. Load shared
`values.yaml` followed by the cluster 002 overrides. Reuse the same Secret name
in that cluster with a separate tunnel token,
and use `.local/config/002/kubeconfig.yaml`. Create a distinct `homelab-002`
tunnel and explicit routes for that cluster.

The child Application has a cascading-deletion finalizer. Removing it deletes
its Deployment, ServiceAccount, disruption budget, and SealedSecret,
disconnecting the tunnel. Deleting the SealedSecret also deletes its owned
token Secret. The namespace is not listed in this application's resources.
Delete the Cloudflare routes and tunnel separately when retiring the cluster.

## Sources

- [HelmForge Cloudflared chart](https://helmforge.dev/docs/charts/cloudflared/)
- [Argo CD external Helm values](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/)
- [Cloudflare Kubernetes deployment](https://developers.cloudflare.com/tunnel/guides/kubernetes/)
- [Cloudflared 2026.10.0 release](https://github.com/cloudflare/cloudflared/releases/tag/2026.10.0)
- [Cloudflare Access setup](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)
