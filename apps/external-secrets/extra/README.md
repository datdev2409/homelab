# AWS Systems Manager Parameter Store

The External Secrets Application deploys Kubernetes manifests from this
directory, including subdirectories, alongside the Helm chart.

`cluster-secret-store.yaml` defines ClusterSecretStore `aws-parameterstore`
for AWS Systems Manager Parameter Store in `ap-southeast-1`. It uses JWT/OIDC
authentication through service account `external-secrets/aws-secretsmanager`, defined in
`service-account.yaml` and annotated with IAM role
`arn:aws:iam::803537989070:role/homelab-secrets-reader`.

ESO requests short-lived service account tokens with audience
`sts.amazonaws.com` and exchanges them through `sts:AssumeRoleWithWebIdentity`.
The store leaves `serviceAccountRef.audiences` unset because ESO supplies
`sts.amazonaws.com` by default. Adding it there appends a duplicate audience
in ESO v2.12.0, causing AWS STS to reject the token for multiple audiences
without an authorized-party claim.
The `eks.amazonaws.com/role-arn` annotation is read by ESO even on this kubeadm
cluster; this store-specific flow does not require a pod identity webhook.
The store omits `aws.role`, which would trigger an additional `sts:AssumeRole`
after OIDC authentication. The dedicated service account is separate from the
operator's Helm-managed service account. Chart RBAC allows the operator to
read service accounts and create tokens through the TokenRequest API.

The service account syncs in default wave `0`, and the store uses wave `1`
so Argo CD waits for the operator and webhook deployments first.

## OIDC prerequisites

These manifests configure the ESO side. This repository does not currently
configure or publish a public Kubernetes service account OIDC issuer or manage
the AWS IAM OIDC provider and role trust. Authentication will fail until those
prerequisites are supplied:

1. Kubernetes service account tokens must use an HTTPS issuer whose discovery
   document and JWKS endpoints AWS can retrieve. The published signing keys
   must match the keys used by this cluster.
2. Register that issuer in AWS account `803537989070` as an IAM OIDC provider
   with audience `sts.amazonaws.com`.
3. Configure `homelab-secrets-reader` to trust that provider for
   `sts:AssumeRoleWithWebIdentity`, restricted with `StringEquals` conditions
   for audience `sts.amazonaws.com` and subject
   `system:serviceaccount:external-secrets:aws-secretsmanager`.
4. Give the role `ssm:GetParameter` access to
   `arn:aws:ssm:ap-southeast-1:803537989070:parameter/homelab/cloudflared-tunnel-token`.
   For a `SecureString` encrypted with a customer-managed key, it may also need
   `kms:Decrypt` scoped to that key.

The exact provider ARN and trust condition keys depend on the cluster's issuer
URL. Use the issuer host and path without `https://` for the condition key
prefix. The issuer must match the Kubernetes service account tokens.

This ClusterSecretStore can be referenced from any workload namespace.
Control who can create ExternalSecrets and scope the role's IAM permissions
accordingly. Existing Sealed Secrets resources retain their current owner.

## Consumers and readiness

The Cloudflared application has its ExternalSecret in its own
`apps/cloudflared/extra/` source. It selects this store with:

```yaml
spec:
  secretStoreRef:
    name: aws-parameterstore
    kind: ClusterSecretStore
```

After reconciliation and AWS trust setup, check readiness without printing
credentials or secret values:

```sh
kubectl --kubeconfig .local/config/001/kubeconfig.yaml get clustersecretstore aws-parameterstore
kubectl --kubeconfig .local/config/001/kubeconfig.yaml wait --for=condition=Ready clustersecretstore/aws-parameterstore --timeout=120s
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cloudflare get externalsecret cloudflared-tunnel-token
kubectl --kubeconfig .local/config/001/kubeconfig.yaml -n cloudflare wait --for=condition=Ready externalsecret/cloudflared-tunnel-token --timeout=120s
```

Store readiness verifies provider initialization; a successful ExternalSecret
reconciliation is still needed to verify access to a specific secret.

## Sources

- [ESO AWS authentication](https://external-secrets.io/latest/provider/aws-access/)
- [AWS Parameter Store](https://external-secrets.io/latest/provider/aws-parameter-store/)
- [Extract structured data](https://external-secrets.io/latest/guides/all-keys-one-secret/)
- [AWS IAM OIDC provider requirements](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [AWS OIDC role trust](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html)
