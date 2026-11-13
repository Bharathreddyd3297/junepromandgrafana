# Shared settings for all lab scripts. Override any value by setting an
# environment variable first, e.g.  $env:LOCATION = 'centralindia'

function Get-Setting([string]$Name, [string]$Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($value)) { return $Default }
    return $value
}

function Assert-Ok([string]$What) {
    if ($LASTEXITCODE -ne 0) { throw "$What failed (exit code $LASTEXITCODE)." }
}

$RG        = Get-Setting 'RG'         'rg-promgraf-lab'
$LOCATION  = Get-Setting 'LOCATION'   'eastus'
$CLUSTER   = Get-Setting 'CLUSTER'    'aks-promgraf-lab'
$NODE_COUNT = Get-Setting 'NODE_COUNT' '2'
$NODE_SIZE = Get-Setting 'NODE_SIZE'  'Standard_D2s_v3'

$MON_NS  = 'monitoring'
$RELEASE = 'monitoring'
$APP_NS  = 'demo'

# Folder that contains manifests\ and dashboards\
$ROOT_DIR = Split-Path -Parent $PSScriptRoot
