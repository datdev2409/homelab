# Cloudflare

One OpenTofu root module owns the selected Cloudflare resources for an account.
The account-level Terragrunt unit is `infrastructure/cloudflare/`; it is independent
of Kubernetes cluster lifecycle. Non-secret inputs live in that unit's
`cloudflare.hcl`. The zone is currently `datnguyen.me`.

| File | Ownership |
| --- | --- |
| `zone.tf` | Domain zone, explicit zone settings, DNS records including tunnel CNAMEs |
| `zero-trust.tf` | Optional existing Zero Trust organization and WARP default profile |
| `tunnels.tf` | Remotely managed HTTP/private tunnels, complete ingress configs, private CIDR routes |

The provider is pinned to `cloudflare/cloudflare` **5.27.0**. The module and
Terragrunt unit commit provider lockfiles. The backend is an absolute local path:
`.local/states/cloudflare/terraform.tfstate`. Protect this directory and its backups
as described in the [credentials guide](../../../docs/guides/credentials.md).

## Current scope

This creates configuration, not a deployment or an account inventory. The live
account has not been inspected, and no resources have been imported. Committed
inputs select only the existing zone. The other maps are empty and optional
organization/profile objects are null until their settings are inventoried.
`infrastructure/cloudflare/cloudflare.hcl.example` illustrates HTTP and VPN
tunnels; replace example settings with actual values rather than applying it
unchanged. Stable map keys become state addresses; keep them unchanged after import.

The zone resource manages DNS hosting, not domain registration, purchasing,
transfer, or renewal. Registrar ownership, Access applications/policies, identity
providers, Gateway policies, and additional Cloudflare services are outside this
initial module. Add their resources to these files when their actual configuration
is known; do not create a second state owner for them.

Cloudflare owns tunnel control-plane configuration. Argo CD continues owning the
existing Kubernetes `cloudflared` workload and its Secret reference. Proxmox LXC
provisioning and Ansible installation of the private connector are separate work.
This module neither installs connectors nor reads, rotates, or outputs tunnel
tokens. Keep the existing HTTP tunnel token and its SSM/ESO delivery intact.

## Credentials and initialization

