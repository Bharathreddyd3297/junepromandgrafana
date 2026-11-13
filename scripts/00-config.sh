#!/usr/bin/env bash
# Shared settings for all lab scripts. Override any value by exporting it first,
# e.g.  LOCATION=centralindia ./scripts/01-create-aks.sh

export RG="${RG:-rg-promgraf-lab}"
export LOCATION="${LOCATION:-eastus}"
export CLUSTER="${CLUSTER:-aks-promgraf-lab}"
export NODE_COUNT="${NODE_COUNT:-2}"
export NODE_SIZE="${NODE_SIZE:-Standard_D2s_v3}"

export MON_NS="monitoring"
export RELEASE="monitoring"
export APP_NS="demo"

# Folder that contains manifests/ and dashboards/
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR
