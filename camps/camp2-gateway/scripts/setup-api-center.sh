#!/bin/bash
# Set up API Center with MCP server metadata

set -e

echo "=========================================="
echo "Setting up API Center"
echo "=========================================="

# Check required variables
if [ -z "$API_CENTER_NAME" ] || [ -z "$RG_NAME" ] || [ -z "$APIM_GATEWAY_URL" ]; then
    echo "Error: API_CENTER_NAME, RG_NAME, and APIM_GATEWAY_URL must be set"
    exit 1
fi

echo "Registering Sherpa MCP Server in API Center..."
az apic api create \
    --resource-group "$RG_NAME" \
    --service-name "$API_CENTER_NAME" \
    --api-id "sherpa-mcp-server" \
    --title "Sherpa MCP Server" \
    --type "rest" \
    --description "Mountain climbing assistance MCP server"

az apic api version create \
    --resource-group "$RG_NAME" \
    --service-name "$API_CENTER_NAME" \
    --api-id "sherpa-mcp-server" \
    --version-id "v1-0" \
    --title "v1.0" \
    --lifecycle-stage "production"

# Note: Deployment and environment setup can be done via Azure Portal if needed

echo "Registering Trail MCP Server in API Center..."
az apic api create \
    --resource-group "$RG_NAME" \
    --service-name "$API_CENTER_NAME" \
    --api-id "trail-mcp-server" \
    --title "Trail MCP Server" \
    --type "rest" \
    --description "Trail information MCP server"

az apic api version create \
    --resource-group "$RG_NAME" \
    --service-name "$API_CENTER_NAME" \
    --api-id "trail-mcp-server" \
    --version-id "v1-0" \
    --title "v1.0" \
    --lifecycle-stage "production"

# Note: Deployment and environment setup can be done via Azure Portal if needed

echo ""
echo "✓ API Center setup complete"
echo "  APIs registered: Sherpa MCP Server, Trail MCP Server"
