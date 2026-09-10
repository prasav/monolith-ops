variable "a1_ocpus" {
  type        = number
  description = "A1 Flex OCPUs (max 2 for Always Free as of June 2026)"
  default     = 2
  validation {
    condition     = var.a1_ocpus <= 2 && var.a1_ocpus > 0
    error_message = "Always Free A1 limit is 2 OCPUs max (June 2026)."
  }
}

variable "a1_memory_gb" {
  type        = number
  description = "A1 Flex memory in GB (max 12 for Always Free as of June 2026)"
  default     = 12
  validation {
    condition     = var.a1_memory_gb <= 12 && var.a1_memory_gb > 0
    error_message = "Always Free A1 limit is 12 GB max (June 2026)."
  }
}

variable "instance_hostname" {
  type        = string
  description = "Hostname for the A1 instance (must be unique in subnet)"
  default     = "monolith-a1"
}

variable "vcn_cidr" {
  type        = string
  description = "VCN CIDR block"
  default     = "10.0.0.0/16"
}

variable "vcn_dns_label" {
  type        = string
  description = "VCN DNS label"
  default     = "monolithvcn"
}

variable "subnet_cidr" {
  type        = string
  description = "Public subnet CIDR"
  default     = "10.0.1.0/24"
}

variable "subnet_dns_label" {
  type        = string
  description = "Subnet DNS label"
  default     = "monolithsub"
}

variable "admin_cidr" {
  type        = string
  description = "Admin CIDR for SSH access (your IP/32)"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key for instance access"
}

variable "timezone" {
  type        = string
  description = "Timezone for the instance"
  default     = "Asia/Kolkata"
}

variable "environment" {
  type        = string
  description = "Environment tag"
  default     = "production"
}