Add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` to the existing private
`.local/credentials/.env`; preserve other credentials. The provider consumes the
API token directly from the environment. The Terragrunt unit reads the account ID.
Do not place either a connector token or API token in HCL or command arguments.

Use an API token scoped to the intended account and `datnguyen.me`, with only the
permissions needed for the resources you enable:

- Zone Read/Write for zone adoption/management; DNS Read/Write for records.
- Zone Settings Read/Write for explicit zone settings.
- Access: Organizations, Identity Providers, and Groups Read/Write for the organization.
- Cloudflare Tunnel Read/Write (or the equivalent Cloudflare One connector permissions)
  for tunnels, ingress configuration, and routes.
- Zero Trust Write for the optional WARP default profile.

From the repository root, after the existing root `.envrc` has been approved:

```sh
mkdir -p .local/states/cloudflare
chmod 700 .local .local/states .local/states/cloudflare
cd infrastructure/cloudflare
direnv exec ../.. terragrunt init
```

These commands use the account-level state, without accessing cluster state.
Do not use `infrastructure/clusters/root.hcl` for this unit: its relative state
path logic is scoped to cluster units.

## Adopt existing resources

First inventory the account ID, zone ID, exact organization name/team domain,
tunnel IDs/names, complete ingress rules (including origin options), DNS record
IDs, route IDs, and the existing default profile if you intend to manage it.
Inspect those configurations through the dashboard or a suitable authenticated
read-only API tool; do not export tunnel tokens or credentials into Git.

Populate `cloudflare.hcl` to match each resource before importing it. Add a tunnel
to `tunnels` before referencing its key in `dns_records`, `tunnel_configurations`,
or `private_routes`. Omit a tunnel from `tunnel_configurations` until its complete
configuration is known. Managing this resource replaces the complete ingress
configuration; partial lists can remove working hostname routes.

From `infrastructure/cloudflare/`, the import patterns are:

```sh
direnv exec ../.. terragrunt import cloudflare_zone.this '<zone-id>'
direnv exec ../.. terragrunt import 'cloudflare_zone_setting.this["ssl"]' '<zone-id>/ssl'
direnv exec ../.. terragrunt import 'cloudflare_dns_record.this["app"]' '<zone-id>/<record-id>'
direnv exec ../.. terragrunt import 'cloudflare_zero_trust_organization.this[0]' '<account-id>'
direnv exec ../.. terragrunt import 'cloudflare_zero_trust_device_default_profile.this[0]' '<account-id>'
direnv exec ../.. terragrunt import 'cloudflare_zero_trust_tunnel_cloudflared.this["http"]' '<account-id>/<tunnel-id>'
direnv exec ../.. terragrunt import 'cloudflare_zero_trust_tunnel_cloudflared_config.this["http"]' '<account-id>/<tunnel-id>'
direnv exec ../.. terragrunt import 'cloudflare_zero_trust_tunnel_cloudflared_route.this["home"]' '<account-id>/<route-id>'
```

Run only the imports for resources present in both your inputs and account.
Imports write local state but do not deploy connectors. Provider **5.27.0** supports
organization import by account ID, despite older registry documentation describing
it as unsupported. Enable `zero_trust` with the existing organization values first.
Complete onboarding/subscription setup in the dashboard if the account has no Zero
Trust organization yet; this module does not subscribe the account to a plan.

Then inspect a plan:

```sh
make plan-cloudflare  # From the repository root
```

For adoption, resolve any unexpected changes, replacements, or deletions before
applying. Unlisted existing DNS records and unrelated dashboard resources remain
unmanaged; this module does not discover and prune them automatically. Zone,
organization, and tunnel resources use `prevent_destroy`; removal of that
protection must be an intentional code change before deleting them.

`make apply-cloudflare` is a separate, interactive live operation. Creating code
or importing state is not authorization to deploy. Keep domain/account resources
out of cluster bootstrap and teardown commands.

## Automatic ingress DNS

Set `add_zone_dns = true` on a rule in `tunnels.<key>.ingress` to manage a
proxied CNAME for its hostname in `zone_name`. The record targets that tunnel's
`<tunnel-id>.cfargotunnel.com` address and uses automatic TTL (`1`). The flag
defaults to `false`; catch-all rules do not need it. It is a module option and
is omitted from the ingress configuration sent to Cloudflare.

```hcl
tunnels = {
  http = {
    name = "homelab-http"
    ingress = [
      {
        hostname     = "app.datnguyen.me"
        service      = "http://traefik.traefik.svc.cluster.local:80"
        add_zone_dns = true
      },
      { service = "http_status:404" }
    ]
  }
}
```

Each enabled hostname must belong to the managed zone and appear only once.
Do not also declare that hostname in `dns_records`. If its DNS record already
exists, import it before applying, for example:

```sh
direnv exec ../.. terragrunt import 'cloudflare_dns_record.tunnel_ingress["app.datnguyen.me"]' '<zone-id>/<record-id>'
```

Turning the flag off or removing its ingress rule removes the managed DNS record
on the next apply. DNS creation requires a separate plan/apply like other resources.

## WARP/private-network access

The VPN tunnel needs a running connector with LAN reachability, a private CIDR
route, enrolled WARP clients, and a client profile that sends the private CIDR
through WARP. The home LAN currently uses `192.168.1.0/24`; overlapping networks
on remote devices can prevent access.

The optional `warp_profile` manages the account's default profile. Provide exactly
one complete `include` or `exclude` list, with exactly one `address` or `host` per
entry. These lists replace existing lists. For Include mode, preserve Cloudflare's
required Zero Trust destinations as well as your private CIDR; do not include only
the home subnet and assume enrollment/authentication will work. Custom profiles
may override the default and are not yet managed here. Leaving `warp_profile = null`
preserves existing dashboard ownership.

Private routes do not themselves restrict users. Existing enrollment permissions
and Gateway network policies must be reviewed before use; they are not created by
this module. Likewise, HTTP tunnel routes require suitable Access policies before
publishing private dashboards. The example HTTP route is illustrative, not an
approved exposure configuration.

## Validation

```sh
tofu fmt -check infrastructure/root_modules/cloudflare
cd infrastructure/root_modules/cloudflare
tofu init -backend=false
tofu validate
tofu test
```

Check Terragrunt formatting with the repository's `make fmt-terragrunt` target.
Initialization downloads the pinned provider; validation does not contact the
account. No plan can verify the intended adoption without real account inputs and
the existing resources imported into the account-level state.

## References

- [Pinned provider documentation](https://github.com/cloudflare/terraform-provider-cloudflare/tree/v5.27.0/docs/resources)
- [Organization import](https://github.com/cloudflare/terraform-provider-cloudflare/blob/v5.27.0/docs/resources/zero_trust_organization.md#import)
- [Cloudflare Tunnel with Terraform](https://developers.cloudflare.com/tunnel/guides/terraform/)
- [Private CIDR routes and WARP setup](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/private-net/cloudflared/connect-cidr/)
- [ADR 0019](../../../docs/adrs/0019-cloudflare-account-resources-with-opentofu.md)
