# Step 3 - deploy the demo application and the custom Prometheus rules (about 1 minute).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-config.ps1"

Write-Host ">> Deploying the demo application"
kubectl apply -f "$ROOT_DIR\manifests\demo-app.yaml"
Assert-Ok 'Demo app deployment'

Write-Host ">> Loading custom Prometheus rules"
kubectl apply -f "$ROOT_DIR\manifests\prometheus-rules.yaml"
Assert-Ok 'Prometheus rules'

Write-Host ">> Waiting for podinfo to become ready"
kubectl rollout status deployment/podinfo -n $APP_NS --timeout=180s
Assert-Ok 'podinfo rollout'

kubectl get pods,svc,servicemonitor,prometheusrule -n $APP_NS
