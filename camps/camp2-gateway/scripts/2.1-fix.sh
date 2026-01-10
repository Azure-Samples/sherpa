#!/bin/bash
# Waypoint 2.1: Fix - Apply Content Safety
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 2.1: Apply Content Safety"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TENANT_ID=$(az account show --query tenantId -o tsv)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)
CONTENT_SAFETY_ENDPOINT=$(azd env get-value CONTENT_SAFETY_ENDPOINT)

echo "Applying Content Safety configuration..."
echo "  Endpoint: $CONTENT_SAFETY_ENDPOINT"
echo ""

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/2.1-contentsafety.bicep \
  --parameters apimName="$APIM_NAME" \
               tenantId="$TENANT_ID" \
               mcpAppClientId="$MCP_APP_CLIENT_ID" \
               apimGatewayUrl="$APIM_URL" \
               contentSafetyEndpoint="$CONTENT_SAFETY_ENDPOINT" \
  --output none

echo ""
echo "=========================================="
echo "Content Safety Applied"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  - Added llm-content-safety policy"
echo "  - Enabled Prompt Shields"
echo "  - Filtering harmful content categories"
echo ""
echo "Next: Validate the fix"
echo "  ./scripts/2.1-validate.sh"
echo ""
