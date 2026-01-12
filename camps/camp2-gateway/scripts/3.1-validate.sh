#!/bin/bash
# Waypoint 3.1: Validate - IP Restrictions Working
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 3.1: Validate IP Restrictions"
echo "=========================================="
echo ""

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
SHERPA_URL=$(azd env get-value SHERPA_SERVER_URL)
TRAIL_URL=$(azd env get-value TRAIL_API_URL)

echo "Test 1: Direct call to Sherpa (should be blocked)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 \
    "$SHERPA_URL/mcp" 2>/dev/null || echo "000")
echo "  Direct: $HTTP_STATUS"
if [ "$HTTP_STATUS" = "403" ] || [ "$HTTP_STATUS" = "000" ]; then
    echo "  Result: Blocked"
else
    echo "  Result: Still accessible (see note below)"
fi

echo ""
echo "Test 2: Direct call to Trail API (should be blocked)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 \
    "$TRAIL_URL/" 2>/dev/null || echo "000")
echo "  Direct: $HTTP_STATUS"
if [ "$HTTP_STATUS" = "403" ] || [ "$HTTP_STATUS" = "000" ]; then
    echo "  Result: Blocked"
else
    echo "  Result: Still accessible (see note below)"
fi

echo ""
echo "Test 3: Via APIM (should still work through gateway controls)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "$APIM_URL/trailapi/trails" 2>/dev/null || echo "000")
echo "  Via APIM: $HTTP_STATUS (expect 401/200 depending on auth)"

echo ""
echo "=========================================="
echo "Workshop Limitation Note"
echo "=========================================="
echo ""
echo "APIM Basic v2 doesn't have static IPs, so full IP-based"
echo "restrictions require APIM Standard v2 with VNet integration."
echo ""
echo "See docs/network-concepts.md for production patterns."
echo ""
echo "=========================================="
echo "Camp 2 Complete: Gateway Security"
echo "=========================================="
echo ""
echo "Security controls implemented:"
echo "  1.1 Sherpa MCP deployed"
echo "  1.2 OAuth for MCP"
echo "  1.3 Rate Limiting"
echo "  1.4 API Center governance"
echo "  2.1 Content Safety filtering"
echo "  3.1 Network isolation (demo)"
echo ""
echo "For more information:"
echo "  - docs/network-concepts.md"
echo "  - docs/read-write-patterns.md"
echo ""
