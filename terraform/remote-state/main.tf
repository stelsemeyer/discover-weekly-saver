provider "google" {
  project = "dsdx-io"
  region  = "europe-west3"
}

resource "random_id" "instance_id" {
  byte_length = 8
}

resource "google_storage_bucket" "bucket" {
  name     = "disccover-weekly-saver-tf-backend-${random_id.instance_id.hex}"
  location = "EU"

  lifecycle {
    prevent_destroy = true
  }
}
