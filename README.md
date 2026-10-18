# Kubernetes homelab

Single-host Proxmox lab with disposable Kubernetes VMs. Architecture decisions
are recorded in [docs/adrs](docs/adrs).

## Layout

| Directory | Responsibility |
| --- | --- |
| `apps/roots/<id>` | Root GitOps entry point containing child Applications |
| `apps/<app>` | Reusable manifests and cluster overlays |
| `ansible/playbooks`, `ansible/roles` | Ubuntu and Kubernetes configuration |
| `ansible/inventory/<id>` | Non-secret generated inventory and cluster variables |
| `infrastructure/root_modules` | Reusable OpenTofu configurations |
| `infrastructure/cloudflare` | Account-wide Cloudflare inputs and independent Terragrunt unit |
| `infrastructure/clusters/<id>` | Terragrunt configuration per cluster and stage |
| `scripts/` | Ordered lifecycle orchestration |
| `.local/config/<id>/kubeconfig.yaml` | Ignored per-cluster kubeconfig |

Cluster `001` targets a single Ubuntu 24.04 VM running k3s (server and worker). Talos cluster `002` is reserved
for a later implementation. Only three VMs should run at a time.

State mirrors each Terragrunt unit under `.local/states/`, for example
`.local/states/001/base-env/terraform.tfstate`.

## Workflow

```text
base-env (writes inventory) → Ansible → fetch kubeconfig
         → cluster-bootstrap → Argo CD → GitOps applications
```

See [bootstrap](docs/guides/bootstrap.md) and [teardown](docs/guides/teardown.md).
`make bootstrap CLUSTER=001` and `make teardown CLUSTER=001` are the intended
entry points. They currently stop before modifying resources: full lifecycle
orchestration has not been implemented.

## Implementation status

The reusable `root_modules/base-env` is implemented and cluster 001 state is
located under `.local/states/001/base-env/terraform.tfstate`. The legacy
root-level OpenTofu configuration has been removed after the user migrated state;
its local state and variable files are archived under `.local/archives/`.

`root_modules/cluster-bootstrap` installs Argo CD with Helm. Run
`make plan-cluster-bootstrap CLUSTER=001` and `make apply-cluster-bootstrap
CLUSTER=001` after Ansible and kubeconfig retrieval. The kubectl provider manages
the root Application; private Git access credentials must be configured separately.
Child Applications include [Cloudflared](apps/cloudflared/README.md) and
[cert-manager](apps/cert-manager/README.md), plus
[Traefik](apps/traefik/README.md) ingress and
[Sealed Secrets](apps/sealed-secrets/README.md) for encrypted GitOps credentials,
and [External Secrets Operator](apps/external-secrets/README.md) for external
secret synchronization using AWS Systems Manager Parameter Store and OIDC (AWS trust setup
remains separate);
monitoring remains a placeholder. [MetalLB](apps/metallb/README.md) provides
Layer 2 LAN LoadBalancer support using `192.168.1.30–192.168.1.50`. See the
[bootstrap module](infrastructure/root_modules/cluster-bootstrap/README.md).
Ansible playbooks live only in `ansible/playbooks/` and import task files
from `ansible/tasks/`.
The standalone Ubuntu LXC connector has a separate
[Ansible playbook](docs/guides/cloudflared-lxc.md), run with
`make setup-cloudflared CLUSTER=001` after provisioning and starting its guest.
Run `make setup-k3s CLUSTER=001` after VM provisioning to install k3s and
fetch its kubeconfig. Full bootstrap and teardown scripts remain guarded until implemented.

## Credentials

The [Cloudflare module](infrastructure/root_modules/cloudflare/README.md) supports
the `datnguyen.me` zone, Zero Trust settings, and HTTP/private-network tunnels in
one account-level state at `.local/states/cloudflare/terraform.tfstate`.
Its account resources have not been imported or deployed. Inventory and adopt
existing resources before using `make plan-cloudflare` / `make apply-cloudflare`.
It is independent of cluster lifecycle; connector provisioning remains separate.

Use direnv to load shared credentials from `.local/credentials/.env` and cluster
secrets from `.local/credentials/<id>/.env`. Cluster values override global ones.
See [credential setup](docs/guides/credentials.md) for installation, the zsh hook,
and one-time `direnv allow` commands. No actual credentials are committed.

After setup, run `make plan-base-env CLUSTER=001` or
`make apply-base-env CLUSTER=001`. These targets select the cluster's environment
through `direnv exec` automatically. Full bootstrap remains a guarded scaffold.

Keep local directories private (0700), credential files private (0600), and
state/backups protected. Commit provider lockfiles and non-secret configuration.
Git exclusions do not remove secrets already tracked in Git.
