#!/bin/bash
# Waypoint 1.3: Fix - Apply Rate Limiting
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.3: Apply Rate Limiting"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TENANT_ID=$(az account show --query tenantId -o tsv)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)

echo "Applying rate limiting configuration..."
echo "  Rate: 10 requests per minute per MCP session"
echo "  Key: Mcp-Session-Id header"
echo ""

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/1.3-ratelimit.bicep \
  --parameters apimName="$APIM_NAME" \
               tenantId="$TENANT_ID" \
               mcpAppClientId="$MCP_APP_CLIENT_ID" \
               apimGatewayUrl="$APIM_URL" \
  --output none

echo ""
echo "=========================================="
echo "Rate Limiting Applied"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  ✅ Added rate-limit-by-key policy to both APIs"
echo "  ✅ Limited to 10 requests/minute per MCP session"
echo "  ✅ Keyed by Mcp-Session-Id header"
echo "  ✅ Returns 429 when quota exceeded"
echo ""
echo "Next: Validate rate limiting works"
echo "  ./scripts/1.3-validate.sh"
echo ""
