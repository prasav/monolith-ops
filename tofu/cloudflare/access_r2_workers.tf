# Zero Trust Access - protect admin interfaces
resource "cloudflare_zero_trust_application" "n8n" {
  account_id = var.cloudflare_account_id
  name       = "n8n Admin"
  domain     = "n8n.${var.domain}"
  type       = "self_hosted"
  session_duration = "24h"
  cors_headers = []
}

resource "cloudflare_zero_trust_application" "coolify" {
  account_id = var.cloudflare_account_id
  name       = "Coolify Admin"
  domain     = "coolify.${var.domain}"
  type       = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_application" "gitea" {
  account_id = var.cloudflare_account_id
  name       = "Gitea Admin"
  domain     = "gitea.${var.domain}"
  type       = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_application" "vaultwarden" {
  account_id = var.cloudflare_account_id
  name       = "Vaultwarden Admin"
  domain     = "vaultwarden.${var.domain}"
  type       = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_application" "jellyfin" {
  account_id = var.cloudflare_account_id
  name       = "Jellyfin Admin"
  domain     = "jellyfin.${var.domain}"
  type       = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_application" "status" {
  account_id = var.cloudflare_account_id
  name       = "Uptime Kuma Admin"
  domain     = "status.${var.domain}"
  type       = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_application" "beszel" {
  account_id = var.cloudflare_account_id
  name       = "Beszel Admin"
  domain     = "beszel.${var.domain}"
  type       = "self_hosted"
  session_duration = "24h"
}

# Access policies - email-based (or use GitHub/OIDC)
resource "cloudflare_zero_trust_access_policy" "admin_policy" {
  account_id = var.cloudflare_account_id
  name       = "Admin Access"
  decision   = "allow"
  applications = [
    cloudflare_zero_trust_application.n8n.id,
    cloudflare_zero_trust_application.coolify.id,
    cloudflare_zero_trust_application.gitea.id,
    cloudflare_zero_trust_application.vaultwarden.id,
    cloudflare_zero_trust_application.jellyfin.id,
    cloudflare_zero_trust_application.status.id,
    cloudflare_zero_trust_application.beszel.id,
  ]
  include = [
    {
      email = {
        email = var.admin_email
      }
    }
  ]
  require = [
    {
      email = {}
    }
  ]
}

# R2 bucket for backups and state
resource "cloudflare_r2_bucket" "state" {
  account_id = var.cloudflare_account_id
  name       = "monolith-ops-state"
  location   = "WNAM"  # Western North America
}

resource "cloudflare_r2_bucket" "backups" {
  account_id = var.cloudflare_account_id
  name       = "monolith-ops-backups"
  location   = "WNAM"
  versioning = true
}

# Worker for webhooks/cron (100k/day free)
resource "cloudflare_worker_script" "webhooks" {
  account_id = var.cloudflare_account_id
  name       = "monolith-webhooks"
  content    = file("${path.module}/workers/webhooks.js")
  compatibility_date = "2026-09-10"
  module     = true
}

resource "cloudflare_worker_route" "webhooks" {
  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id
  pattern    = "webhooks.${var.domain}/*"
  script_name = cloudflare_worker_script.webhooks.name
}

# Cloudflare Pages for portfolio (static site)
resource "cloudflare_pages_project" "portfolio" {
  account_id = var.cloudflare_account_id
  name       = "portfolio"
  production_branch = "main"
  build_config {
    build_command = "npm run build"
    destination_dir = "dist"
    root_dir = "/portfolio"
  }
  deployment_configs = {
    production = {
      env_vars = {}
    }
    preview = {
      env_vars = {}
    }
  }
}

# Email Routing - free custom email
resource "cloudflare_email_routing_address" "admin" {
  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id
  name       = "admin"
  email      = var.personal_email
}