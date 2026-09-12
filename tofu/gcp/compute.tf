# e2-micro instance - Always Free watchdog/control plane
# Only free in us-west1, us-central1, us-east1

resource "google_compute_instance" "e2_micro" {
  name         = "monolith-watchdog"
  machine_type = "e2-micro"
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30
      type  = "pd-standard"
    }
  }
  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      # Ephemeral public IP
    }
  }
  service_account {
    email  = var.tf_sa_email
    scopes = ["cloud-platform"]
  }
  metadata = {
    ssh-keys = "ubuntu:${var.admin_ssh_key}"
    enable-oslogin = "TRUE"
  }
  metadata_startup_script = templatefile("${path.module}/startup-script.sh", {
    timezone   = var.timezone
    admin_cidr = var.admin_cidr
  })
  labels = {
    managed-by = "monolith-ops"
    role       = "watchdog"
  }
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
}

# VPC for GCP resources
resource "google_compute_network" "vpc" {
  name                    = "monolith-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "monolith-subnet"
  ip_cidr_range = "10.10.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id
  secondary_ip_range {
    range_name    = "cloud-run"
    ip_cidr_range = "10.10.16.0/20"
  }
}

# Firewall rules - minimal, Cloudflare Tunnel handles external
resource "google_compute_firewall" "ssh" {
  name    = "monolith-allow-ssh"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [var.admin_cidr]
  target_tags   = ["watchdog"]
  priority      = 1000
}

resource "google_compute_firewall" "tailscale" {
  name    = "monolith-allow-tailscale"
  network = google_compute_network.vpc.name
  allow {
    protocol = "udp"
    ports    = ["41641"]
  }
  source_ranges = ["100.64.0.0/10"]
  target_tags   = ["watchdog"]
  priority      = 1000
}

resource "google_compute_firewall" "internal" {
  name    = "monolith-allow-internal"
  network = google_compute_network.vpc.name
  allow {
    protocol = "all"
  }
  source_ranges = ["10.10.0.0/20"]
  target_tags   = ["watchdog"]
  priority      = 1000
}

# Cloud NAT for private egress (if needed)
resource "google_compute_router" "nat" {
  name    = "monolith-router"
  network = google_compute_network.vpc.name
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "monolith-nat"
  router                             = google_compute_router.nat.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Budget alert - $1/month
resource "google_billing_budget" "budget" {
  billing_account = var.billing_account
  display_name    = "monolith-ops-gcp-budget"
  budget_filter {
    projects = ["projects/${var.project_id}"]
  }
  amount {
    specified_amount {
      currency_code = "USD"
      units         = "1"
    }
  }
  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}