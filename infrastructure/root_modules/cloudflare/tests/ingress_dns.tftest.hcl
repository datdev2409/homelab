# Mocked plans never contact Cloudflare or read connector tokens.
mock_provider "cloudflare" {
  mock_resource "cloudflare_zero_trust_tunnel_cloudflared" {
    defaults = { id = "11111111-1111-1111-1111-111111111111" }
  }
}

variables {
  account_id = "00000000000000000000000000000000"
  zone_name  = "example.com"
  tunnels = {
    http = {
      name = "test-http"
      ingress = [
        { hostname = "app.example.com", service = "http://localhost:80", add_zone_dns = true },
        { hostname = "manual.example.com", service = "http://localhost:80", add_zone_dns = false },
        { hostname = "default.example.com", service = "http://localhost:80" },
        { service = "http_status:404" }
      ]
    }
    private = { name = "test-private" }
  }
}

run "enabled_hostname" {
  command = plan

  assert {
    condition     = keys(cloudflare_dns_record.tunnel_ingress) == ["app.example.com"]
    error_message = "Only explicitly enabled ingress hostnames should create DNS records."
  }

  assert {
    condition = (
      cloudflare_dns_record.tunnel_ingress["app.example.com"].name == "app.example.com" &&
      cloudflare_dns_record.tunnel_ingress["app.example.com"].type == "CNAME" &&
      cloudflare_dns_record.tunnel_ingress["app.example.com"].content == "11111111-1111-1111-1111-111111111111.cfargotunnel.com" &&
      cloudflare_dns_record.tunnel_ingress["app.example.com"].proxied &&
      cloudflare_dns_record.tunnel_ingress["app.example.com"].ttl == 1
    )
    error_message = "Ingress DNS must be a proxied CNAME to its tunnel with automatic TTL."
  }

  assert {
    condition = (
      length(cloudflare_zero_trust_tunnel_cloudflared_config.this["http"].config.ingress) == 4 &&
      cloudflare_zero_trust_tunnel_cloudflared_config.this["http"].config.ingress[3].service == "http_status:404"
    )
    error_message = "DNS generation must preserve the ordered ingress rules and catch-all."
  }
}

run "no_tunnels" {
  command = plan

  variables {
    tunnels = {}
  }

  assert {
    condition     = length(cloudflare_dns_record.tunnel_ingress) == 0
    error_message = "An empty tunnel map must not create ingress DNS records."
  }
}

run "hostname_required" {
  command = plan

  variables {
    tunnels = {
      http = {
        name    = "test-http"
        ingress = [{ service = "http_status:404", add_zone_dns = true }]
      }
    }
  }

  expect_failures = [var.tunnels]
}

run "hostname_outside_zone" {
  command = plan

  variables {
    tunnels = {
      http = {
        name = "test-http"
        ingress = [
          { hostname = "app.otherexample.com", service = "http://localhost:80", add_zone_dns = true },
          { service = "http_status:404" }
        ]
      }
    }
  }

  expect_failures = [cloudflare_dns_record.tunnel_ingress]
}
