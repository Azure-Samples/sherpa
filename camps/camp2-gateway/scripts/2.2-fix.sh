#!/bin/bash
# Waypoint 2.2: Fix - Apply Credential Manager
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 2.2: Apply Credential Manager"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TENANT_ID=$(az account show --query tenantId -o tsv)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)
APIM_CLIENT_APP_ID=$(azd env get-value APIM_CLIENT_APP_ID)
APIM_CLIENT_SECRET=$(azd env get-value APIM_CLIENT_SECRET)
CONTENT_SAFETY_ENDPOINT=$(azd env get-value CONTENT_SAFETY_ENDPOINT)
TRAIL_URL=$(azd env get-value SERVICE_TRAIL_API_URI)

echo "Applying Credential Manager configuration..."
echo "  APIM Client App: $APIM_CLIENT_APP_ID"
echo ""

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/2.2-credentialmanager.bicep \
  --parameters apimName="$APIM_NAME" \
               tenantId="$TENANT_ID" \
               mcpAppClientId="$MCP_APP_CLIENT_ID" \
               apimClientAppId="$APIM_CLIENT_APP_ID" \
               apimClientSecret="$APIM_CLIENT_SECRET" \
               apimGatewayUrl="$APIM_URL" \
               contentSafetyEndpoint="$CONTENT_SAFETY_ENDPOINT" \
               trailApiUrl="$TRAIL_URL" \
  --output none

echo ""
echo "=========================================="
echo "Credential Manager Applied"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  - Stored client secret in APIM Named Values"
echo "  - Added get-authorization-context policy"
echo "  - APIM obtains backend tokens automatically"
echo ""
echo "Next: Validate the fix"
echo "  ./scripts/2.2-validate.sh"
echo ""
