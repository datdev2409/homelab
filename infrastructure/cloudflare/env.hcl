locals {
  account_id = "e56d7e9643a5ae9809f63e0866fed1a9"
  zone_name  = "datnguyen.me"
}

inputs = {
  account_id = local.account_id

  zone_name = local.zone_name

  tunnels = {
    warp = {
      name = "homelab-warp"
      private_cidrs = [
        {
          network = "192.168.1.0/24"
          comment = "Home LAN via Proxmox connector"
        }
      ]
    }
    http-ingress = {
      name = "homelab-http-ingress"
      ingress = [
        {
          hostname     = "homelab.${local.zone_name}"
          service      = "https://traefik.traefik.svc.cluster.local"
          add_zone_dns = true
        },
        { service = "http_status:404" }
      ]
    }
  }
}
