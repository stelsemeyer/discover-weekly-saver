resource "google_service_account" "cloud_function" {
  account_id = local.name
}

resource "google_storage_bucket" "cloud_function" {
  name     = local.bucket_name
  location = "EU"

  force_destroy = true
}

resource "google_storage_bucket_object" "cloud_function" {
  name   = local.function_archive_name
  bucket = google_storage_bucket.cloud_function.name
  source = data.archive_file.cloud_function.output_path
}

data "archive_file" "cloud_function" {
  type        = "zip"
  source_dir  = local.local_function_source_dir
  output_path = local.function_archive_name
}

resource "google_cloudfunctions_function" "cloud_function" {
  name    = local.name
  runtime = "python310"

  available_memory_mb          = 128
  source_archive_bucket        = google_storage_bucket.cloud_function.name
  source_archive_object        = google_storage_bucket_object.cloud_function.name
  trigger_http                 = true
  https_trigger_security_level = "SECURE_ALWAYS"
  timeout                      = 300
  entry_point                  = "copy_tracks"
  service_account_email        = google_service_account.cloud_function.email

  environment_variables = {
    GCP_PROJECT_ID        = local.project
    GCP_SECRET_ID         = local.secret_name
    # We will pass the Spotify credentials in the deployment step within Github actions
    # SPOTIFY_CLIENT_ID     = var.spotify_client_id
    # SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
    # SPOTIFY_REDIRECT_URI  = var.spotify_redirect_uri
  }

  # Since we manage the cloud function through Github we do not want
  # to trigger recreation when specific values change
  lifecycle {
    ignore_changes = [
      source_archive_object,
      # Cloud functions have a label "deployment-tool" that changes when
      # depending on the deployment tool (gcloud, terraform)
      labels,
      # We feed env vars through our Github deployment pipeline
      environment_variables
    ]
  }
}

resource "google_secret_manager_secret" "cloud_function" {
  secret_id = local.secret_name

  replication {
    automatic = true
  }

  depends_on = [
    google_project_service.secret_manager
  ]
}

resource "google_secret_manager_secret_iam_member" "cloud_function" {
  secret_id = google_secret_manager_secret.cloud_function.secret_id
  role      = "roles/secretmanager.admin"
  member    = "serviceAccount:${google_service_account.cloud_function.email}"

  depends_on = [
    google_project_service.secret_manager
  ]
}

# Activate API
resource "google_project_service" "secret_manager" {
  project = local.project
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}
