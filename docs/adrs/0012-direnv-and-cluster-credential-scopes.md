# ADR 0012: Load global and cluster credentials through direnv

- **Status:** Accepted
- **Date:** 2026-10-11
- **Supersedes:** [ADR 0011](0011-local-proxmox-credentials.md) credential filename and shell-loader mechanism

## Decision

Use direnv to load `.local/credentials/.env` globally, followed by
`.local/credentials/<cluster-id>/.env` when working in a cluster directory.
Cluster values override matching global variables. Keep committed `.envrc`
files free of secret values and all actual credentials excluded from Git.

Use a root `.envrc` for global loading and cluster-level `.envrc` files for
overrides. Make provisioning targets use `direnv exec` at the selected cluster
so they load the correct scope even when invoked from the repository root.
Terragrunt continues reading exported credentials through `get_env`.

Keep private directory/file permissions (0700/0600), blank committed examples,
and protected local backups. Replace the previous credential wrapper with
direnv; preserve existing credentials when renaming the global file.

## Consequences

- Requires direnv installation, a shell hook for automatic interactive loading,
  and local approval of each `.envrc`.
- Global credentials are available throughout the repository; cluster-specific
  credentials load only within the selected cluster's environment.
- The `.envrc` files watch dotenv changes. Additional clusters need corresponding
  scoped `.envrc` files when their infrastructure is implemented.
- Cluster `002` has a reserved private credential directory only; Talos
  provisioning remains future work.
- Plaintext credentials remain outside Git; direnv does not encrypt them.
- No live provisioning occurs as part of configuring environment loading.

## References

- [direnv standard library](https://direnv.net/man/direnv-stdlib.1.html)
- [direnv commands](https://direnv.net/man/direnv.1.html)
