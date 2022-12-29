locals {
  project                   = "dsdx-io"
  name                      = "dw-saver"
  local_function_source_dir = "../app"
  function_archive_name     = "function.zip"
  secret_name               = "${local.name}-token"
  schedule                  = "0 12 * * 1,3,5" # Run Mon, Wed, Fri at 12pm

  bucket_name = "${local.name}-${random_id.instance_id.hex}"

  repo = "stelsemeyer/discover-weekly-saver"

  alert_email = "s.telsemeyer@gmail.com"

  labels = {
    name = local.name
  }
}

resource "random_id" "instance_id" {
  byte_length = 2
}
