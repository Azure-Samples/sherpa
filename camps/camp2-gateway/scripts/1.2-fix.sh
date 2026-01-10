#!/bin/bash
# Waypoint 1.2: Fix - Add OAuth to Trail API
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.2: Add OAuth to Trail API"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TENANT_ID=$(az account show --query tenantId -o tsv)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)

echo "Applying OAuth validation policy..."
echo "  Subscription key: Still required"
echo "  OAuth token: Now also required"
echo ""

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/1.2-oauth.bicep \
  --parameters apimName="$APIM_NAME" \
               tenantId="$TENANT_ID" \
               mcpAppClientId="$MCP_APP_CLIENT_ID" \
               apimGatewayUrl="$APIM_URL" \
  --output none

echo ""
echo "=========================================="
echo "OAuth Added to Trail API"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  ✅ Subscription key still required (application identity)"
echo "  ✅ OAuth token now also required (user identity)"
echo "  ✅ Both must be present for access"
echo ""
echo "This demonstrates the hybrid pattern:"
echo "  - Subscription key = which application"
echo "  - OAuth token = which user"
echo ""
echo "Next: Validate both are required"
echo "  ./scripts/1.2-validate.sh"
echo ""
