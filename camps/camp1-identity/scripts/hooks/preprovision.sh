#!/bin/bash
# Preprovision hook for Camp 1
# Generates a unique resource suffix to avoid soft-delete conflicts

set -e

echo ""
echo "=========================================="
echo "Camp 1: Pre-provision Setup"
echo "=========================================="
echo ""

# ============================================
# Generate unique resource suffix
# ============================================
# This suffix is generated once per environment and stored.
# - Re-running azd up uses the same suffix (idempotent)
# - Deleting .azure/ folder and starting fresh generates a new suffix
#   (avoids soft-delete conflicts with Key Vault and other services)
if [ -z "$RESOURCE_SUFFIX" ]; then
    # Generate a 5-character alphanumeric suffix
    RESOURCE_SUFFIX=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 5)
    echo "Generated new resource suffix: $RESOURCE_SUFFIX"
    azd env set RESOURCE_SUFFIX "$RESOURCE_SUFFIX"
else
    echo "Using existing resource suffix: $RESOURCE_SUFFIX"
fi

# Sync AZURE_LOCATION with resource group location if RG already exists
# This ensures Bicep uses the same location as the resource group
if [ -n "$AZURE_RESOURCE_GROUP" ]; then
    RG_LOCATION=$(az group show -n "$AZURE_RESOURCE_GROUP" --query location -o tsv 2>/dev/null || echo "")
    if [ -n "$RG_LOCATION" ] && [ "$RG_LOCATION" != "$AZURE_LOCATION" ]; then
        echo "Syncing AZURE_LOCATION to resource group location: $RG_LOCATION"
        azd env set AZURE_LOCATION "$RG_LOCATION"
        export AZURE_LOCATION="$RG_LOCATION"
    fi
fi

echo ""
echo "Pre-provision complete. Resource suffix: $RESOURCE_SUFFIX"
echo ""
