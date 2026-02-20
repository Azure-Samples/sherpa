#!/bin/bash
# Waypoint 2.1: Apply Content Safety
# Uses policy fragments for modular, reusable content safety checks
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 2.1: Apply Content Safety"
echo "Using Policy Fragments"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TENANT_ID=$(az account show --query tenantId -o tsv)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)
CONTENT_SAFETY_ENDPOINT=$(azd env get-value CONTENT_SAFETY_ENDPOINT)
MANAGED_IDENTITY_CLIENT_ID=$(azd env get-value MANAGED_IDENTITY_CLIENT_ID)

echo "Deploying:"
echo "  - Named values for Content Safety"
echo "  - Policy fragment: mcp-content-safety"
echo "  - Updated API policies with include-fragment"
echo ""

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/2.1-contentsafety.bicep \
  --parameters apimName="$APIM_NAME" \
               tenantId="$TENANT_ID" \
               mcpAppClientId="$MCP_APP_CLIENT_ID" \
               apimGatewayUrl="$APIM_URL" \
               contentSafetyEndpoint="$CONTENT_SAFETY_ENDPOINT" \
               managedIdentityClientId="$MANAGED_IDENTITY_CLIENT_ID" \
  --output none

echo ""
echo "=========================================="
echo "Content Safety Applied (Fragment-based)"
echo "=========================================="
echo ""
echo "Created:"
echo "  - Named value: content-safety-endpoint"
echo "  - Named value: managed-identity-client-id"
echo "  - Fragment: mcp-content-safety"
echo ""
echo "Benefits:"
echo "  - Reusable across multiple APIs"
echo "  - Update fragment once, applies everywhere"
echo "  - Cleaner, more maintainable policies"
echo ""
