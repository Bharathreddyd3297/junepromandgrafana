# Step 2 - install Prometheus, Alertmanager and Grafana with Helm (about 3 minutes).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-config.ps1"

Write-Host ">> Adding the prometheus-community Helm repository"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
Assert-Ok 'helm repo update'

Write-Host ">> Installing kube-prometheus-stack as release '$RELEASE' in namespace '$MON_NS'"
helm upgrade --install $RELEASE prometheus-community/kube-prometheus-stack `
    --namespace $MON_NS --create-namespace `
    --values "$ROOT_DIR\manifests\monitoring-values.yaml" `
    --wait --timeout 10m
Assert-Ok 'helm install'

Write-Host ">> Monitoring pods:"
kubectl get pods -n $MON_NS
