# Authentik

Cluster 001 uses official chart and application **2026.8.5** in namespace
`authentik`, managed by `apps/roots/001/authentik.yaml`. Shared values load
before cluster overrides. See [ADR 0025](../../docs/adrs/0025-authentik-identity-provider.md)
for resource, storage, and ownership decisions.

One server and one worker share a 1 GiB local-path PVC at `/data`; PostgreSQL
uses an 8 GiB local-path PVC. Total requests are 300m CPU and 1280 MiB memory,
with 2560 MiB combined memory limits. This uses the chart's bundled test database
and official PostgreSQL image, pinned by the chart. No Redis is required.

## Credentials

Cluster 001's encrypted manifests in `extra/` create
`authentik-config` and `authentik-postgresql`. Both are sealed with strict scope
for this namespace and name. Keep their private originals outside Git:

- `.local/credentials/001/authentik-config.secret.json`
- `.local/credentials/001/authentik-postgresql.secret.json`

The configuration includes the Authentik secret key, database connection,
disabled error reporting, and a random bootstrap password for **akadmin**.
Retrieve `stringData.AUTHENTIK_BOOTSTRAP_PASSWORD` from the protected local
configuration file using your local editor. Do not paste it into logs or Git.
The bootstrap password is only used on first startup; subsequent password
changes happen in Authentik. No bootstrap API token is generated.

Never regenerate these files on an existing installation. Preserve the
Authentik secret key and coordinate database password changes with PostgreSQL.
Back up originals and the controller sealing keys outside the disposable VM.
See [Sealed Secrets](../sealed-secrets/README.md) for resealing and recovery.
Changes to Secrets loaded as environment variables require pod restarts.

## Access

Map `auth.datnguyen.me` to Traefik's LAN IP **192.168.1.30** in local DNS, then
open `https://auth.datnguyen.me` and log in as **akadmin**. cert-manager uses
ClusterIssuer `letsencrypt-prod` to issue `authentik-tls`.

For external access, configure the Cloudflare Tunnel published hostname
`auth.datnguyen.me` with origin
`https://traefik.traefik.svc.cluster.local:443`, preserving the Host header.
Set the origin TLS server name (`originServerName`) to `auth.datnguyen.me`
so certificate validation matches `authentik-tls`; keep TLS verification enabled.
DNS/tunnel routes are not created
by this Application. Do not put an Access policy that depends on Authentik in
front of Authentik itself, which would create an authentication loop.

For temporary local access after deployment:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n authentik port-forward svc/authentik-server 9000:80
```

Open `http://localhost:9000`. SMTP, MFA enrollment, providers, and application
SSO integrations are configured separately in Authentik. Managed Kubernetes
outposts are disabled initially; the embedded outpost remains available.

## Validation and deployment

```sh
helm pull authentik --repo https://charts.goauthentik.io --version 2026.8.5 --destination /tmp
helm lint /tmp/authentik-2026.8.5.tgz -f apps/authentik/values.yaml -f apps/authentik/override/001/values.yaml
helm template authentik /tmp/authentik-2026.8.5.tgz --namespace authentik -f apps/authentik/values.yaml -f apps/authentik/override/001/values.yaml
kubectl kustomize apps/roots/001
```

Commit and push to `main` to let the existing root Application reconcile it.
The Sealed Secrets controller must be ready first. Database migrations run
automatically during startup; the first rollout can take several minutes.

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n argocd get application authentik
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n authentik get sealedsecrets,pvc,pods,certificate,ingress
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n authentik rollout status statefulset/authentik-postgresql
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n authentik rollout status deployment/authentik-server
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n authentik rollout status deployment/authentik-worker
```

Verify login and an HTTPS request through Traefik before configuring providers.
The Ingress uses only Traefik's `websecure` entrypoint for LAN and tunnel access.

## Backup and removal

Back up the PostgreSQL database using a consistent dump, the `/data` volume,
private credentials, and sealing keys to protected storage outside the VM.
No scheduled backup is configured. Restore testing remains an operational task.
Back up before chart upgrades, because schema migrations can prevent downgrades.

The Application has a cascading-deletion finalizer. The explicit data PVC opts
out of Argo CD prune/delete; PostgreSQL's StatefulSet retains its generated PVC
by default. Both still depend on this node. Deleting the namespace or PVCs
destroys local data with the storage class's Delete reclaim policy.

## Sources

- [Official installation](https://docs.goauthentik.io/install-config/install/kubernetes/)
- [Official Helm chart](https://github.com/goauthentik/helm)
- [Automated bootstrap](https://docs.goauthentik.io/install-config/automated-install/)
