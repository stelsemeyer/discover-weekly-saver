resource "google_service_account" "deployment" {
  account_id = "${local.name}-deployment"
}

# If a pool (and provider) gets deleted, the id cannot be reused for 30 days.
# So when destroying it is recommend to remove state first
# via terraform state rm google_iam_workload_identity_pool.github
resource "google_iam_workload_identity_pool" "deployment" {
  project                   = local.project
  workload_identity_pool_id = "github-pool"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_iam_workload_identity_pool_provider" "deployment" {
  project                            = local.project
  workload_identity_pool_id          = google_iam_workload_identity_pool.deployment.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account_iam_member" "deployment_workload_identity_user" {
  service_account_id = google_service_account.deployment.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.deployment.name}/attribute.repository/${local.repo}"
}

# To deploy cloud function on gh
resource "google_cloudfunctions_function_iam_member" "deployment" {
  project        = google_cloudfunctions_function.cloud_function.project
  region         = google_cloudfunctions_function.cloud_function.region
  cloud_function = google_cloudfunctions_function.cloud_function.name
  role           = "roles/cloudfunctions.developer"
  member         = "serviceAccount:${google_service_account.deployment.email}"
}

resource "google_storage_bucket_iam_member" "deployment_storage_admin" {
  bucket = local.bucket_name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.deployment.email}"

  depends_on = [
    google_storage_bucket_object.cloud_function
  ]
}

resource "google_service_account_iam_member" "deployment_service_acccount_user" {
  service_account_id = google_service_account.deployment.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployment.email}"
}

# To let deployment service account act as cloud function service account on gh
resource "google_service_account_iam_member" "deployment_service_account_impersonation" {
  service_account_id = google_service_account.cloud_function.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployment.email}"
}

# If we want to run the cloud function on the github runner we can give the deployment SA token creation and secrets access
resource "google_service_account_iam_member" "deployment_service_acccount_token_creator" {
  service_account_id = google_service_account.deployment.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.deployment.name}/attribute.repository/${local.repo}"
}

resource "google_secret_manager_secret_iam_member" "deployment" {
  secret_id = google_secret_manager_secret.cloud_function.secret_id
  role      = "roles/secretmanager.admin"
  member    = "serviceAccount:${google_service_account.deployment.email}"

  depends_on = [
    google_project_service.secret_manager
  ]
}
