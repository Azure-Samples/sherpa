#!/bin/bash
# Post-provision hook for Camp 2
# Called automatically by azd after infrastructure deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=========================================="
echo "Running post-provision configuration..."
echo "=========================================="

# Get deployment outputs from azd
echo "Loading deployment outputs..."
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP)
LOCATION=$(azd env get-value AZURE_LOCATION)
ACR_NAME=$(azd env get-value AZURE_CONTAINER_REGISTRY_NAME)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL)
APIM_LOCATION=$(azd env get-value APIM_LOCATION)
API_CENTER_NAME=$(azd env get-value API_CENTER_NAME)
API_CENTER_LOCATION=$(azd env get-value API_CENTER_LOCATION)
CONTENT_SAFETY_LOCATION=$(azd env get-value CONTENT_SAFETY_LOCATION)

# Show region adjustments if any
if [ "$APIM_LOCATION" != "$LOCATION" ] || [ "$API_CENTER_LOCATION" != "$LOCATION" ] || [ "$CONTENT_SAFETY_LOCATION" != "$LOCATION" ]; then
    echo ""
    echo "ℹ️  Region adjustments made for service availability:"
    [ "$APIM_LOCATION" != "$LOCATION" ] && echo "   • API Management: $LOCATION → $APIM_LOCATION"
    [ "$API_CENTER_LOCATION" != "$LOCATION" ] && echo "   • API Center: $LOCATION → $API_CENTER_LOCATION"
    [ "$CONTENT_SAFETY_LOCATION" != "$LOCATION" ] && echo "   • Content Safety: $LOCATION → $CONTENT_SAFETY_LOCATION"
fi

export RG_NAME ACR_NAME APIM_NAME APIM_GATEWAY_URL API_CENTER_NAME

# Load Entra ID app IDs from environment
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)
APIM_CLIENT_APP_ID=$(azd env get-value APIM_CLIENT_APP_ID)
APIM_CLIENT_SECRET=$(azd env get-value APIM_CLIENT_SECRET)

export MCP_APP_CLIENT_ID APIM_CLIENT_APP_ID APIM_CLIENT_SECRET

echo ""
echo "Configuration loaded:"
echo "  Resource Group: $RG_NAME"
echo "  ACR: $ACR_NAME"
echo "  APIM: $APIM_NAME"
echo "  Gateway URL: $APIM_GATEWAY_URL"
echo ""

# Update Entra ID redirect URI with actual APIM gateway URL
if [ -n "$MCP_APP_CLIENT_ID" ] && [ -n "$APIM_GATEWAY_URL" ]; then
    echo "Updating Entra ID redirect URI..."
    az ad app update --id "$MCP_APP_CLIENT_ID" \
        --web-redirect-uris "$APIM_GATEWAY_URL/auth/callback" 2>/dev/null || \
        echo "Note: Could not update redirect URI. You may need to update it manually in the Azure Portal."
fi

echo ""
echo "=========================================="
echo "Post-provision configuration complete!"
echo "=========================================="
echo ""
echo "🎉 Camp 2 deployment successful!"
echo ""
echo "📍 APIM Gateway URL: $APIM_GATEWAY_URL"
echo "📍 Sherpa MCP Server: $APIM_GATEWAY_URL/sherpa-mcp/mcp"
echo "📍 Trail MCP Server: $APIM_GATEWAY_URL/trail-mcp/mcp"
echo ""
echo "📋 Next steps:"
echo "1. Configure VS Code MCP settings with the gateway URL above"
echo "2. OAuth will be discovered automatically via PRM"
echo "3. Run tests: cd tests && ./test-oauth-flow.sh"
echo ""
echo "📚 For detailed instructions, see:"
echo "   https://azure-samples.github.io/sherpa/camps/camp2-gateway/"
