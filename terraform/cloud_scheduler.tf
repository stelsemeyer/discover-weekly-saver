resource "google_cloud_scheduler_job" "cloud_scheduler" {
  name             = local.name
  schedule         = local.schedule
  time_zone        = "UTC"
  attempt_deadline = "320s"

  http_target {
    http_method = "GET"
    uri         = google_cloudfunctions_function.cloud_function.https_trigger_url

    oidc_token {
      service_account_email = google_service_account.cloud_scheduler.email
    }
  }
}

resource "google_service_account" "cloud_scheduler" {
  account_id = "${local.name}-scheduler"
}

resource "google_cloudfunctions_function_iam_member" "cloud_scheduler" {
  project        = google_cloudfunctions_function.cloud_function.project
  region         = google_cloudfunctions_function.cloud_function.region
  cloud_function = google_cloudfunctions_function.cloud_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.cloud_scheduler.email}"
}
