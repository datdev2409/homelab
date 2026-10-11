# base-env

Reusable Proxmox provisioning for a shared cloud image or installer ISO and a
map of VMs. Talos-specific machine configuration remains future work.

## Configuration

Edit `infrastructure/clusters/001/cluster.hcl`:

- `image`: mode, HTTPS URL or absolute local path, filename, datastore, optional checksum
  and algorithm. For repeatable builds, use a dated URL and checksum.
- `vms`: stable inventory names mapped to role, VM ID, CPU cores, memory MiB,
  disk GiB, and IPv4/CIDR. Optional fields: `started`, `on_boot`,
  `guest_agent_enabled`, and `disk_storage` override.
- Host, storage, network, name prefix, and cloud-init username are configurable.

Default startup is enabled. Use `started = false` and `on_boot = false` for
inactive experiments and respect the lab's three-running-VM limit.
Enable guest-agent support only after installing the agent in the guest.
Source media stays on HDD; active VM disks remain on SSD.

Credentials load through direnv: global `.local/credentials/.env`, followed by
`.local/credentials/<id>/.env`. See [setup guide](../../../docs/guides/credentials.md)
for the shell hook and local approval commands. Root environment configuration
selects OpenTofu and loads the existing public SSH key when available.

`infrastructure/clusters/root.hcl` loads the Proxmox token from `PROXMOX_VE_API_TOKEN`,
falling back to `TF_VAR_virtual_environment_api_token`. The base-env unit
consumes the exposed credential map; cluster-bootstrap does not. No token is
written into generated provider configuration. The module's token variable is
sensitive; state and rendered Terragrunt configuration still require protection.

The same root configuration generates a local backend for every included unit:
`.local/states/<unit-path>/terraform.tfstate`, mirroring the unit's path relative
to `infrastructure/clusters/`. For example:

- `.local/states/001/base-env/terraform.tfstate`
- `.local/states/001/cluster-bootstrap/terraform.tfstate`

These are separate state files outside execution caches and excluded from Git.

## Fresh deployment

The Makefile uses direnv to load global and selected-cluster credentials for
these commands, using OpenTofu by default:

```sh
make plan-base-env CLUSTER=001
make apply-base-env CLUSTER=001
```

No manual credential sourcing is required for these targets. Apply retains its
interactive confirmation. The public key is required for cloud-image mode.

For new clusters, use fresh state and available VM IDs/addresses. Cluster 001
uses state already migrated by the user. Its old root-level configuration has
been removed, with local artifacts archived under `.local/archives/`. Review a
plan against the migrated state and resolve legacy resource addresses before
applying; repository cleanup did not modify active state.

With the shell hook configured and the cluster .envrc approved, run:

```sh
mkdir -p .local/states/001/base-env
chmod 700 .local .local/states .local/states/001 .local/states/001/base-env
cd infrastructure/clusters/001/base-env
terragrunt plan
terragrunt apply
```

## Media modes

Both modes accept exactly one `url` or `local_path`. Use an absolute path for
local uploads because OpenTofu runs inside Terragrunt's cache. The Proxmox
storage must accept `import` for cloud images or `iso` for installers.
The filename describes the actual format; renaming a file does not convert it.

### Cloud image (default)

```hcl
image = {
  mode = "cloud_image"
  url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name = "ubuntu-24.04-cloudimg-amd64.qcow2"
  datastore_id = "HDD-Storage"
}
```

Imports the preinstalled OS into each `scsi0` disk and configures user, key,
network, and DNS with cloud-init. A public SSH key is required. The existing
cluster 001 configuration remains in this mode.

### Local cloud image

```hcl
image = {
  mode = "cloud_image"
  local_path = "/absolute/path/ubuntu-cloud-image.qcow2"
  file_name = "ubuntu-local.qcow2"
  datastore_id = "HDD-Storage"
}
```

### Installer ISO

```hcl
image = {
  mode = "installer_iso"
  local_path = "/absolute/path/ubuntu-server.iso"
  file_name = "ubuntu-server.iso"
  datastore_id = "HDD-Storage"
}
```

For a remote ISO, replace `local_path` with its HTTPS `url`. Installer mode
creates a blank VM disk, attaches the ISO on `ide3`, and boots the CD-ROM first.
It does not attach the cloud-init disk or automatically configure the installed
OS. Perform installation through the Proxmox console or provide an unattended
installation mechanism separately. Configure the OS user, SSH key, address,
gateway, and DNS to match the desired inventory before running Ansible.

After installing a VM, set its `boot_from_installer = false` and optionally
`installer_attached = false` in `vms`, then review and apply the change. These
fields affect only ISO mode. Detaching the installer leaves an empty CD-ROM.
Changing between cloud-image and ISO modes on existing VMs may replace disks
or VMs; inspect the plan and use fresh VMs for a different installation method.

Both sources support optional `checksum` and `checksum_algorithm` together.
Downloads support SHA256/SHA384/SHA512; local uploads require SHA256. Pin dated
artifacts and checksums for reproducibility. Local uploads do not overwrite
existing unmanaged files with the same filename.

## Backend path relocation

Existing cluster 001 state has been moved to
`.local/states/001/base-env/terraform.tfstate`, with a pre-move backup under
`.local/archives/`. Reinitialize the existing unit before planning or applying:

```sh
cd infrastructure/clusters/001/base-env
direnv exec .. terragrunt init -reconfigure
```

This refreshes cached backend configuration; do not migrate the state again.
The shared root now lives at `infrastructure/clusters/root.hcl`.

## Outputs

- `vms`: VM IDs, roles, and addresses.
- `image_id`: uploaded or downloaded source media ID.
- `ansible_inventory`: inventory object including all hosts and Kubernetes groups.
- `inventory_file`: absolute path to the managed inventory file.
- `public_key`: configured public key, for compatibility.

OpenTofu writes YAML inventory automatically during apply, after VM provisioning,
using `local_file.ansible_inventory`. Terragrunt passes the absolute path:
`ansible/inventory/<id>/inventory.yml`. Direct module callers must provide
`inventory_path` explicitly. New parent directories use 0700 permissions and
the inventory file uses 0600. The file contains no credentials, may be committed to Git, and is removed by destroy.

No manual output export is required. The inventory output remains available for
other consumers. Ansible defaults to cluster 001 when run from `ansible/`; select a cluster
explicitly when needed:

```sh
cd ansible
ansible-playbook -i inventory/001/inventory.yml playbooks/site.yml
```

This command uses the existing `ansible.cfg` and shared group variables; load any
future cluster-specific variables explicitly. ISO installation must complete
before Ansible can connect. Full lifecycle orchestration remains pending.
