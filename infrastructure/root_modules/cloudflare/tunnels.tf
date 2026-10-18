resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  for_each = var.tunnels

  account_id = var.account_id
  name       = each.value.name
  config_src = "cloudflare"

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# A configuration owns the complete ordered ingress list, including its final
# catch-all rule. Leave a tunnel out of this map until its full config is known.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  for_each = { for k, v in var.tunnels : k => v if v.ingress != null }

  account_id = var.account_id
  tunnel_id  = try(cloudflare_zero_trust_tunnel_cloudflared.this[each.key].id, null)
  config = {
    ingress = [for ingress in each.value.ingress : {
      hostname = ingress.hostname
      service  = ingress.service
    }]
  }
}

locals {
  tunnel_private_routes = flatten([
    for tunnel_key, tunnel in var.tunnels : [
      for cidr in tunnel.private_cidrs : {
        key          = "${tunnel_key}_${cidr.network}"
        tunnel       = tunnel_key
        private_cidr = cidr
      }
    ] if tunnel.private_cidrs != null
  ])
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "this" {
  for_each = { for route in local.tunnel_private_routes : route.key => route }

  account_id = var.account_id
  tunnel_id  = try(cloudflare_zero_trust_tunnel_cloudflared.this[each.value.tunnel].id, null)
  network    = each.value.private_cidr.network
  comment    = each.value.private_cidr.comment
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  for_each   = var.tunnels
  account_id = var.account_id
  tunnel_id  = try(cloudflare_zero_trust_tunnel_cloudflared.this[each.key].id, null)
}

output "cloudflared_token" {
  value = {
    for k, tunnel in var.tunnels : k => data.cloudflare_zero_trust_tunnel_cloudflared_token.this[k].token
  }
  sensitive = true
}
