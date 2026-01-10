#!/bin/bash
# Waypoint 1.2: Validate - Hybrid Authentication Working
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.2: Validate Hybrid Auth"
echo "=========================================="
echo ""

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
SUB_KEY=$(azd env get-value TRAIL_API_SUBSCRIPTION_KEY)

echo "Test 1: Request with subscription key only (should fail)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APIM_URL/trails" \
    -H "Ocp-Apim-Subscription-Key: $SUB_KEY" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "401" ]; then
    echo "  ✅ Result: 401 (OAuth token also required)"
else
    echo "  ❌ Result: $HTTP_STATUS (expected 401)"
fi

echo ""
echo "Test 2: Request with neither credential (should fail)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APIM_URL/trails" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "401" ]; then
    echo "  ✅ Result: 401 (credentials required)"
else
    echo "  ❌ Result: $HTTP_STATUS (expected 401)"
fi

echo ""
echo "Test 3: Check WWW-Authenticate header"
HEADERS=$(curl -s -I "$APIM_URL/trails" 2>/dev/null || echo "")
AUTH_HEADER=$(echo "$HEADERS" | grep -i "WWW-Authenticate" | head -1)
if [ -n "$AUTH_HEADER" ]; then
    echo "  ✅ WWW-Authenticate header present"
else
    echo "  ❌ No WWW-Authenticate header"
fi

echo ""
echo "=========================================="
echo "✅ Waypoint 1.2 Complete"
echo "=========================================="
echo ""
echo "Key Learnings:"
echo "  • Subscription keys identify applications, not users"
echo "  • OAuth tokens provide user identity"
echo "  • Hybrid pattern: subscription key + OAuth"
echo "  • REST APIs commonly use both"
echo ""
echo "Next: Add rate limiting"
echo "  ./scripts/1.3-deploy.sh"
echo ""
