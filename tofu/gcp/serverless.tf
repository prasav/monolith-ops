# Cloud Run services (serverless demos, min-instances=0)

resource "google_cloud_run_v2_service" "demo" {
  name                = "demo-app"
  location            = var.region
  deletion_protection = false
  template {
    containers {
      image = "gcr.io/cloudrun/hello"
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }
    }
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
  labels = {
    managed-by = "monolith-ops"
  }
}

# Firestore database (free 1 GB)
resource "google_firestore_database" "main" {
  project                 = var.project_id
  name                    = "(default)"
  location_id             = "nam5" # Multi-region US
  type                    = "FIRESTORE_NATIVE"
  delete_protection_state = "DELETE_PROTECTION_ENABLED"
  deletion_policy         = "DELETE"
}

# BigQuery dataset for analytics
resource "google_bigquery_dataset" "analytics" {
  dataset_id    = "analytics"
  friendly_name = "Monolith Analytics"
  description   = "Analytics dataset for freelance portfolio"
  location      = "US"
  default_table_expiration_ms = 2592000000  # 30 days
  labels = {
    managed-by = "monolith-ops"
  }
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "demos" {
  location      = var.region
  repository_id = "demos"
  description   = "Docker images for Cloud Run demos"
  format        = "DOCKER"
  labels = {
    managed-by = "monolith-ops"
  }
}

# Cloud Build trigger (for CI)
resource "google_cloudbuild_trigger" "deploy_demo" {
  name        = "deploy-demo"
  description = "Deploy demo app to Cloud Run on push"
  filename    = "cloudbuild.yaml"
  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }
  service_account = var.tf_sa_email
}

# Service accounts for workloads
resource "google_service_account" "cloudrun" {
  account_id   = "cloudrun-demo"
  display_name = "Cloud Run Demo Service Account"
  description  = "Runs Cloud Run demo services"
}

resource "google_service_account" "backup" {
  account_id   = "backup-writer"
  display_name = "Backup Writer"
  description  = "Writes backups to GCS and BigQuery"
}

# IAM bindings
resource "google_project_iam_member" "cloudrun_runner" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

resource "google_project_iam_member" "backup_writer" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.backup.email}"
}

resource "google_project_iam_member" "backup_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.backup.email}"
}