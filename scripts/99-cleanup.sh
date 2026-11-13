#!/usr/bin/env bash
# Delete EVERYTHING created by this lab (the resource group and the AKS cluster in it).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"

read -r -p "Delete resource group '$RG' and everything in it? (y/N) " answer
if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
  echo "Cancelled."
  exit 0
fi

az group delete --name "$RG" --yes --no-wait
kubectl config delete-context "$CLUSTER" 2>/dev/null || true
echo "Deletion started. It finishes in the background in a few minutes."
