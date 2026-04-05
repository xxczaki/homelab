resource "grafana_notification_policy" "default" {
  group_by      = ["alertname", "namespace"]
  contact_point = grafana_contact_point.oncall.name

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  policy {
    matcher {
      label = "namespace"
      match = "="
      value = "discord-bot"
    }
    contact_point = grafana_contact_point.discord.name
    continue      = true
  }
}
