# base-env

Reusable Proxmox provisioning for a shared cloud image or installer ISO and a
map of VMs, plus optional LXC system containers and OCI application containers.
Talos-specific machine configuration remains future work.

## Configuration

Edit `infrastructure/clusters/001/cluster.hcl`:

- `image`: mode, HTTPS URL or absolute local path, filename, datastore, optional checksum
  and algorithm. For repeatable builds, use a dated URL and checksum.
- `vms`: stable inventory names mapped to role, VM ID, CPU cores, memory MiB,
  disk GiB, and IPv4/CIDR. Optional fields: `started`, `on_boot`,
  `guest_agent_enabled`, and `disk_storage` override.
- `lxc_templates`, `oci_images`, and `containers`: system rootfs templates, OCI
  images, and LXC guests, described below.
- Host, storage, network, name prefix, and cloud-init username are configurable.

VM startup is enabled by default; containers default to stopped. Use `started = false` and `on_boot = false` for
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

## Ubuntu LXC system containers

Use `lxc_templates` for a full Ubuntu userspace with systemd and package management.
Set `source = "template"` on a container and reference a template through `image_key`.
Use a Proxmox LXC template rather than a generic cloud-image rootfs: device nodes
in generic archives can fail extraction with `Cannot mknod: Operation not permitted`
when creating an unprivileged container. The template is downloaded to storage
supporting `vztmpl`, using HTTPS with an optional checksum/algorithm pair, or HTTP
with a required checksum/algorithm pair. Supported archive extensions are `.tar.xz`,
`.tar.gz`, and `.tar.zst`; `os_type` defaults to `ubuntu`.

Cluster 001 now configures `cloudflared` as an Ubuntu 24.04 system container:

| Setting | Value |
| --- | --- |
| CT ID / hostname | `204` / `k8s-homelab-cloudflared` |
| IPv4 / gateway | `192.168.1.204/24` / `192.168.1.1` |
| CPU / RAM / disk | 1 core / 512 MiB / 8 GiB |
| Template / root disk storage | `HDD-Storage` / `local-lvm` |
| Initial state | Stopped, host-boot startup disabled |

Its Proxmox Ubuntu LXC template is pinned to `24.04-2` with the SHA512 checksum
from the Proxmox appliance catalog. The published download uses HTTP; the pinned
checksum verifies the downloaded archive. The Proxmox node must reach the download URL, and `HDD-Storage`
must accept container templates. Verify that ID 204 and the address are available
before applying; repository checks cannot establish live availability. Existing
VMs and their media settings remain unchanged.

System containers are unprivileged with nesting enabled for modern systemd.
Proxmox initializes hostname, DNS, static networking, and the shared public SSH
key for **root**. `cloud_init_user` applies to VMs, not LXC; the module does not
create an `ubuntu` user in system containers. `entrypoint` and
`environment_variables` are reserved for OCI guests. Replacing a source/template
can replace the container; inspect the plan before changing it.

System containers appear in inventory under `system_containers` with
`ansible_user: root`. Kubernetes preparation targets only `control_plane:workers`.
After provisioning and starting the container, verify SSH and Python availability;
if the selected rootfs lacks either, install `openssh-server` and `python3` through
the Proxmox console or `pct exec`, and enable the SSH service. Template initialization
is not cloud-init and does not install application packages.

This provisions the Ubuntu host only. Run `make setup-cloudflared CLUSTER=001`
after starting it to install the connector and its systemd service through the
[standalone Ansible playbook](../../../docs/guides/cloudflared-lxc.md). No Cloudflare credentials or tunnel tokens are passed through these
inputs, and the existing Kubernetes HTTP connector is unchanged. Reserve host
capacity before enabling `started`/`on_boot`; the three Kubernetes VMs already
allocate 13 GiB of RAM.

## OCI-backed LXC application containers

Requires Proxmox VE 9.1+ with OCI registry pull support and host-managed container
networking. Application containers are a Proxmox technology preview. The pinned
`bpg/proxmox` 0.115.0 provider supplies `proxmox_oci_image`; no provider upgrade is
needed. See [Proxmox OCI documentation](https://pve.proxmox.com/pve-docs/chapter-pct.html#_open_container_initiative_oci_images)
and the [pinned image resource schema](https://github.com/bpg/terraform-provider-proxmox/blob/v0.115.0/docs/resources/oci_image.md).

Add these inputs to a cluster's `base_env` configuration or pass them directly to
the module. Existing VM inputs and resource addresses remain compatible. For an
LXC-only deployment, omit `image` and `vms` (or set `image = null`, `vms = {}`).
At least one VM or container is required; `inventory_path` remains required and
a deployment containing only OCI application containers writes an empty host inventory.

```hcl
oci_images = {
  nginx = {
    reference    = "docker.io/library/nginx:1.28-alpine"
    datastore_id = "HDD-Storage"
    file_name    = "nginx-1.28-alpine.tar"
  }
}

containers = {
  web = {
    vm_id     = 200
    image_key = "nginx"
    cores     = 1
    memory_mb = 256
    disk_gb   = 2
    ip_addr   = "192.168.1.20/24"
    # Enable only after reviewing the host's available RAM and CPU budget.
    started = false
    on_boot = false
  }
}
```

The node pulls images from the registry into template storage (`vztmpl` content
must be enabled). It needs registry access and an image matching the host CPU
architecture. Multiple containers can share an image key. Prefer immutable image
digests for reproducibility; changing a registry tag alone is not a reliable
redeployment mechanism. Existing unmanaged template files are never overwritten.

Each container is unprivileged with OS type `unmanaged`, a root disk on
`vm_disk_storage` (or its `disk_storage` override), and an `eth0` interface on
`network_bridge`. The shared gateway and DNS apply. Host-managed networking lets
Proxmox configure networking for images without a DHCP client or init system.
The image's startup command is used unless you supply `entrypoint`; optional
`environment_variables` configures runtime environment values. Include all
required runtime values when overriding the image's environment. Do not commit
credentials in these maps; runtime values can be retained in state.

Containers default to stopped and do not start on host boot. Budget their RAM,
CPU, and SSD space alongside the existing 13 GiB VM allocation before enabling
them; OCI support does not expand the host capacity or the three-running-VM
limit. Cluster 001 uses a system-template container, not an OCI application image.

IDs, names, and IPv4 addresses must be unique across both guest maps within a
module instance. Also check availability across other states and existing guests
before applying. The module cannot detect conflicts with unmanaged resources.
Changing image/template settings can replace a container; always review the plan.

Application images need not provide SSH, Python, systemd, or a shell. They are
excluded from the Kubernetes Ansible inventory and receive no cloud-init user
or SSH key. Image build and application configuration remain separate work;
this capability does not run the kubeadm playbooks inside LXC containers.

Run offline regression checks with mocked providers:

```sh
cd infrastructure/root_modules/base-env
tofu test
```

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
- `image_id`: uploaded or downloaded VM source media ID; null for LXC-only deployments.
- `containers`: LXC IDs, image keys, and desired addresses.
- `oci_image_ids`: OCI template volume IDs keyed by image name.
- `lxc_template_ids`: downloaded system-template volume IDs keyed by template name.
- `ansible_inventory`: inventory object including all hosts and Kubernetes groups.
- `inventory_file`: absolute path to the managed inventory file.
- `public_key`: configured public key, for compatibility.

OpenTofu writes YAML inventory automatically during apply, after VM and LXC provisioning,
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
