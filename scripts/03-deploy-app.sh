#!/usr/bin/env bash
# Step 3 - deploy the demo application and the custom Prometheus rules (about 1 minute).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

echo ">> Deploying the demo application"
kubectl apply -f "$ROOT_DIR/manifests/demo-app.yaml"

echo ">> Loading custom Prometheus rules"
kubectl apply -f "$ROOT_DIR/manifests/prometheus-rules.yaml"

echo ">> Waiting for podinfo to become ready"
kubectl rollout status deployment/podinfo -n "$APP_NS" --timeout=180s

kubectl get pods,svc,servicemonitor,prometheusrule -n "$APP_NS"
