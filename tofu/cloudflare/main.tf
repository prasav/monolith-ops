terraform {
  required_version = ">= 1.6"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  backend "s3" {
    bucket = "monolith-ops-state"
    key    = "cloudflare/terraform.tfstate"
    region = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check    = true
    skip_requesting_account_id = true
    endpoints = {
      s3 = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
    }
  }
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token with Zone:Read, Zone:Edit, Account:Read, Account:Edit, R2:Edit, Workers:Edit, Pages:Edit, Zero Trust:Edit"
  sensitive   = true
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare Account ID"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID (for your domain)"
}

variable "domain" {
  type        = string
  description = "Root domain (e.g., example.com)"
}

variable "oracle_tunnel_token" {
  type        = string
  description = "Cloudflare Tunnel token for Oracle A1"
  sensitive   = true
}

variable "gcp_tunnel_token" {
  type        = string
  description = "Cloudflare Tunnel token for GCP e2-micro"
  sensitive   = true
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "random" {}
provider "time" {}