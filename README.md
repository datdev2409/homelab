# Kubernetes homelab

Single-host Proxmox lab with disposable Kubernetes VMs. Architecture decisions
are recorded in [docs/adrs](docs/adrs).

## Layout

| Directory | Responsibility |
| --- | --- |
| `apps/roots/<id>` | Root GitOps entry point containing child Applications |
| `apps/<app>` | Reusable manifests and cluster overlays |
| `ansible/playbooks`, `ansible/roles` | Ubuntu and kubeadm configuration |
| `ansible/inventory/<id>` | Non-secret generated inventory and cluster variables |
| `infrastructure/root_modules` | Reusable OpenTofu configurations |
| `infrastructure/clusters/<id>` | Terragrunt configuration per cluster and stage |
| `scripts/` | Ordered lifecycle orchestration |
| `.local/clusters/<id>` | Ignored kubeconfig and local artifacts |

Cluster `001` targets Ubuntu 24.04 and kubeadm. Talos cluster `002` is reserved
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
entry points. They currently stop before modifying resources: Argo CD bootstrap
and full lifecycle orchestration have not been implemented.

## Implementation status

The reusable `root_modules/base-env` is implemented and cluster 001 state is
located under `.local/states/001/base-env/terraform.tfstate`. The legacy
root-level OpenTofu configuration has been removed after the user migrated state;
its local state and variable files are archived under `.local/archives/`.

`root_modules/cluster-bootstrap` remains a documented placeholder. Ansible task
files remain in their original locations; the new playbooks import them.
Full bootstrap and teardown scripts remain guarded until implemented.

## Credentials

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
