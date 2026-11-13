#!/usr/bin/env bash
# Step 2 - install Prometheus, Alertmanager and Grafana with Helm (about 3 minutes).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

echo ">> Adding the prometheus-community Helm repository"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community

echo ">> Installing kube-prometheus-stack as release '$RELEASE' in namespace '$MON_NS'"
helm upgrade --install "$RELEASE" prometheus-community/kube-prometheus-stack \
  --namespace "$MON_NS" --create-namespace \
  --values "$ROOT_DIR/manifests/monitoring-values.yaml" \
  --wait --timeout 10m

echo ">> Monitoring pods:"
kubectl get pods -n "$MON_NS"
