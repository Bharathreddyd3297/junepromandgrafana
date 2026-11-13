# Step 4 (option B) - expose Grafana, Prometheus and Alertmanager on public IPs.
#
#   .\scripts\05-expose-loadbalancer.ps1 203.0.113.10   # only this IP may connect (recommended)
#   .\scripts\05-expose-loadbalancer.ps1 any            # open to the internet (short demos only)
#
# Find your public IP by opening https://ifconfig.me in a browser.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Allow
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-config.ps1"

$helmArgs = @(
    'upgrade', '--install', $RELEASE, 'prometheus-community/kube-prometheus-stack',
    '--namespace', $MON_NS,
    '--values', "$ROOT_DIR\manifests\monitoring-values.yaml",
    '--values', "$ROOT_DIR\manifests\monitoring-values-loadbalancer.yaml",
    '--wait', '--timeout', '10m'
)

if ($Allow -eq 'any') {
    Write-Warning 'Prometheus and Alertmanager have no login and will be open to the internet.'
}
else {
    $cidr = "$Allow/32"
    Write-Host ">> Restricting access to $cidr"
    $helmArgs += @(
        '--set', "grafana.service.loadBalancerSourceRanges={$cidr}",
        '--set', "prometheus.service.loadBalancerSourceRanges={$cidr}",
        '--set', "alertmanager.service.loadBalancerSourceRanges={$cidr}"
    )
}

& helm @helmArgs
Assert-Ok 'helm upgrade'

function Get-LbIp([string]$Service) {
    $ip = kubectl -n $MON_NS get svc $Service -o "jsonpath={.status.loadBalancer.ingress[0].ip}"
    if ([string]::IsNullOrEmpty($ip)) { return '<pending>' }
    return $ip
}

Write-Host ">> Waiting for Azure to assign public IPs (1-2 minutes)"
foreach ($i in 1..40) {
    $g = Get-LbIp "$RELEASE-grafana"
    $p = Get-LbIp "$RELEASE-kube-prometheus-prometheus"
    $a = Get-LbIp "$RELEASE-kube-prometheus-alertmanager"
    if (@($g, $p, $a) -notcontains '<pending>') { break }
    Start-Sleep -Seconds 5
}

Write-Host ''
Write-Host "  Grafana       http://$g        (admin / PromGraf-Lab-2026)"
Write-Host "  Prometheus    http://${p}:9090"
Write-Host "  Alertmanager  http://${a}:9093"
Write-Host ''
Write-Host "  If an address shows <pending>, run:  kubectl get svc -n $MON_NS"
