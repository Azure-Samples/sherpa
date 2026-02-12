#!/bin/bash
# ==============================================================================
# Camp 3: Get MCP Token (Device Code Flow)
# ==============================================================================
# Gets an OAuth token for authenticating with the Trails MCP server through APIM.
# Use this token in the trails-mcp.http file or with curl commands.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "🎫 Camp 3: Get MCP Token (Device Code Flow)"
echo "==========================================="

# Load azd environment variables
echo "📦 Loading azd environment..."
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null)
AZURE_TENANT_ID=$(azd env get-value AZURE_TENANT_ID 2>/dev/null)
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL 2>/dev/null)

# Check for required environment variables
if [ -z "${MCP_APP_CLIENT_ID}" ]; then
    echo "❌ Error: MCP_APP_CLIENT_ID not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

if [ -z "${AZURE_TENANT_ID}" ]; then
    echo "❌ Error: AZURE_TENANT_ID not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

echo "MCP App Client ID: ${MCP_APP_CLIENT_ID}"
echo "Tenant ID: ${AZURE_TENANT_ID}"
echo "APIM Gateway: ${APIM_GATEWAY_URL}"
echo ""
echo "🔐 Acquiring access token..."
echo "You may be prompted to authenticate in your browser."
echo ""

# Get token for the MCP application
TOKEN=$(az account get-access-token \
    --resource "${MCP_APP_CLIENT_ID}" \
    --query accessToken -o tsv 2>&1)

if [ $? -ne 0 ] || [ -z "${TOKEN}" ]; then
    echo ""
    echo "❌ Failed to acquire token"
    echo "${TOKEN}"
    exit 1
fi

echo ""
echo "✅ Token acquired successfully!"
echo ""
echo "Your access token:"
echo ""
echo "${TOKEN}"
echo ""
echo "💡 Tip: Decode this token at https://jwt.ms to see the claims inside (aud, iss, exp, scp, etc.)"
echo ""
echo "⚠️  Note: Tokens expire after ~1 hour. Run this script again to get a fresh token."
echo ""
