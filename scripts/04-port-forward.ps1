# Step 4 (option A) - reach the UIs from your laptop with port-forwarding.
# Leave this window open; press Ctrl+C to stop.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-config.ps1"

$forwards = @(
    @('-n', $MON_NS, 'port-forward', "svc/$RELEASE-grafana", '3000:80'),
    @('-n', $MON_NS, 'port-forward', "svc/$RELEASE-kube-prometheus-prometheus", '9090:9090'),
    @('-n', $MON_NS, 'port-forward', "svc/$RELEASE-kube-prometheus-alertmanager", '9093:9093'),
    @('-n', $APP_NS, 'port-forward', 'svc/podinfo', '9898:9898')
)

$procs = @()
try {
    foreach ($f in $forwards) {
        $procs += Start-Process -FilePath 'kubectl' -ArgumentList $f -WindowStyle Hidden -PassThru
    }

    Write-Host ''
    Write-Host '  Grafana       http://localhost:3000   (admin / PromGraf-Lab-2026)'
    Write-Host '  Prometheus    http://localhost:9090'
    Write-Host '  Alertmanager  http://localhost:9093'
    Write-Host '  Demo app      http://localhost:9898'
    Write-Host ''
    Write-Host '  Press Ctrl+C to stop port-forwarding.'

    while ($true) {
        Start-Sleep -Seconds 5
        $dead = @($procs | Where-Object { $_.HasExited })
        if ($dead.Count -gt 0) {
            Write-Warning 'A port-forward stopped (pod restarted or connection dropped). Run this script again.'
            break
        }
    }
}
finally {
    $procs | Where-Object { -not $_.HasExited } | Stop-Process -Force
}
