# Makefile for monolith-ops

.PHONY: init plan apply destroy plan-oci apply-oci plan-gcp apply-gcp plan-cloudflare apply-cloudflare

# Initialize all providers
init:
	@echo "Initializing OCI..."
	cd tofu/oci && tofu init
	@echo "Initializing GCP..."
	cd tofu/gcp && tofu init
	@echo "Initializing Cloudflare..."
	cd tofu/cloudflare && tofu init

# Plan all
plan: plan-oci plan-gcp plan-cloudflare

plan-oci:
	cd tofu/oci && tofu plan

plan-gcp:
	cd tofu/gcp && tofu plan

plan-cloudflare:
	cd tofu/cloudflare && tofu plan

# Apply all
apply: apply-oci apply-gcp apply-cloudflare

apply-oci:
	cd tofu/oci && tofu apply

apply-gcp:
	cd tofu/gcp && tofu apply

apply-cloudflare:
	cd tofu/cloudflare && tofu apply

# Destroy (use with caution)
destroy:
	@echo "Destroying Cloudflare..."
	cd tofu/cloudflare && tofu destroy
	@echo "Destroying GCP..."
	cd tofu/gcp && tofu destroy
	@echo "Destroying OCI..."
	cd tofu/oci && tofu destroy

# Validate all
validate:
	cd tofu/oci && tofu validate
	cd tofu/gcp && tofu validate
	cd tofu/cloudflare && tofu validate

# Format all
fmt:
	cd tofu/oci && tofu fmt -recursive
	cd tofu/gcp && tofu fmt -recursive
	cd tofu/cloudflare && tofu fmt -recursive