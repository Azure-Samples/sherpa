#!/bin/bash
# Configure APIM Credential Manager for backend authentication

set -e

echo "=========================================="
echo "Configuring APIM Credential Manager"
echo "=========================================="

# Check required variables
if [ -z "$APIM_NAME" ] || [ -z "$RG_NAME" ] || [ -z "$APIM_CLIENT_APP_ID" ] || [ -z "$APIM_CLIENT_SECRET" ]; then
    echo "Error: Required variables not set"
    echo "Required: APIM_NAME, RG_NAME, APIM_CLIENT_APP_ID, APIM_CLIENT_SECRET"
    exit 1
fi

# Create named value for APIM client ID
echo "Creating named value for APIM client ID..."
az apim nv create \
    --resource-group "$RG_NAME" \
    --service-name "$APIM_NAME" \
    --named-value-id "apim-client-id" \
    --display-name "apim-client-id" \
    --value "$APIM_CLIENT_APP_ID" \
    --secret false

# Create named value for APIM client secret
echo "Creating named value for APIM client secret..."
az apim nv create \
    --resource-group "$RG_NAME" \
    --service-name "$APIM_NAME" \
    --named-value-id "apim-client-secret" \
    --display-name "apim-client-secret" \
    --value "$APIM_CLIENT_SECRET" \
    --secret true

echo ""
echo "Credential Manager configuration complete"
