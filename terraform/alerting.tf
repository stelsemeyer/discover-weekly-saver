resource "google_logging_metric" "alert" {
  count = local.alert_email != "" ? 1 : 0

  name = local.name

  filter = <<-EOT
    resource.type="cloud_function"
    resource.labels.function_name="${local.name}"
    severity="DEBUG"
    "finished with status: 'crash'"
    OR
    "finished with status: 'error'"
    OR
    "finished with status: 'timeout'"
    OR
    "finished with status: 'connection error'"
    EOT

  label_extractors = {
    "function_name" = "EXTRACT(resource.labels.function_name)"
  }
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key        = "function_name"
      value_type = "STRING"
    }
  }
}

resource "google_monitoring_alert_policy" "alert" {
  count = local.alert_email != "" ? 1 : 0

  display_name = local.name
  combiner     = "OR"

  notification_channels = [
    google_monitoring_notification_channel.alert[0].id
  ]

  conditions {
    display_name = local.name
    condition_threshold {
      filter     = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.alert[0].id}\" resource.type=\"cloud_function\""
      duration   = "0s"
      comparison = "COMPARISON_GT"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
      trigger {
        count   = 1
        percent = 0
      }
    }
  }
}

resource "google_monitoring_notification_channel" "alert" {
  count = local.alert_email != "" ? 1 : 0

  display_name = local.name
  type         = "email"
  labels = {
    email_address = local.alert_email
  }
}
