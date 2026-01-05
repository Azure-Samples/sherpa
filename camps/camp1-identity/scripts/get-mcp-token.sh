#!/bin/bash
set -e

echo "🎫 Camp 1: Get MCP Token (Device Code Flow)"
echo "==========================================="

# Load azd environment variables
echo "📦 Loading azd environment..."
eval "$(azd env get-values | sed 's/^/export /')"

# Check for required environment variables
if [ -z "${AZURE_CLIENT_ID}" ]; then
    echo "❌ Error: AZURE_CLIENT_ID not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

if [ -z "${AZURE_TENANT_ID}" ]; then
    echo "❌ Error: AZURE_TENANT_ID not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

echo "Client ID: ${AZURE_CLIENT_ID}"
echo "Tenant ID: ${AZURE_TENANT_ID}"
echo ""
echo "🔐 Acquiring access token..."
echo "You may be prompted to authenticate in your browser."
echo ""

# Get token for the Entra ID application
# The scope "api://{CLIENT_ID}/access_as_user" requests delegated permissions
TOKEN=$(az account get-access-token \
    --resource "api://${AZURE_CLIENT_ID}" \
    --scope "api://${AZURE_CLIENT_ID}/access_as_user" \
    --query accessToken -o tsv 2>&1)

if [ $? -ne 0 ] || [ -z "${TOKEN}" ]; then
    echo ""
    echo "❌ Failed to acquire token"
    echo "${TOKEN}"
    exit 1
fi

if [ -z "${TOKEN}" ]; then
    echo "❌ Failed to acquire token"
    exit 1
fi

echo ""
echo "✅ Token acquired successfully!"
echo ""
echo "📋 Add this to your MCP client configuration (mcp.json):"
echo ""
echo "{"
echo '  "mcpServers": {'
echo '    "camp1-secure": {'
echo '      "url": "https://your-container-app.azurecontainerapps.io/mcp",'
echo '      "transport": "streamable-http",'
echo "      \"headers\": {"
echo "        \"Authorization\": \"Bearer ${TOKEN}\""
echo "      }"
echo "    }"
echo "  }"
echo "}"
echo ""
echo "⚠️  Note: Tokens expire! You'll need to refresh periodically."
