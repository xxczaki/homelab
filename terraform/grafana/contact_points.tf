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

# Wicek triages newly firing alerts (cluster, Alloy, network) and DMs the findings.
resource "grafana_contact_point" "wicek" {
  name = "Wicek"

  webhook {
    url                       = "https://wicek-webhooks.tail12a84.ts.net/hooks/grafana"
    authorization_scheme      = "Bearer"
    authorization_credentials = var.wicek_webhook_token
  }
}
