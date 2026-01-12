#!/bin/bash
# Waypoint 1.2: Fix - Add OAuth to Trail MCP Server
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.2: Add OAuth to Trail MCP"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TENANT_ID=$(az account show --query tenantId -o tsv)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)

echo "Applying OAuth validation + PRM discovery..."
echo "  Subscription key: Still required (tracking/billing)"
echo "  OAuth token: Now also required (authentication)"
echo ""

# Build bicep to ARM JSON (workaround for CLI issues)
az bicep build --file infra/waypoints/1.2-oauth.bicep --outfile /tmp/trail-oauth.json 2>/dev/null

az deployment group create \
  --resource-group "$RG" \
  --template-file /tmp/trail-oauth.json \
  --parameters apimName="$APIM_NAME" \
               tenantId="$TENANT_ID" \
               mcpAppClientId="$MCP_APP_CLIENT_ID" \
               apimGatewayUrl="$APIM_URL" \
  --output none

echo ""
echo "=========================================="
echo "OAuth Added to Trail MCP Server"
echo "=========================================="
echo ""
echo "PRM Discovery endpoint (RFC 9728):"
echo "  $APIM_URL/.well-known/oauth-protected-resource/trails/mcp"
echo ""
echo "Security now requires BOTH:"
echo "  - Subscription key (which application)"
echo "  - OAuth token (which user)"
echo ""
