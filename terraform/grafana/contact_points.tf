resource "grafana_contact_point" "oncall" {
  name = "Grafana OnCall"

  oncall {
    url = grafana_oncall_integration.alerting.link
  }
}

resource "grafana_contact_point" "discord" {
  name = "Discord"

  discord {
    url     = var.discord_webhook_url
    message = <<-EOT
      {{ range .Alerts }}
      **{{ .Status | toUpper }}** {{ .Labels.alertname }}
      {{ .Annotations.summary }}
      {{ end }}
    EOT
  }
}
