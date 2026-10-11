# Working in this repository

- Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
  for commit messages: `<type>[optional scope]: <description>`.
- Read the relevant ADRs and component README before changing architecture.
  Record accepted decisions in numbered Markdown ADRs and link amendments or
  superseded decisions. Keep implementation and operational guides consistent.
- Keep one owner per resource: OpenTofu for VMs and Argo CD bootstrap, Ansible
  for OS/kubeadm/Flannel, and Argo CD for child Applications and workloads.
- Preserve user changes and migrated state. Do not reintroduce the removed legacy
  stack or create a second state owner for the same VMs. Keep existing migration
  blocks and temporary storage settings unless the task involves changing them.
- Keep modules reusable: cluster-specific inputs belong in cluster configuration.
  File destinations must be explicit absolute paths, not relative to execution caches.
- Never commit, print, or unnecessarily inspect secrets, private keys, kubeconfigs,
  state, or saved plans. Preserve existing credential files when preparing templates.
  Follow the credential guide for scopes, paths, permissions, and direnv behavior.
- Commit provider lockfiles. Edit configuration sources rather than generated
  caches, backend files, or import files. Leave archives and active state untouched
  unless the task authorizes state work.
- Code edits do not imply live deployment. Apply, destroy, Kubernetes writes, and
  state changes require authorization within the user's task. Do not add automatic
  approval flags as a shortcut; review plans for unexpected replacement/deletion.
- Check current implementation status in README and guides. Do not claim guarded
  bootstrap/teardown scripts or placeholder components are functional.
- Respect the hardware/resource ADRs, including the three-running-VM limit.
- Follow the formatting and validation rules linked from AGENTS.md.
