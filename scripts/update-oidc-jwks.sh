#!/usr/bin/env bash
set -euo pipefail

# Refreshes the public service account signing keys served on GitHub Pages
# (oidc/), used by external OIDC consumers such as Tailscale workload identity
# federation. Run after rotating the k3s service account signing key.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

kubectl get --raw /openid/v1/jwks | jq . > "$REPO_ROOT/oidc/openid/v1/jwks.json"
echo "Updated oidc/openid/v1/jwks.json"
