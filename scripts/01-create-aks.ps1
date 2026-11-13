# Step 1 - create a 2-node AKS cluster and connect kubectl to it (about 5 minutes).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\00-config.ps1"

Write-Host ">> Subscription in use:"
az account show --query "{name:name, id:id}" -o table
Assert-Ok 'az account show (run "az login" first)'

Write-Host ">> Creating resource group $RG in $LOCATION"
az group create --name $RG --location $LOCATION -o none
Assert-Ok 'Resource group creation'

Write-Host ">> Creating AKS cluster $CLUSTER ($NODE_COUNT x $NODE_SIZE) - takes about 5 minutes"
az aks create `
    --resource-group $RG `
    --name $CLUSTER `
    --node-count $NODE_COUNT `
    --node-vm-size $NODE_SIZE `
    --tier free `
    --generate-ssh-keys `
    -o none
Assert-Ok 'AKS cluster creation'

Write-Host ">> Fetching kubeconfig"
az aks get-credentials --resource-group $RG --name $CLUSTER --overwrite-existing
Assert-Ok 'az aks get-credentials'

Write-Host ">> Cluster nodes:"
kubectl get nodes -o wide
