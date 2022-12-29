output "cloud_function_name" {
  value = local.name
}

output "cloud_function_bucket_name" {
  value = google_storage_bucket.cloud_function.name
}

output "cloud_function_url" {
  value = google_cloudfunctions_function.cloud_function.https_trigger_url
}

output "cloud_function_service_account" {
  value = google_service_account.cloud_function.email
}

output "cloud_function_secret_id" {
  value = google_secret_manager_secret.cloud_function.secret_id
}

output "deployment_service_account" {
  value = google_service_account.deployment.email
}

output "workload_identity_provider" {
  value = "${google_iam_workload_identity_pool.deployment.name}/providers/${google_iam_workload_identity_pool_provider.deployment.workload_identity_pool_provider_id}"
}

