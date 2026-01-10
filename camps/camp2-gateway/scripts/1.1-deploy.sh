#!/bin/bash
# Waypoint 1.1: Deploy Sherpa MCP Server
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.1: Deploy Sherpa MCP Server"
echo "=========================================="
echo ""

# Deploy the container service
echo "Building and deploying Sherpa MCP Server..."
azd deploy sherpa-mcp-server

# Get environment values
RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
SHERPA_URL=$(azd env get-value SHERPA_SERVER_URL)

echo ""
echo "Configuring APIM backend and API..."

# Deploy APIM configuration via Bicep
az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/1.1-deploy-sherpa.bicep \
  --parameters apimName="$APIM_NAME" \
               backendUrl="${SHERPA_URL}/mcp" \
  --output none

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)

echo ""
echo "=========================================="
echo "Sherpa MCP Server Deployed"
echo "=========================================="
echo ""
echo "Endpoint: $APIM_URL/sherpa/mcp"
echo ""
echo "Current security: NONE (completely open)"
echo ""
echo "Next: See why this is dangerous"
echo "  ./scripts/1.1-exploit.sh"
echo ""
