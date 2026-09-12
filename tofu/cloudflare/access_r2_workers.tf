# Zero Trust Access - protect admin interfaces
# Policies are configured per-app in the dashboard (provider v5 schema for
# shared policies churns) — apps below are the stable part.
resource "cloudflare_zero_trust_access_application" "n8n" {
  account_id       = var.cloudflare_account_id
  name             = "n8n Admin"
  domain           = "n8n.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_application" "coolify" {
  account_id       = var.cloudflare_account_id
  name             = "Coolify Admin"
  domain           = "coolify.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_application" "gitea" {
  account_id       = var.cloudflare_account_id
  name             = "Gitea Admin"
  domain           = "gitea.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_application" "vaultwarden" {
  account_id       = var.cloudflare_account_id
  name             = "Vaultwarden Admin"
  domain           = "vaultwarden.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_application" "jellyfin" {
  account_id       = var.cloudflare_account_id
  name             = "Jellyfin Admin"
  domain           = "jellyfin.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_application" "status" {
  account_id       = var.cloudflare_account_id
  name             = "Uptime Kuma Admin"
  domain           = "status.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_application" "beszel" {
  account_id       = var.cloudflare_account_id
  name             = "Beszel Admin"
  domain           = "beszel.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

# R2 bucket for backups and state
resource "cloudflare_r2_bucket" "state" {
  account_id = var.cloudflare_account_id
  name       = "monolith-ops-state"
  location   = "WNAM" # Western North America
}

resource "cloudflare_r2_bucket" "backups" {
  account_id = var.cloudflare_account_id
  name       = "monolith-ops-backups"
  location   = "WNAM"
}

# Workers + Pages are deployed via wrangler/dashboard (schemas churn across
# provider versions) — see workers/webhooks.js and portfolio repo.
# Uncomment and pin exact schema once `tofu init` locks your version.

# Email Routing - free custom email
resource "cloudflare_email_routing_address" "admin" {
  account_id = var.cloudflare_account_id
  email      = var.personal_email
}