#!/usr/bin/env bash
# Step 4 (option B) - expose Grafana, Prometheus and Alertmanager on public IPs.
#
#   ./scripts/05-expose-loadbalancer.sh 203.0.113.10   # only this IP may connect (recommended)
#   ./scripts/05-expose-loadbalancer.sh any            # open to the internet (short demos only)
#
# Find your laptop's public IP by opening https://ifconfig.me in a browser.
# Do not detect it from Cloud Shell - that returns the Cloud Shell IP, not yours.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

ALLOW="${1:-}"
if [[ -z "$ALLOW" ]]; then
  echo "Usage: $0 <your-public-ip | any>" >&2
  exit 1
fi

EXTRA=()
if [[ "$ALLOW" == "any" ]]; then
  echo "!! WARNING: Prometheus and Alertmanager have no login and will be open to the internet."
else
  CIDR="$ALLOW/32"
  echo ">> Restricting access to $CIDR"
  EXTRA=(
    --set "grafana.service.loadBalancerSourceRanges={$CIDR}"
    --set "prometheus.service.loadBalancerSourceRanges={$CIDR}"
    --set "alertmanager.service.loadBalancerSourceRanges={$CIDR}"
  )
fi

helm upgrade --install "$RELEASE" prometheus-community/kube-prometheus-stack \
  --namespace "$MON_NS" \
  --values "$ROOT_DIR/manifests/monitoring-values.yaml" \
  --values "$ROOT_DIR/manifests/monitoring-values-loadbalancer.yaml" \
  "${EXTRA[@]}" \
  --wait --timeout 10m

get_ip() {
  kubectl -n "$MON_NS" get svc "$1" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true
}

echo ">> Waiting for Azure to assign public IPs (1-2 minutes)"
for _ in $(seq 1 40); do
  G="$(get_ip "$RELEASE-grafana")"
  P="$(get_ip "$RELEASE-kube-prometheus-prometheus")"
  A="$(get_ip "$RELEASE-kube-prometheus-alertmanager")"
  if [[ -n "$G" && -n "$P" && -n "$A" ]]; then break; fi
  sleep 5
done

cat <<EOF

  Grafana       http://${G:-<pending>}        (admin / PromGraf-Lab-2026)
  Prometheus    http://${P:-<pending>}:9090
  Alertmanager  http://${A:-<pending>}:9093

  If an address shows <pending>, run:  kubectl get svc -n $MON_NS
EOF
