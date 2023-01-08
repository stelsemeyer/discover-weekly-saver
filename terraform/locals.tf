locals {
  name                      = "dw-saver"
  local_function_source_dir = "../app"
  function_archive_name     = "function.zip"
  secret_name               = "${local.name}-token"
  schedule                  = "0 12 * * 1,3,5"  # Run Mon, Wed, Fri at 12pm

  labels = {
    name = local.name
  }

  bucket_name = "${local.name}-${random_id.instance_id.hex}"
}

resource "random_id" "instance_id" {
  byte_length = 2
}
