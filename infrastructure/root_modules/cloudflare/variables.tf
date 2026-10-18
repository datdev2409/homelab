variable "account_id" {
  description = "Existing Cloudflare account ID; not a user ID or an Enterprise Organization ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32-character lowercase hexadecimal Cloudflare account ID."
  }
}

variable "zone_name" {
  description = "Existing domain zone to adopt, such as datnguyen.me. Domain registration is separate."
  type        = string
}

variable "zone_settings" {
  description = "Explicit zone setting IDs and values, for example ssl = strict. Omitted settings are unmanaged."
  # Values can be strings, numbers, or objects depending on the setting.
  type    = any
  default = {}

  validation {
    condition     = can(keys(var.zone_settings))
    error_message = "zone_settings must be a map of setting IDs to their values."
  }
}

variable "dns_records" {
  description = "DNS records keyed by stable names. Set content OR tunnel_key; tunnel records are proxied CNAMEs."
  type = map(object({
    name       = string
    type       = string
    content    = optional(string)
    tunnel_key = optional(string)
    ttl        = optional(number, 1)
    proxied    = optional(bool, false)
    priority   = optional(number)
    comment    = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([for record in values(var.dns_records) :
      (record.content != null) != (record.tunnel_key != null)
    ])
    error_message = "Each DNS record must have exactly one of content or tunnel_key."
  }

  validation {
    condition = alltrue([for record in values(var.dns_records) :
      record.tunnel_key == null || (record.type == "CNAME" && record.proxied && record.ttl == 1)
    ])
    error_message = "Tunnel records must use type CNAME, proxied = true, and ttl = 1."
  }
}

variable "zero_trust" {
  description = "Optional existing Zero Trust organization settings. Import by account ID before applying."
  type = object({
    name                        = string
    auth_domain                 = string
    session_duration            = optional(string)
    allow_authenticate_via_warp = optional(bool)
    auto_redirect_to_identity   = optional(bool)
    deny_unmatched_requests     = optional(bool)
    is_ui_read_only             = optional(bool)
  })
  default = null

  validation {
    condition     = var.zero_trust == null ? true : can(regex("^[a-z0-9-]+[.]cloudflareaccess[.]com$", var.zero_trust.auth_domain))
    error_message = "zero_trust.auth_domain must be the existing team-name.cloudflareaccess.com domain."
  }
}

variable "warp_profile" {
  description = "Optional account-wide WARP default profile. Include and exclude are mutually exclusive complete lists."
  type = object({
    mode              = optional(string, "warp")
    allowed_to_leave  = optional(bool)
    allow_mode_switch = optional(bool)
    switch_locked     = optional(bool)
    include = optional(list(object({
      address     = optional(string)
      host        = optional(string)
      description = optional(string)
    })))
    exclude = optional(list(object({
      address     = optional(string)
      host        = optional(string)
      description = optional(string)
    })))
  })
  default = null

  validation {
    condition     = var.warp_profile == null ? true : (var.warp_profile.include != null) != (var.warp_profile.exclude != null)
    error_message = "Set exactly one of warp_profile.include or warp_profile.exclude."
  }

  validation {
    condition = var.warp_profile == null ? true : alltrue([
      for route in concat(coalesce(var.warp_profile.include, []), coalesce(var.warp_profile.exclude, [])) :
      (route.address != null) != (route.host != null)
    ])
    error_message = "Each split-tunnel entry must specify exactly one of address or host."
  }
}

variable "tunnels" {
  description = "Remotely managed tunnels keyed by stable purpose, for example http and vpn. Existing tunnels need import."
  type = map(object({
    name = string
    ingress = optional(list(object({
      hostname     = optional(string)
      service      = string
      add_zone_dns = optional(bool, false)
    })), null)
    private_cidrs = optional(list(object({
      network = string
      comment = optional(string)
    })), null)
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for tunnel in values(var.tunnels) : [
        for ingress in coalesce(tunnel.ingress, []) :
        !ingress.add_zone_dns || try(trimspace(ingress.hostname) != "", false)
      ]
    ]))
    error_message = "Ingress rules with add_zone_dns = true must specify a hostname."
  }
}

variable "tunnel_configurations" {
  description = "Complete provider-schema config objects keyed by tunnel key. Omit tunnels whose config is not yet adopted."
  # Keep the provider's full origin_request schema available without duplicating
  # it or silently discarding options through a narrower object conversion.
  type    = any
  default = {}

  validation {
    condition     = can(keys(var.tunnel_configurations))
    error_message = "tunnel_configurations must be a map of tunnel keys to config objects."
  }
}
