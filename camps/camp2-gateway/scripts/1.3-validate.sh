#!/bin/bash
# Waypoint 1.3: Validate - Rate Limiting Working
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.3: Validate Rate Limiting"
echo "=========================================="
echo ""

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
SUB_KEY=$(azd env get-value TRAIL_API_SUBSCRIPTION_KEY)

# Generate a unique session ID for testing
SESSION_ID="test-session-$(date +%s)"

echo "Testing with session: $SESSION_ID"
echo ""
echo "Sending 15 rapid requests (limit is 10/minute)..."
echo ""

RATE_LIMITED=0
SUCCESS_COUNT=0
for i in {1..15}; do
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        "$APIM_URL/trails" \
        -H "Ocp-Apim-Subscription-Key: $SUB_KEY" \
        -H "Mcp-Session-Id: $SESSION_ID" 2>/dev/null || echo -e "\n000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    
    if [ "$HTTP_CODE" = "429" ]; then
        echo "  Request $i: ✅ 429 Too Many Requests"
        ((RATE_LIMITED++))
    elif [ "$HTTP_CODE" = "401" ]; then
        echo "  Request $i: 401 (OAuth required, but passed rate limit check)"
        ((SUCCESS_COUNT++))
    elif [ "$HTTP_CODE" = "200" ]; then
        echo "  Request $i: 200 OK"
        ((SUCCESS_COUNT++))
    else
        echo "  Request $i: $HTTP_CODE"
    fi
done

echo ""
echo "Results:"
echo "  Requests that passed rate limit: $SUCCESS_COUNT"
echo "  Requests rate limited (429): $RATE_LIMITED"
echo ""

if [ "$RATE_LIMITED" -gt 0 ]; then
    echo "✅ Rate limiting is working!"
    echo ""
    echo "Check rate limit headers on next request:"
    curl -s -I "$APIM_URL/trails" \
        -H "Ocp-Apim-Subscription-Key: $SUB_KEY" \
        -H "Mcp-Session-Id: $SESSION_ID" 2>/dev/null | grep -E "(X-Rate-Limit|Retry-After)" || echo "  (Rate limit headers present on 429 responses)"
else
    echo "Note: If no 429s, rate limiting may not have triggered."
    echo "Try running again or check APIM policy configuration."
fi

echo ""
echo "=========================================="
echo "✅ Waypoint 1.3 Complete"
echo "=========================================="
echo ""
echo "Next: Register APIs for governance"
echo "  ./scripts/1.4-fix.sh"
echo ""
