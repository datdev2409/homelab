# Agent navigation

Read the relevant files below before working on a component. Keep this file a
short index; put detailed instructions in `.rules/` or operational guides.

| Task | Read |
| --- | --- |
| Repository layout and implementation status | [README](README.md) |
| General working conventions | [Repository rules](.rules/repository-work.md) |
| Architecture decisions and resource limits | [ADRs](docs/adrs/) |
| OpenTofu or Terragrunt edits | [Formatting rules](.rules/opentofu-terragrunt-formatting.md) |
| Validation and reporting | [Validation rules](.rules/validation.md) |
| Credentials, SSH keys, or direnv | [Credentials guide](docs/guides/credentials.md) |
| VM provisioning, images, or inventory | [base-env README](infrastructure/root_modules/base-env/README.md) |
| Argo CD bootstrap | [cluster-bootstrap README](infrastructure/root_modules/cluster-bootstrap/README.md) |
| Bootstrap and Ansible workflow | [Bootstrap guide](docs/guides/bootstrap.md) |
| Teardown | [Teardown guide](docs/guides/teardown.md) |
| Available commands | [Makefile](Makefile) |

Cluster inputs live in `infrastructure/clusters/<id>/`; Ansible code is under
`ansible/`; GitOps definitions are under `apps/`.
