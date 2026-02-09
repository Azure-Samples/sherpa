#!/bin/bash
# Waypoint 1.1: Fix - Apply OAuth Authentication
# 
# This script configures OAuth protection for the Sherpa MCP API:
# 1. Adds Entra ID token validation
# 2. Creates RFC 9728 Protected Resource Metadata (PRM) endpoints
# 3. Removes subscription key requirement
#
# Key learnings:
# - VS Code discovers PRM via suffix path: /{api-path}/.well-known/oauth-protected-resource
# - PRM must return BEFORE OAuth validation (uses <return-response> before <base />)
# - 401 responses must include resource_metadata in both header AND body
# - APIM native MCP type auto-prepends API path to resource_metadata in WWW-Authenticate header
# - Entra app must have empty identifierUris for VS Code MCP OAuth to work

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
echo "  - Created PRM metadata endpoints (RFC 9728)"
echo "  - Removed subscription key requirement"
echo ""
echo "PRM Endpoints (both work for discovery):"
echo "  RFC 9728: $APIM_URL/.well-known/oauth-protected-resource/sherpa/mcp"
echo "  Suffix:   $APIM_URL/sherpa/mcp/.well-known/oauth-protected-resource"
echo ""
echo "Next: Validate the fix"
echo "  ./scripts/1.1-validate.sh"
echo ""
