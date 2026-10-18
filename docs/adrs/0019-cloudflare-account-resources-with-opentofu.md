# ADR 0019: Manage Cloudflare account resources with OpenTofu

- **Status:** Accepted
- **Date:** 2026-10-18
- **Amends:** [ADR 0009](0009-repository-structure-and-cluster-lifecycle.md) and
  [ADR 0015](0015-cloudflare-tunnel-for-workload-access.md)

## Decision

Use one reusable `infrastructure/root_modules/cloudflare` configuration and one
account-level Terragrunt unit at `infrastructure/cloudflare`. Organize resources
in `zone.tf`, `zero-trust.tf`, and `tunnels.tf`, without child modules. Keep
non-secret account inputs in `infrastructure/cloudflare/cloudflare.hcl`.

Cloudflare resources span clusters and home-network access, so their lifecycle
must be independent of cluster bootstrap/teardown. Use the absolute local backend
`.local/states/cloudflare/terraform.tfstate`, separate from every cluster state.
This unit generates its own backend; cluster-relative backend logic is unchanged.

The initial module supports the `datnguyen.me` zone and explicit DNS/zone settings,
the existing Zero Trust organization, optional WARP default-profile settings,
remotely managed HTTP/private tunnels, ingress configurations, and CIDR routes.
Registrar, Access/enrollment policies, identity providers, and Gateway policies
can be added once their actual configuration is inventoried. They are not
implicitly adopted by this change.

Import existing resources before applying. Preserve existing tunnel names/IDs,
routes, hostname configurations, organization/team domain, and token delivery.
Provider 5.27.0 supports organization import using the account ID. The committed
unit initially selects only the zone; empty maps/null optional settings leave
other resources unmanaged until their inputs are supplied. Use destruction
protection for the zone, organization, and tunnels.

Supply `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` through global direnv
credentials. Do not generate provider credentials or fetch/output connector
tokens. OpenTofu owns the Cloudflare control plane after adoption; Argo CD
continues owning the Kubernetes connector and its existing SSM/ESO Secret delivery.
The private connector's Proxmox LXC and OS configuration remain separate work.

## Consequences

- Dashboard changes to adopted resources must be reconciled into OpenTofu inputs.
- A tunnel configuration owns its complete ingress rule set; inventory it before adoption.
- WARP split-tunnel lists replace the corresponding lists; retain required destinations.
- A private route alone does not authorize users or complete client setup. Review
  enrollment and Gateway policies separately before enabling private access.
- Cloudflare state and credentials require protected local storage and backups.
- Creating this module performs no import, state migration, live deployment, or
  account subscription. Plan/apply remain separate operations.

See the [module guide](../../infrastructure/root_modules/cloudflare/README.md).
