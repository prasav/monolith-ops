terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
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
    key    = "gcp/terraform.tfstate"
    region = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check    = true
    skip_requesting_account_id = true
    endpoints = {
      s3 = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
    }
  }
}

variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region (e2-micro free only in us-west1, us-central1, us-east1)"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP Zone"
  default     = "us-central1-a"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare Account ID (for R2 state backend)"
}

variable "admin_ssh_key" {
  type        = string
  description = "SSH public key for e2-micro admin access"
}

# Service account for Terraform (created separately, key stored securely)
variable "tf_sa_email" {
  type        = string
  description = "Terraform service account email"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "random" {}
provider "time" {}