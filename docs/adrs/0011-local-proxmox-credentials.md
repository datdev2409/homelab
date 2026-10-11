# ADR 0011: Store Proxmox credentials in a private local environment file

- **Status:** Accepted
- **Date:** 2026-10-11

## Context

The user selects a simple local credential file for the initial homelab.
Terragrunt root configuration already reads the Proxmox API token from the
environment. Plaintext secrets must be excluded from Git.

## Decision

Store the API token in `.local/credentials/proxmox.env` as an exported
`PROXMOX_VE_API_TOKEN` variable. Keep the credential directory private (0700)
and the file readable/writable only by its owner (0600).

Commit only a blank template at `docs/examples/proxmox.env.example`. Preserve
an existing credential file when setting up the repository. The actual token
must be supplied locally by the user, not committed or printed by automation.

Load the trusted local shell file into the command environment with
`scripts/with-proxmox-credentials.sh`, or source it manually in a subshell.
The wrapper rejects a missing file or empty token before executing commands.
`infrastructure/root.hcl` continues reading credentials from the environment;
it does not parse shell files or write tokens into generated provider files.

## Consequences

- No password manager or additional secret-management tool is required.
- The file is plaintext, protected by local permissions and Git exclusions.
  Back up the credential separately from disposable VMs and excluded files.
- Sourcing the file executes shell code; keep it locally controlled.
- Runtime credentials and rendered configuration still require care; marking
  OpenTofu variables sensitive does not encrypt files or state.
- Password-manager injection remains a future alternative using the same
  environment-variable interface.
- The credential loader does not provision resources by itself.
