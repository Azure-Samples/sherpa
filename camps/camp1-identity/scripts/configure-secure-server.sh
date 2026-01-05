#!/bin/bash
set -e

echo "🔧 Camp 1: Configure Secure Server"
echo "==================================="

# Load azd environment variables
echo "📦 Loading azd environment..."
eval "$(azd env get-values | sed 's/^/export /')"

# Verify we have the necessary variables
if [ -z "${AZURE_CLIENT_ID}" ]; then
    echo "❌ Error: AZURE_CLIENT_ID not found in azd environment."
    echo "Make sure you've run 'azd env set AZURE_CLIENT_ID <your-client-id>' first."
    exit 1
fi

if [ -z "${SECURE_SERVER_NAME}" ]; then
    echo "❌ Error: SECURE_SERVER_NAME not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

echo "Updating secure server: ${SECURE_SERVER_NAME}"
echo "Setting AZURE_CLIENT_ID to: ${AZURE_CLIENT_ID}"
echo ""

# Update the Container App with the correct client ID
az containerapp update \
    --name "${SECURE_SERVER_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --set-env-vars AZURE_CLIENT_ID="${AZURE_CLIENT_ID}" \
    --output none

echo ""
echo "✅ Secure server configured!"
echo "The Container App now uses your Entra ID application client ID for JWT validation."
