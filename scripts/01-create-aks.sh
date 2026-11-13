#!/usr/bin/env bash
# Step 1 - create a 2-node AKS cluster and connect kubectl to it (about 5 minutes).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

echo ">> Subscription in use:"
az account show --query "{name:name, id:id}" -o table

echo ">> Creating resource group $RG in $LOCATION"
az group create --name "$RG" --location "$LOCATION" -o none

echo ">> Creating AKS cluster $CLUSTER ($NODE_COUNT x $NODE_SIZE) - takes about 5 minutes"
az aks create \
  --resource-group "$RG" \
  --name "$CLUSTER" \
  --node-count "$NODE_COUNT" \
  --node-vm-size "$NODE_SIZE" \
  --tier free \
  --generate-ssh-keys \
  -o none

echo ">> Fetching kubeconfig"
az aks get-credentials --resource-group "$RG" --name "$CLUSTER" --overwrite-existing

echo ">> Cluster nodes:"
kubectl get nodes -o wide
