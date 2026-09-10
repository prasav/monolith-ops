variable "timezone" {
  type        = string
  description = "Timezone for the instance"
  default     = "Asia/Kolkata"
}

variable "admin_cidr" {
  type        = string
  description = "Admin CIDR for SSH access (your IP/32)"
}

variable "billing_account" {
  type        = string
  description = "GCP Billing Account ID (for budget alerts)"
}

variable "github_owner" {
  type        = string
  description = "GitHub owner for Cloud Build trigger"
  default     = ""
}

variable "github_repo" {
  type        = string
  description = "GitHub repo for Cloud Build trigger"
  default     = ""
}