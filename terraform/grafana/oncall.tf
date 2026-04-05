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

# --- Default chain: notify team ---

resource "grafana_oncall_escalation" "default_notify" {
  escalation_chain_id = grafana_oncall_escalation_chain.default.id
  type                = "notify_team_members"
  position            = 0
}

# --- Critical chain: important notify ---

resource "grafana_oncall_escalation" "critical_notify" {
  escalation_chain_id = grafana_oncall_escalation_chain.critical.id
  type                = "notify_team_members"
  position            = 0
  important           = true
}

# --- Route: severity=critical -> critical chain ---

resource "grafana_oncall_route" "critical" {
  integration_id      = grafana_oncall_integration.alerting.id
  escalation_chain_id = grafana_oncall_escalation_chain.critical.id
  routing_regex       = "\"severity\": \"critical\""
  position            = 0
}
