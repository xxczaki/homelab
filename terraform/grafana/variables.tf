variable "grafana_url" {
  description = "Grafana Cloud instance URL"
  type        = string
}

variable "grafana_sa_token" {
  description = "Grafana service account token"
  type        = string
  sensitive   = true
}

variable "oncall_access_token" {
  description = "Grafana OnCall API token"
  type        = string
  sensitive   = true
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for discord-bot alerts"
  type        = string
  sensitive   = true
}

variable "wicek_webhook_token" {
  description = "Bearer token for the wicek /hooks/grafana webhook (GRAFANA_WEBHOOK_TOKEN)"
  type        = string
  sensitive   = true
}
