output "instance_public_ip" {
  description = "Public IP of the A1 instance"
  value       = oci_core_instance.a1_flex.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the A1 instance"
  value       = oci_core_instance.a1_flex.private_ip
}

output "instance_ocid" {
  description = "OCID of the A1 instance"
  value       = oci_core_instance.a1_flex.id
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.main.id
}

output "subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

output "nsg_id" {
  description = "OCID of the Network Security Group"
  value       = oci_core_network_security_group.instance.id
}

output "reserved_public_ip" {
  description = "Reserved public IP OCID"
  value       = oci_core_public_ip.instance.id
}