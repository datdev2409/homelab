# Credentials with direnv

Global and cluster-specific dotenv files live outside Git:

```text
.local/credentials/
├── .env              # Global: Proxmox token and shared credentials
├── node_private_key.pem  # Shared VM SSH private key
├── node_public_key.pub   # Shared VM SSH public key
├── 001/.env          # Cluster 001 overrides and additional secrets
└── 002/.env          # Reserved secrets for future cluster 002
```

The account-wide [Cloudflare unit](../../infrastructure/root_modules/cloudflare/README.md)
uses global `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` assignments in
`.local/credentials/.env`. The API provider reads the token from the environment;
do not put it in HCL or command arguments. Keep connector tunnel tokens separate
from this account API token. Cloudflare Make targets load the repository's global
environment and do not select a Kubernetes cluster credential scope.

Use dotenv assignments, such as `PROXMOX_VE_API_TOKEN='user@realm!name=secret'`.
Global values load first; cluster values override matching variables. Leaving a
variable unset in the cluster file retains its global value. Empty assignments
override a global value with an empty value, so leave unused settings commented.

## One-time setup

Install direnv, then add this hook to your zsh configuration and reload the shell:

```sh
eval "$(direnv hook zsh)"
```

Review the committed `.envrc` files and allow them locally:

```sh
direnv allow .
direnv allow infrastructure/clusters/001
```

direnv requires this local trust step before executing `.envrc`; repeat it after
changing those files. The repository does not alter your shell configuration or
automatically approve environment files.

Fill in `.local/credentials/.env` locally. Directory permissions should be 0700
and credential files 0600. Committed blank templates are in `docs/examples/`.
The previous `proxmox.env` file is renamed to the global `.env` when the new file
does not already exist. Existing destination files are never overwritten.

## Behavior

- At repository root, direnv loads global credentials and the default OpenTofu
  engine selection. It reads `.local/credentials/node_public_key.pub` if no key
  is supplied. Ansible uses `.local/credentials/node_private_key.pem` when run
  from `ansible/`, as documented in the base-env README. Both keys are excluded
  from Git; the private key remains owner-readable only.
- Under `infrastructure/clusters/001/`, it loads global values and then `001/.env`.
- Leaving a directory unloads its environment changes through direnv's shell hook.
- `make plan-base-env CLUSTER=001` and `make apply-base-env CLUSTER=001` explicitly
  use `direnv exec`, so selection follows CLUSTER even when Make runs at root.
  They require a non-empty token; apply retains interactive confirmation.

Changes to the dotenv files are watched for reload. Avoid printing the environment
or rendering Terragrunt configuration into committed files containing credentials.
The local files are plaintext and require a separate protected backup.

For encrypted GitOps credential manifests, see the
[Sealed Secrets guide](../../apps/sealed-secrets/README.md). Keep original
credentials and private sealing-key backups in protected storage outside Git;
the controller's public certificate is used to generate committed ciphertext.

For a future cluster, add its committed `.envrc` with the same global-first pattern,
change the cluster ID/path, and allow it locally. The reserved `002` credential
folder does not provision or configure a Talos cluster.

See [direnv standard library](https://direnv.net/man/direnv-stdlib.1.html) and
[direnv commands](https://direnv.net/man/direnv.1.html).
