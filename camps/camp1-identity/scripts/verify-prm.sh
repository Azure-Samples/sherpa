#!/bin/bash
# Verify Protected Resource Metadata (PRM) endpoint

set -e

echo "=============================================="
echo "Camp 1: Verify PRM Endpoint"
echo "=============================================="
echo ""

# Get secure server URL from environment
SECURE_URL=$(azd env get-values 2>/dev/null | grep SECURE_SERVER_URL | cut -d= -f2 | tr -d '"')

if [ -z "$SECURE_URL" ]; then
    echo "❌ Error: SECURE_SERVER_URL not found"
    echo "   Make sure you've deployed the secure server with 'azd deploy --service secure-server'"
    exit 1
fi

echo "Secure Server URL: $SECURE_URL"
echo ""

# Test PRM endpoint
echo "Testing PRM endpoint..."
echo "GET ${SECURE_URL}/.well-known/oauth-protected-resource"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "${SECURE_URL}/.well-known/oauth-protected-resource")
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" != "200" ]; then
    echo "❌ PRM endpoint returned HTTP $HTTP_STATUS"
    echo ""
    echo "Response:"
    echo "$BODY"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify the secure server is deployed"
    echo "  2. Check that AZURE_TENANT_ID and AZURE_CLIENT_ID are set in the Container App"
    echo "  3. Redeploy with: azd deploy --service secure-server"
    exit 1
fi

echo "✅ PRM endpoint is working!"
echo ""
echo "Response:"
echo "$BODY" | jq .

# Validate JSON structure
RESOURCE=$(echo "$BODY" | jq -r '.resource')
AUTH_SERVER=$(echo "$BODY" | jq -r '.authorization_servers[0]')
SCOPE=$(echo "$BODY" | jq -r '.scopes_supported[0]')

echo ""
echo "=============================================="
echo "PRM Configuration Summary"
echo "=============================================="
echo "Resource:           $RESOURCE"
echo "Authorization Server: $AUTH_SERVER"
echo "Required Scope:     $SCOPE"
echo "Bearer Method:      header"
echo ""

if [[ "$AUTH_SERVER" == *"login.microsoftonline.com"* ]]; then
    echo "✅ Authorization server is Entra ID"
else
    echo "⚠️  Warning: Authorization server doesn't look like Entra ID"
fi

if [[ "$SCOPE" == api://* ]]; then
    echo "✅ Scope format is correct (api://...)"
else
    echo "⚠️  Warning: Scope format unexpected"
fi

echo ""
echo "VS Code can now discover authentication requirements automatically!"
echo ""
echo "Add to .vscode/mcp.json:"
echo "{"
echo "  \"mcpServers\": {"
echo "    \"camp1-secure\": {"
echo "      \"type\": \"sse\","
echo "      \"url\": \"${SECURE_URL}/mcp\""
echo "    }"
echo "  }"
echo "}"
echo ""
echo "=============================================="
