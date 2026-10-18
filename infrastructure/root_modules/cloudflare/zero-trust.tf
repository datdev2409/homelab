# Opt in after matching the existing organization settings, then import it
# using the account ID before applying.
resource "cloudflare_zero_trust_organization" "this" {
  count = var.zero_trust == null ? 0 : 1

  account_id                  = var.account_id
  name                        = var.zero_trust.name
  auth_domain                 = var.zero_trust.auth_domain
  session_duration            = var.zero_trust.session_duration
  allow_authenticate_via_warp = var.zero_trust.allow_authenticate_via_warp
  auto_redirect_to_identity   = var.zero_trust.auto_redirect_to_identity
  deny_unmatched_requests     = var.zero_trust.deny_unmatched_requests
  is_ui_read_only             = var.zero_trust.is_ui_read_only

  lifecycle {
    prevent_destroy = true
  }
}

# Optional account-wide WARP default profile; supplying a split-tunnel list
# replaces that list rather than adding entries to the dashboard configuration.
resource "cloudflare_zero_trust_device_default_profile" "this" {
  count = var.warp_profile == null ? 0 : 1

  account_id        = var.account_id
  include           = var.warp_profile.include
  exclude           = var.warp_profile.exclude
  allowed_to_leave  = var.warp_profile.allowed_to_leave
  allow_mode_switch = var.warp_profile.allow_mode_switch
  switch_locked     = var.warp_profile.switch_locked
  service_mode_v2 = {
    mode = var.warp_profile.mode
  }
}
