resource "cloudflare_zone" "this" {
  account = {
    id = var.account_id
  }
  name = var.zone_name
  type = "full"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_zone_setting" "this" {
  for_each = var.zone_settings

  zone_id    = cloudflare_zone.this.id
  setting_id = each.key
  value      = each.value
}

resource "cloudflare_dns_record" "this" {
  for_each = var.dns_records

  zone_id  = cloudflare_zone.this.id
  name     = each.value.name
  type     = each.value.type
  ttl      = each.value.ttl
  proxied  = each.value.proxied
  priority = each.value.priority
  comment  = each.value.comment
  content = each.value.tunnel_key == null ? each.value.content : try(
    "${cloudflare_zero_trust_tunnel_cloudflared.this[each.value.tunnel_key].id}.cfargotunnel.com", null
  )

  lifecycle {
    precondition {
      condition     = each.value.tunnel_key == null ? true : contains(keys(var.tunnels), each.value.tunnel_key)
      error_message = "A tunnel DNS record must reference a key in tunnels."
    }
  }
}

locals {
  tunnel_ingress_dns = flatten([
    for tunnel_key, tunnel in var.tunnels : [
      for ingress in coalesce(tunnel.ingress, []) : {
        hostname   = ingress.hostname
        tunnel_key = tunnel_key
      } if ingress.add_zone_dns && ingress.hostname != null
    ]
  ])
}

resource "cloudflare_dns_record" "tunnel_ingress" {
  for_each = { for record in local.tunnel_ingress_dns : record.hostname => record }

  zone_id = cloudflare_zone.this.id
  name    = each.value.hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this[each.value.tunnel_key].id}.cfargotunnel.com"
  ttl     = 1
  proxied = true

  lifecycle {
    precondition {
      condition = (
        lower(trimsuffix(each.value.hostname, ".")) == lower(trimsuffix(var.zone_name, ".")) ||
        endswith(lower(trimsuffix(each.value.hostname, ".")), ".${lower(trimsuffix(var.zone_name, "."))}")
      )
      error_message = "Ingress rules with add_zone_dns = true must use a hostname in zone_name."
    }
  }
}
