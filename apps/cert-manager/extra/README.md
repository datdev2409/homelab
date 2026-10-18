# Extra cert-manager resources

Place Kubernetes manifests such as ClusterIssuers in this directory. The
cert-manager Application deploys these manifests alongside the Helm chart,
including manifests in subdirectories.

For ClusterIssuers, use sync wave `1` so Argo CD waits for the cert-manager
deployments in the default wave before applying issuer configuration:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

Keep issuer credentials out of Git. Reference separately supplied Kubernetes
Secrets; with the default chart settings, ClusterIssuer credential Secrets
belong in the `cert-manager` namespace.

## Private CA for home.apra

`home-apra-issuer.yaml` creates a bootstrap SelfSigned Issuer in wave 1, a
private root CA Certificate in wave 2, and ClusterIssuer `home-apra-ca` in
wave 3. The root Certificate and generated Secret `home-apra-root-ca` live
in namespace `cert-manager`, where ClusterIssuers look up signing Secrets.
No private keys are stored in Git.

Workloads in any namespace can request certificates using:

```yaml
spec:
  dnsNames:
  - app.home.apra
  secretName: app-tls
  issuerRef:
    name: home-apra-ca
    kind: ClusterIssuer
    group: cert-manager.io
```

TLS Secrets are created in each Certificate's namespace. This issuer is intended
for `home.apra`; its name does not enforce DNS name restrictions. Keep access
to Certificate requests limited to trusted cluster users.

Clients must trust the private root. Export only its public certificate:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cert-manager get secret home-apra-root-ca -o jsonpath='{.data.tls\.crt}' | base64 --decode > /tmp/home-apra-root-ca.crt
```

Import that certificate into client trust stores and configure local DNS for
the requested hostnames. Back up the CA Secret privately. The root lasts ten
years and starts renewal a year before expiry. Plan renewal and redistribution
of the root before expiry; cert-manager does not automatically reissue existing
leaf certificates when the signing CA changes. See the
[CA issuer documentation](https://cert-manager.io/docs/configuration/ca/).

Moving from the earlier Argo CD namespace-scoped CA creates a new trust root.
Trust `home-apra-root-ca` on clients after the shared issuer is ready; the
Argo CD Certificate now references this ClusterIssuer and will be reissued.

## Let's Encrypt with Cloudflare DNS-01

`cluster-issuer.yaml` defines `letsencrypt-prod`, using Let's Encrypt's
production ACME endpoint and Cloudflare DNS-01. DNS-01 supports wildcard
certificates and does not require inbound access to Traefik. The optional
`spec.acme.email` is unset; add your contact address if desired. Cert-manager
generates the ACME account key in Secret `letsencrypt-prod-account-key`.

Create a Cloudflare API token with `Zone / DNS / Edit` and
`Zone / Zone / Read` permissions for the zones you want to issue certificates
for. Save it locally as `.local/credentials/001/cloudflare-dns-api-token`, with
mode 0600 in the private credentials directory. This is a DNS API token,
separate from the Cloudflared tunnel token.

Supply the Secret before requesting certificates. The following command writes
to the cluster; run it after saving your real token locally:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cert-manager create secret generic cloudflare-api-token-secret --from-file=api-token=.local/credentials/001/cloudflare-dns-api-token
```

The Secret is managed separately from Argo CD. If it already exists, update it
through your credential workflow instead of running the create command again.
Issuer readiness confirms ACME account registration; a successful Certificate
request is needed to verify Cloudflare permissions and DNS validation.

Alternatively, use the [Sealed Secrets workflow](../../sealed-secrets/README.md)
to manage the DNS token as ciphertext in Git. Keep the same Secret name and
key, and explicitly transfer ownership if the manually created Secret exists.

After committing and pushing the extra Git source and issuer manifest, check:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get clusterissuer letsencrypt-prod
```

Workload Certificates select this issuer with:

```yaml
spec:
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io
```

For automatic certificate creation from a Traefik Ingress, add annotation
`cert-manager.io/cluster-issuer: letsencrypt-prod` and configure `spec.tls`
with the actual hostname and desired TLS Secret name. Certificate Secrets
are created in the workload namespace.

See the official [Cloudflare solver guide](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
and [ACME configuration](https://cert-manager.io/docs/configuration/acme/).
