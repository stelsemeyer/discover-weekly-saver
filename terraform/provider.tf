provider "google" {
  project = var.gcp_project_id
  region  = "europe-west3"
  zone    = "europe-west3-a"
}

terraform {
  backend "gcs" {
    bucket = "disccover-weekly-saver-tf-backend-52efdddc6fd5349e"
  }
}
