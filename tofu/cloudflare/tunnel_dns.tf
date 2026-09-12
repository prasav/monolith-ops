# Cloudflare Tunnels (tunnel IDs + secrets in Terraform; ingress config lives
# on each VM in /etc/cloudflared/config.yml — see docs/cloudflared-*.yml)
resource "random_password" "oracle_tunnel_secret" {
  length  = 32
  special = false
}

resource "random_password" "gcp_tunnel_secret" {
  length  = 32
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "oracle" {
  account_id = var.cloudflare_account_id
  name       = "oracle-a1"
  config_src = "cloudflare"
  tunnel_secret = base64encode(random_password.oracle_tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "gcp" {
  account_id = var.cloudflare_account_id
  name       = "gcp-watchdog"
  config_src = "cloudflare"
  tunnel_secret = base64encode(random_password.gcp_tunnel_secret.result)
}

# DNS records pointing to Tunnels
resource "cloudflare_dns_record" "n8n" {
  zone_id = var.cloudflare_zone_id
  name    = "n8n.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "coolify" {
  zone_id = var.cloudflare_zone_id
  name    = "coolify.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "gitea" {
  zone_id = var.cloudflare_zone_id
  name    = "gitea.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "vaultwarden" {
  zone_id = var.cloudflare_zone_id
  name    = "vaultwarden.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "jellyfin" {
  zone_id = var.cloudflare_zone_id
  name    = "jellyfin.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "status" {
  zone_id = var.cloudflare_zone_id
  name    = "status.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.gcp.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "beszel" {
  zone_id = var.cloudflare_zone_id
  name    = "beszel.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.gcp.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# Root domain -> Cloudflare Pages (portfolio)
resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "CNAME"
  content = "${var.domain}.pages.dev"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.domain}"
  type    = "CNAME"
  content = "${var.domain}.pages.dev"
  proxied = true
  ttl     = 1
}

# Wildcard for future subdomains
resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
