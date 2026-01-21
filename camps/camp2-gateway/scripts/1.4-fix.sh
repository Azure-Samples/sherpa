#!/bin/bash
# Waypoint 1.4: Register APIs in API Center
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.4: API Center Registration"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
API_CENTER_NAME=$(azd env get-value API_CENTER_NAME)

echo "Registering MCP servers in API Center..."
echo "  API Center: $API_CENTER_NAME"
echo ""

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/1.4-apicenter.bicep \
  --parameters apiCenterName="$API_CENTER_NAME" \
               apimGatewayUrl="$APIM_URL" \
  --output none

echo ""
echo "=========================================="
echo "API Center Registration Complete"
echo "=========================================="
echo ""
echo "Registered MCP Servers:"
echo "  - Sherpa MCP Server (/sherpa/mcp)"
echo "  - Trails MCP Server (/trails/mcp)"
echo ""
echo "Benefits:"
echo "  ✅ Central MCP server discovery"
echo "  ✅ Prevents shadow MCP servers"
echo "  ✅ Enables governance & compliance"
echo ""
echo "View in Azure Portal:"
echo "  https://portal.azure.com/#@/resource/subscriptions/.../resourceGroups/$RG/providers/Microsoft.ApiCenter/services/$API_CENTER_NAME"
echo ""
echo "=========================================="
echo "✅ Section 1 Complete: Gateway & Governance"
echo "=========================================="
echo ""
echo "Next: Content Safety protection"
echo "  ./scripts/2.1-exploit.sh"
echo ""
