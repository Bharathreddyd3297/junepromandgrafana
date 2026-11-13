#!/usr/bin/env bash
# Step 4 (option A) - reach the UIs from your laptop with port-forwarding.
# Run this on your LAPTOP (it does not work from Azure Cloud Shell - use
# 05-expose-loadbalancer.sh there). Leave it running; Ctrl+C stops it.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

trap 'kill $(jobs -p) 2>/dev/null || true' EXIT

kubectl -n "$MON_NS" port-forward "svc/$RELEASE-grafana" 3000:80 >/dev/null &
kubectl -n "$MON_NS" port-forward "svc/$RELEASE-kube-prometheus-prometheus" 9090:9090 >/dev/null &
kubectl -n "$MON_NS" port-forward "svc/$RELEASE-kube-prometheus-alertmanager" 9093:9093 >/dev/null &
kubectl -n "$APP_NS" port-forward svc/podinfo 9898:9898 >/dev/null &

cat <<EOF

  Grafana       http://localhost:3000   (admin / PromGraf-Lab-2026)
  Prometheus    http://localhost:9090
  Alertmanager  http://localhost:9093
  Demo app      http://localhost:9898

  Press Ctrl+C to stop port-forwarding.
EOF

wait
