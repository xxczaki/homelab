#!/usr/bin/env bash
set -euo pipefail

if ! command -v kubeseal 2>&1 >/dev/null; then
    echo "kubeseal is not installed"
    exit 1
fi

sealed_no=0

# Map secret filenames to their sealed output paths
declare -A secret_map=(
  [api-keys-secret.yaml]="apps/openclaw/resources/api-keys-secret.yaml"
  [ha-ssh-sealed-secret.yaml]="apps/openclaw/resources/ha-ssh-sealed-secret.yaml"
  [argo-cd-secret.yaml]="apps/argo-cd/secret.yaml"
  [discord-bot-secret.yaml]="apps/discord-bot/secret.yaml"
  [logs-grafana-k8s-monitoring-secret.yaml]="apps/k8s-monitoring/logs-secret.yaml"
  [metrics-grafana-k8s-monitoring-secret.yaml]="apps/k8s-monitoring/metrics-secret.yaml"
  [traces-grafana-k8s-monitoring-secret.yaml]="apps/k8s-monitoring/traces-secret.yaml"
  [longhorn-backblaze-b2-secret.yaml]="apps/longhorn/backblaze-b2-secret.yaml"
  [tailscale-operator-oauth-secret.yaml]="apps/tailscale/oauth-secret.yaml"
)

for path in secrets/*.yaml; do
  [[ -f "$path" ]] || continue
  filename=$(basename "$path")

  output="${secret_map[$filename]:-}"
  if [[ -z "$output" ]]; then
    echo "Warning: no output mapping for $filename, skipping"
    continue
  fi

  kubeseal -f "$path" -w "$output"
  ((sealed_no++))
done

echo "Successfully sealed $sealed_no file(s)"