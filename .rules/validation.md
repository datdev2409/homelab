# Validation and reporting

- Run checks relevant to changed files without contacting the live lab unless
  needed and authorized. Formatting and syntax checks are the starting point.
- OpenTofu: `tofu fmt -check infrastructure/root_modules/base-env`; initialize
  and validate the affected module when its provider binaries can run.
- Terragrunt: `make fmt-terragrunt`; use `terragrunt hcl fmt --check` from
  `infrastructure/` to check without rewriting, excluding generated caches.
- Ansible: run `ansible-playbook --syntax-check playbooks/site.yml` and the
  corresponding kubeconfig playbook from `ansible/` when changed. For generated
  inventory changes, check host groups and addresses with `ansible-inventory`.
- Shell: `bash -n` on changed scripts and `.envrc` files; Make: dry-run changed
  targets with `make -n` before any live operation.
- Cached provider binaries have previously failed to start in the restricted
  agent environment. Report that validation limitation accurately; isolated
  HCL or inventory checks do not substitute for a full provider-backed plan.
- Do not change machine permissions or reinstall tools to bypass an environment
  failure during routine validation.
- Report what changed, what was verified, remaining implementation gaps, and
  whether live resources or state were modified. Never claim a deployment
  succeeded based only on syntax checks or a Make dry-run.
