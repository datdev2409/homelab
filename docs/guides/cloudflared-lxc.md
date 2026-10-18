# Bootstrap the standalone Cloudflare connector

`ansible/playbooks/cloudflared.yml` installs the standalone `homelab-warp`
connector on the Ubuntu LXC created by base-env. The Kubernetes HTTP connector
remains managed by Argo CD and uses its own token.

## Prerequisites

- Create/adopt the remotely managed `homelab-warp` tunnel in Cloudflare. Its
  connector token is different from the Cloudflare account API token and the
  Kubernetes HTTP tunnel token.
- Review available host RAM and start the Ubuntu container. For OpenTofu-managed
  startup, set `containers.cloudflared.started = true` in cluster 001's
  `base_env`, then review and apply `make plan-base-env CLUSTER=001` /
  `make apply-base-env CLUSTER=001`. `on_boot` independently controls host-boot
  startup. This playbook does not start Proxmox guests.
- Base-env must have generated `ansible/inventory/001/inventory.yml`, including
  `cloudflared` under `system_containers`. Do not hand-edit the inventory.
- Root SSH using the existing shared key must work from the Ansible runner.
  The playbook can install missing Python, but cannot install SSH before it can
  connect. If SSH is missing, use the Proxmox console to install/enable
  `openssh-server` first.
- The guest needs HTTPS access to Ubuntu mirrors and GitHub release downloads,
  plus outbound connectivity required by Cloudflare Tunnel.

## Private credential

Add the following assignment locally to `.local/credentials/001/.env`:

```dotenv
CLOUDFLARED_TUNNEL_TOKEN='<homelab-warp connector token>'
```

Keep the file at 0600 and its directory at 0700. Obtain the token through the
Cloudflare tunnel setup or replica workflow. Never commit it or pass it using
`ansible-playbook -e`, an installation command argument, or a Terraform input.
The Make target loads global credentials followed by cluster overrides using
the existing direnv configuration. It does not retrieve or create tokens.

## Install or reconcile

From the repository root:

```sh
make setup-cloudflared CLUSTER=001
```

The target checks for the inventory and token. The playbook validates its target,
waits for SSH, bootstraps Python if absent, and requires Ubuntu 24.04 amd64 with
systemd. It downloads the official `cloudflared` 2026.10.1 binary and verifies
its release SHA256 checksum before installation at `/usr/local/bin/cloudflared`.
Version and digest are pinned in `ansible/group_vars/cloudflared.yml` and must
be updated together for an upgrade.

The token is copied to `/etc/cloudflared/tunnel-token` with root ownership and
0600 permissions in a 0700 directory. Token validation and copying use `no_log`,
and secret diffs and backups are disabled. The systemd unit refers to the token
file, so the token is not embedded in command arguments or the unit.

The service runs as root inside the unprivileged LXC, starts at guest boot,
restarts on process failure, and has automatic binary updates disabled. Binary,
token, or unit changes notify one restart handler; unchanged reruns keep the
running service. The playbook then requires HTTP 200 from the guest-local
`http://127.0.0.1:2000/ready`, confirming an active Cloudflare connection. Metrics
and readiness bind only to loopback.

A healthy connector does not establish authorization or routing by itself.
Configure the tunnel's LAN routes, WARP split tunnels, enrollment, and access
policies separately. The playbook does not create DNS records, routes, policies,
or modify the Kubernetes connector.

## Rotate, upgrade, and troubleshoot

After rotating the tunnel token in Cloudflare, update the private environment
and rerun the Make target. Ansible replaces the file and restarts the connector.
For a version upgrade or rollback, change the pinned version and matching digest,
then rerun the same target. A single connector restart briefly interrupts traffic.

On the Ubuntu guest:

```sh
systemctl status cloudflared --no-pager
journalctl -u cloudflared -n 50 --no-pager
curl --fail http://127.0.0.1:2000/ready
```

If readiness fails, inspect the service logs, token validity, DNS, and outbound
connectivity. The playbook intentionally leaves the service enabled for diagnosis
and reconnection; it does not roll back automatically. Stop it on the guest with
`systemctl disable --now cloudflared` when decommissioning, and retire its
Cloudflare routes/tunnel separately.

## Offline verification

Syntax and host-selection checks do not connect to guests:

```sh
cd ansible
ansible-playbook --syntax-check playbooks/cloudflared.yml
ansible-playbook --list-hosts playbooks/cloudflared.yml
```

`--check` is useful only on an already bootstrapped guest with Python and the
service installed; it skips the readiness request and does not bootstrap Python.
A fresh-install dry run cannot prove connectivity or service startup. The
repository implementation was checked locally, not deployed to the live LXC.

## References

- [Official cloudflared release](https://github.com/cloudflare/cloudflared/releases/tag/2026.10.1)
- [Release metadata and asset digests](https://api.github.com/repos/cloudflare/cloudflared/releases/tags/2026.10.1)
- [Token-file and service parameters](https://developers.cloudflare.com/tunnel/reference/run-parameters/)
- [Tunnel token management](https://developers.cloudflare.com/tunnel/reference/tunnel-tokens/)
