data "grafana_oncall_user" "me" {
  username = "xxczaki"
}

resource "grafana_oncall_integration" "alerting" {
  name = "Grafana Alerting"
  type = "grafana_alerting"

  default_route {
    escalation_chain_id = grafana_oncall_escalation_chain.default.id
  }
}

# --- Escalation chains ---

resource "grafana_oncall_escalation_chain" "default" {
  name = "Default"
}

resource "grafana_oncall_escalation_chain" "critical" {
  name = "Critical"
}

# --- Default chain: notify user ---

resource "grafana_oncall_escalation" "default_notify" {
  escalation_chain_id = grafana_oncall_escalation_chain.default.id
  type                = "notify_persons"
  position            = 0
  persons_to_notify   = [data.grafana_oncall_user.me.id]
}

# --- Critical chain: important notify ---

resource "grafana_oncall_escalation" "critical_notify" {
  escalation_chain_id = grafana_oncall_escalation_chain.critical.id
  type                = "notify_persons"
  position            = 0
  important           = true
  persons_to_notify   = [data.grafana_oncall_user.me.id]
}

# --- Route: severity=critical -> critical chain ---

resource "grafana_oncall_route" "critical" {
  integration_id      = grafana_oncall_integration.alerting.id
  escalation_chain_id = grafana_oncall_escalation_chain.critical.id
  routing_regex       = "\"severity\": \"critical\""
  position            = 0
}
