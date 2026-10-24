# ADR 0025: Authentik identity provider through Argo CD

- **Status:** Accepted
- **Date:** 2026-10-24

## Decision

Install Authentik on cluster 001 through its official Helm chart, pinned to
2026.8.5, as an Argo CD child Application in namespace `authentik`. Use one
server, one worker, and the chart's bundled PostgreSQL 17 database for this
single-node homelab. Combined requests are 300m CPU and 1280 MiB memory;
combined memory limits are 2560 MiB. No additional VM is needed.

Use SSD-backed `local-path` volumes: 8 GiB for PostgreSQL and 1 GiB shared
between the server and worker at `/data`. The shared ReadWriteOnce volume is
appropriate only while both pods run on the same node. Retain the data PVC
during Argo CD pruning/deletion. The PostgreSQL StatefulSet retains its PVC
on deletion by default. Namespace deletion still destroys these volumes.

Expose `auth.datnguyen.me` through Traefik, with a cert-manager certificate
for HTTPS on the `websecure` entrypoint. Cloudflare Tunnel must also use an
HTTPS origin with TLS server name `auth.datnguyen.me` and certificate validation
enabled. DNS and tunnel published hostnames are configured separately.

Sealed Secrets owns the configuration and database credentials. Generate a
random initial `akadmin` password before exposing the application. Keep the
plaintext originals in protected ignored cluster credential files. Do not
change the Authentik secret key after initialization or regenerate database
credentials without coordinating the existing database password.

Use the embedded outpost initially. Disable managed-outpost Kubernetes RBAC
and service account token mounts; add access only when configuring managed
outposts explicitly. Existing application authentication is unchanged.

## Consequences

This is a single-node installation without database failover. The bundled
database is intended for test environments; migrate to a separately managed
database before production use. Back up PostgreSQL, uploaded files, credentials,
and sealing keys before rebuilding the VM. PVC sizes reserve capacity logically;
monitor actual free space on the shared 100 GiB VM disk. SMTP and application
SSO integrations remain separate configuration tasks.

## References

- [Official Kubernetes installation](https://docs.goauthentik.io/install-config/install/kubernetes/)
- [Automated installation](https://docs.goauthentik.io/install-config/automated-install/)
- [File storage requirements](https://docs.goauthentik.io/customize/files/)
- [Single-node k3s](0022-single-node-k3s.md)
