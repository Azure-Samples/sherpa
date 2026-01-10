#!/bin/bash
# Waypoint 1.1: Fix - Apply OAuth Authentication
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.1: Apply OAuth Authentication"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TENANT_ID=$(az account show --query tenantId -o tsv)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)

echo "Applying OAuth configuration..."
echo "  Tenant ID: $TENANT_ID"
echo "  MCP App: $MCP_APP_CLIENT_ID"
echo ""

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/1.1-oauth.bicep \
  --parameters apimName="$APIM_NAME" \
               tenantId="$TENANT_ID" \
               mcpAppClientId="$MCP_APP_CLIENT_ID" \
               apimGatewayUrl="$APIM_URL" \
  --output none

echo ""
echo "=========================================="
echo "OAuth Authentication Applied"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  - Added validate-azure-ad-token policy"
echo "  - Created PRM metadata endpoint (RFC 9728)"
echo "  - Removed subscription key requirement"
echo ""
echo "PRM Endpoint: $APIM_URL/.well-known/oauth-protected-resource"
echo ""
echo "Next: Validate the fix"
echo "  ./scripts/1.1-validate.sh"
echo ""
