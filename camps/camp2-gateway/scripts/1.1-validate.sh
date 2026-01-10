#!/bin/bash
# Waypoint 1.1: Validate - OAuth Working
# 
# Validates that OAuth is properly configured:
# 1. Requests without token return 401
# 2. WWW-Authenticate header includes resource_metadata
# 3. Both PRM discovery paths work (RFC 9728 + suffix)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.1: Validate OAuth"
echo "=========================================="
echo ""

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
ALL_PASSED=true

echo "Test 1: Request without token (should return 401)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "$APIM_URL/sherpa/mcp" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "401" ]; then
    echo "  ✅ Result: 401 Unauthorized (token required)"
else
    echo "  ❌ Result: $HTTP_STATUS (expected 401)"
    ALL_PASSED=false
fi

echo ""
echo "Test 2: Check WWW-Authenticate header has correct resource_metadata"
AUTH_HEADER=$(curl -s -I "$APIM_URL/sherpa/mcp" 2>/dev/null | grep -i "WWW-Authenticate" | head -1)
if echo "$AUTH_HEADER" | grep -q "sherpa/mcp"; then
    echo "  ✅ WWW-Authenticate includes /sherpa/mcp path"
else
    echo "  ❌ WWW-Authenticate missing /sherpa/mcp path"
    echo "  Header: $AUTH_HEADER"
    ALL_PASSED=false
fi

echo ""
echo "Test 3: Check 401 response body has correct resource_metadata"
BODY=$(curl -s "$APIM_URL/sherpa/mcp" 2>/dev/null)
if echo "$BODY" | grep -q "sherpa/mcp"; then
    echo "  ✅ Response body includes /sherpa/mcp path"
else
    echo "  ❌ Response body missing /sherpa/mcp path"
    echo "  Body: $BODY"
    ALL_PASSED=false
fi

echo ""
echo "Test 4: RFC 9728 path-based PRM discovery"
echo "  GET $APIM_URL/.well-known/oauth-protected-resource/sherpa/mcp"
PRM_RFC=$(curl -s "$APIM_URL/.well-known/oauth-protected-resource/sherpa/mcp" 2>/dev/null || echo "{}")
if echo "$PRM_RFC" | jq -e '.resource' >/dev/null 2>&1; then
    echo "  ✅ RFC 9728 PRM metadata returned"
    echo "$PRM_RFC" | jq . 2>/dev/null || echo "$PRM_RFC"
else
    echo "  ❌ RFC 9728 PRM not accessible"
    ALL_PASSED=false
fi

echo ""
echo "Test 5: Suffix pattern PRM discovery"
echo "  GET $APIM_URL/sherpa/mcp/.well-known/oauth-protected-resource"
PRM_SUFFIX=$(curl -s "$APIM_URL/sherpa/mcp/.well-known/oauth-protected-resource" 2>/dev/null || echo "{}")
if echo "$PRM_SUFFIX" | jq -e '.resource' >/dev/null 2>&1; then
    echo "  ✅ Suffix PRM metadata returned"
else
    echo "  ❌ Suffix PRM not accessible"
    ALL_PASSED=false
fi

echo ""
if [ "$ALL_PASSED" = true ]; then
    echo "=========================================="
    echo "✅ Waypoint 1.1 Complete"
    echo "=========================================="
    echo ""
    echo "OAuth is properly configured. VS Code can now:"
    echo "  1. Discover PRM at either discovery path"
    echo "  2. Find the Entra ID authorization server"
    echo "  3. Obtain tokens and call the MCP API"
    echo ""
    echo "Next: Deploy Trail API and learn about subscription keys"
    echo "  ./scripts/1.2-deploy.sh"
else
    echo "=========================================="
    echo "❌ Waypoint 1.1 Validation Failed"
    echo "=========================================="
    echo ""
    echo "Some tests failed. Review the output above."
fi
echo ""
