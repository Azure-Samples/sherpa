#!/bin/bash
# Test OAuth flow with PRM discovery

set -e

echo "=========================================="
echo "Testing OAuth Flow with PRM Discovery"
echo "=========================================="

# Check required variables
if [ -z "$APIM_GATEWAY_URL" ]; then
    echo "Error: APIM_GATEWAY_URL must be set"
    exit 1
fi

echo "Step 1: Discover OAuth configuration via PRM..."
PRM_URL="$APIM_GATEWAY_URL/.well-known/oauth-protected-resource"
echo "Fetching PRM metadata from: $PRM_URL"

curl -v "$PRM_URL"

echo ""
echo ""
echo "Step 2: Get authorization endpoint from discovery..."
AUTH_SERVER=$(curl -s "$PRM_URL" | jq -r '.authorization_servers[0]')
echo "Authorization server: $AUTH_SERVER"

OPENID_CONFIG_URL="$AUTH_SERVER/.well-known/openid-configuration"
echo "Fetching OpenID configuration from: $OPENID_CONFIG_URL"

curl -s "$OPENID_CONFIG_URL" | jq .

echo ""
echo ""
echo "=========================================="
echo "OAuth Discovery Testing Complete"
echo "=========================================="
echo ""
echo "To complete OAuth flow:"
echo "1. Configure VS Code MCP settings with APIM gateway URL"
echo "2. VS Code will discover OAuth endpoints via PRM"
echo "3. VS Code will initiate OAuth flow automatically"
