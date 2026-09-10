# OCI Compute - Ampere A1 Flex (Always Free)
# 2 OCPU / 12 GB RAM max under current limits (June 2026)

resource "oci_core_instance" "a1_flex" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = local.compartment_id
  shape               = "VM.Standard.A1.Flex"
  shape_config {
    ocpus  = var.a1_ocpus
    memory_in_gbs = var.a1_memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.instance.id]
    hostname_label   = var.instance_hostname
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      hostname = var.instance_hostname
      timezone = var.timezone
    }))
  }

  freeform_tags = {
    managed-by = "monolith-ops"
    environment = var.environment
  }
}

# Always Free Ubuntu image
data "oci_core_images" "ubuntu" {
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid
  operating_system = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape = "VM.Standard.A1.Flex"
  sort_by = "TIMECREATED"
  sort_order = "DESC"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Network Security Group - only what we need
resource "oci_core_network_security_group" "instance" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.instance_hostname}-nsg"
  freeform_tags = {
    managed-by = "monolith-ops"
  }
}

# Ingress rules - Cloudflare Tunnel handles external, so only internal + SSH from admin
resource "oci_core_network_security_group_security_rule" "ssh" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.admin_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
  description = "SSH from admin CIDR only"
}

# Allow Tailscale mesh traffic
resource "oci_core_network_security_group_security_rule" "tailscale" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP
  source                    = "100.64.0.0/10"
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  udp_options {
    destination_port_range {
      min = 41641
      max = 41641
    }
  }
  description = "Tailscale control plane"
}

# Allow all internal VCN traffic (for Coolify containers, DB, etc.)
resource "oci_core_network_security_group_security_rule" "internal" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_vcn.main.cidr_block
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  description               = "Full internal VCN access"
}

# Egress - allow all (Cloudflare Tunnel + apt + docker)
resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
  description               = "All outbound"
}