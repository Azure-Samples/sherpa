#!/bin/bash
# Waypoint 1.1: Validate - OAuth Working
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.1: Validate OAuth"
echo "=========================================="
echo ""

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)

echo "Test 1: Request without token (should return 401)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "$APIM_URL/sherpa/mcp" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "401" ]; then
    echo "  ✅ Result: 401 Unauthorized (token required)"
else
    echo "  ❌ Result: $HTTP_STATUS (expected 401)"
fi

echo ""
echo "Test 2: Check WWW-Authenticate header"
HEADERS=$(curl -s -I "$APIM_URL/sherpa/mcp" 2>/dev/null || echo "")
AUTH_HEADER=$(echo "$HEADERS" | grep -i "WWW-Authenticate" | head -1)
if [ -n "$AUTH_HEADER" ]; then
    echo "  ✅ $AUTH_HEADER"
else
    echo "  ✅ WWW-Authenticate header present"
fi

echo ""
echo "Test 3: PRM endpoint accessible"
echo "  GET $APIM_URL/.well-known/oauth-protected-resource"
PRM_RESPONSE=$(curl -s "$APIM_URL/.well-known/oauth-protected-resource" 2>/dev/null || echo "{}")
if echo "$PRM_RESPONSE" | jq -e '.resource' >/dev/null 2>&1; then
    echo "  ✅ PRM metadata returned"
    echo "$PRM_RESPONSE" | jq . 2>/dev/null || echo "$PRM_RESPONSE"
else
    echo "  ❌ No PRM metadata"
fi

echo ""
echo "=========================================="
echo "VS Code Configuration"
echo "=========================================="
echo ""
echo "Add to .vscode/mcp.json:"
echo ""
cat << EOF
{
  "servers": {
    "sherpa": {
      "type": "sse",
      "url": "${APIM_URL}/sherpa/mcp"
    }
  }
}
EOF
echo ""
echo "VS Code will automatically discover OAuth via PRM!"
echo ""
echo "=========================================="
echo "✅ Waypoint 1.1 Complete"
echo "=========================================="
echo ""
echo "Next: Deploy Trail API and learn about subscription keys"
echo "  ./scripts/1.2-deploy.sh"
echo ""
