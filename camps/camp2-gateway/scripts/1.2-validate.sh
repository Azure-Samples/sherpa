#!/bin/bash
# Waypoint 1.2: Validate - Hybrid Authentication Working
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.2: Validate Trail MCP Security"
echo "=========================================="
echo ""

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
SUB_KEY=$(azd env get-value TRAIL_SUBSCRIPTION_KEY)

echo "Test 1: No credentials (should fail)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APIM_URL/trails/mcp" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "401" ]; then
    echo "  Result: 401 Unauthorized (needs subscription key)"
else
    echo "  Result: $HTTP_STATUS (expected 401)"
fi

echo ""
echo "Test 2: Subscription key only (should fail - needs OAuth)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APIM_URL/trails/mcp" \
    -H "Ocp-Apim-Subscription-Key: $SUB_KEY" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "401" ]; then
    echo "  Result: 401 Unauthorized (OAuth also required)"
else
    echo "  Result: $HTTP_STATUS (expected 401)"
fi

echo ""
echo "Test 3: Check WWW-Authenticate header"
RESPONSE=$(curl -s -D - "$APIM_URL/trails/mcp" -H "Ocp-Apim-Subscription-Key: $SUB_KEY" 2>/dev/null || echo "")
AUTH_HEADER=$(echo "$RESPONSE" | grep -i "WWW-Authenticate" | head -1)
if [ -n "$AUTH_HEADER" ]; then
    echo "  WWW-Authenticate header present"
    echo "  $AUTH_HEADER" | sed 's/^/  /'
else
    echo "  No WWW-Authenticate header"
fi

echo ""
echo "Test 4: RFC 9728 PRM discovery"
echo "  GET $APIM_URL/.well-known/oauth-protected-resource/trails/mcp"
PRM_RESPONSE=$(curl -s "$APIM_URL/.well-known/oauth-protected-resource/trails/mcp" 2>/dev/null)
if echo "$PRM_RESPONSE" | grep -q "authorization_servers"; then
    echo "  PRM metadata returned correctly"
    echo "$PRM_RESPONSE" | jq . 2>/dev/null | sed 's/^/  /' || echo "$PRM_RESPONSE" | sed 's/^/  /'
else
    echo "  PRM endpoint not returning expected metadata"
    echo "  Response: $PRM_RESPONSE"
fi

echo ""
echo "=========================================="
echo "Waypoint 1.2 Complete"
echo "=========================================="
echo ""
echo "Trail MCP Server now requires:"
echo "  - Subscription key (for tracking/billing)"
echo "  - OAuth token (for authentication)"
echo ""
