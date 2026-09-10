# VCN and Networking

resource "oci_core_vcn" "main" {
  compartment_id = local.compartment_id
  cidr_block     = var.vcn_cidr
  dns_label      = var.vcn_dns_label
  display_name   = "${var.instance_hostname}-vcn"
  freeform_tags = {
    managed-by = "monolith-ops"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  cidr_block     = var.subnet_cidr
  dns_label      = var.subnet_dns_label
  display_name   = "${var.instance_hostname}-subnet"
  prohibit_public_ip_on_vnic = false
  route_table_id = oci_core_route_table.nat.id
  freeform_tags = {
    managed-by = "monolith-ops"
  }
}

# Internet Gateway for public access
resource "oci_core_internet_gateway" "main" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.instance_hostname}-igw"
  is_enabled     = true
  freeform_tags = {
    managed-by = "monolith-ops"
  }
}

# NAT Gateway for private subnet egress (not strictly needed for public subnet, but good practice)
resource "oci_core_nat_gateway" "main" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.instance_hostname}-nat"
  block_traffic  = false
  freeform_tags = {
    managed-by = "monolith-ops"
  }
}

# Route Table for public subnet
resource "oci_core_route_table" "nat" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.instance_hostname}-rt"
  route_rules = [
    {
      network_entity_id = oci_core_internet_gateway.main.id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  ]
  freeform_tags = {
    managed-by = "monolith-ops"
  }
}

# Security List as backup (OCI requires either NSG or Security List)
resource "oci_core_security_list" "default" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.instance_hostname}-sl"
  ingress_security_rules = [
    {
      protocol  = "6"
      source    = var.admin_cidr
      stateless = false
      tcp_options {
        destination_port_range { min = 22 max = 22 }
      }
    },
    {
      protocol   = "17"
      source     = "100.64.0.0/10"
      stateless  = false
      udp_options {
        destination_port_range { min = 41641 max = 41641 }
      }
    },
    {
      protocol  = "all"
      source    = var.vcn_cidr
      stateless = false
    }
  ]
  egress_security_rules = [
    {
      protocol        = "all"
      destination     = "0.0.0.0/0"
      destination_type = "CIDR_BLOCK"
      stateless       = false
    }
  ]
  freeform_tags = {
    managed-by = "monolith-ops"
  }
}

# Reserve public IP for the instance (optional, for stability)
resource "oci_core_public_ip" "instance" {
  compartment_id = local.compartment_id
  lifetime       = "RESERVED"
  display_name   = "${var.instance_hostname}-public-ip"
  freeform_tags = {
    managed-by = "monolith-ops"
  }
}