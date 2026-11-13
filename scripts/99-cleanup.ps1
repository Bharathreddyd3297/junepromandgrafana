# Delete EVERYTHING created by this lab (the resource group and the AKS cluster in it).
param([switch]$Yes)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-config.ps1"

if (-not $Yes) {
    Write-Host "This deletes resource group '$RG' and everything in it."
    Write-Host "Re-run with -Yes to confirm:  .\scripts\99-cleanup.ps1 -Yes"
    return
}

az group delete --name $RG --yes --no-wait
Assert-Ok 'az group delete'
kubectl config delete-context $CLUSTER
Write-Host 'Deletion started. It finishes in the background in a few minutes.'
