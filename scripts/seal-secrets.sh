#!/usr/bin/env bash
set -euo pipefail

if ! command -v kubeseal 2>&1 >/dev/null; then
    echo "kubeseal is not installed"
    exit 1
fi

sealed_no=0

# Seal secrets destined for resources/
for path in secrets/*.yaml; do
  [[ -f "$path" ]] || continue
  filename=$(basename "$path")

  # OpenClaw secrets go to openclaw/, not resources/
  case "$filename" in
    api-keys-secret.yaml)
      kubeseal -f "$path" -w openclaw/api-keys-secret.yaml
      ;;
    ha-ssh-sealed-secret.yaml)
      kubeseal -f "$path" -w openclaw/ha-ssh-sealed-secret.yaml
      ;;
    *)
      kubeseal -f "$path" -w "resources/$filename"
      ;;
  esac
  ((sealed_no++))
done

echo "Successfully sealed $sealed_no file(s)"