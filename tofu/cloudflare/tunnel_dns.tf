# Cloudflare Tunnel for Oracle A1
resource "cloudflare_zero_trust_tunnel" "oracle" {
  account_id = var.cloudflare_account_id
  name       = "oracle-a1"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_config" "oracle" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel.oracle.id
  config = jsonencode({
    ingress = [
      {
        hostname = "n8n.${var.domain}"
        service  = "http://localhost:5678"
        originRequest = {
          httpHostHeader = "n8n.${var.domain}"
        }
      },
      {
        hostname = "coolify.${var.domain}"
        service  = "http://localhost:8000"
        originRequest = {
          httpHostHeader = "coolify.${var.domain}"
        }
      },
      {
        hostname = "gitea.${var.domain}"
        service  = "http://localhost:3000"
        originRequest = {
          httpHostHeader = "gitea.${var.domain}"
        }
      },
      {
        hostname = "vaultwarden.${var.domain}"
        service  = "http://localhost:8080"
        originRequest = {
          httpHostHeader = "vaultwarden.${var.domain}"
        }
      },
      {
        hostname = "jellyfin.${var.domain}"
        service  = "http://localhost:8096"
        originRequest = {
          httpHostHeader = "jellyfin.${var.domain}"
        }
      },
      {
        service = "http_status:404"
      }
    ]
  })
}

# Cloudflare Tunnel for GCP e2-micro
resource "cloudflare_zero_trust_tunnel" "gcp" {
  account_id = var.cloudflare_account_id
  name       = "gcp-watchdog"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_config" "gcp" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel.gcp.id
  config = jsonencode({
    ingress = [
      {
        hostname = "status.${var.domain}"
        service  = "http://localhost:3001"
        originRequest = {
          httpHostHeader = "status.${var.domain}"
        }
      },
      {
        hostname = "beszel.${var.domain}"
        service  = "http://localhost:8090"
        originRequest = {
          httpHostHeader = "beszel.${var.domain}"
        }
      },
      {
        service = "http_status:404"
      }
    ]
  })
}

# DNS records pointing to Tunnels
resource "cloudflare_record" "n8n" {
  zone_id = var.cloudflare_zone_id
  name    = "n8n"
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "coolify" {
  zone_id = var.cloudflare_zone_id
  name    = "coolify"
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "gitea" {
  zone_id = var.cloudflare_zone_id
  name    = "gitea"
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "vaultwarden" {
  zone_id = var.cloudflare_zone_id
  name    = "vaultwarden"
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "jellyfin" {
  zone_id = var.cloudflare_zone_id
  name    = "jellyfin"
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "status" {
  zone_id = var.cloudflare_zone_id
  name    = "status"
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel.gcp.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "beszel" {
  zone_id = var.cloudflare_zone_id
  name    = "beszel"
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel.gcp.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# Root domain -> Cloudflare Pages (portfolio)
resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CNAME"
  value   = "${var.domain}.pages.dev"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  type    = "CNAME"
  value   = "${var.domain}.pages.dev"
  proxied = true
  ttl     = 1
}

# Wildcard for future subdomains
resource "cloudflare_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel.oracle.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}