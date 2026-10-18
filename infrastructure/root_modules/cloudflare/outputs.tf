output "zone_id" {
  value = cloudflare_zone.this.id
}

output "name_servers" {
  value = cloudflare_zone.this.name_servers
}

output "tunnel_ids" {
  value = { for key, tunnel in cloudflare_zero_trust_tunnel_cloudflared.this : key => tunnel.id }
}

output "private_route_ids" {
  value = { for key, route in cloudflare_zero_trust_tunnel_cloudflared_route.this : key => route.id }
}
