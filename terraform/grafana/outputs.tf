# Link of the Cluster Heartbeat integration. Sensitive: the link embeds a token.
output "heartbeat_integration_link" {
  description = "Link of the Cluster Heartbeat OnCall integration."
  value       = grafana_oncall_integration.heartbeat.link
  sensitive   = true
}
