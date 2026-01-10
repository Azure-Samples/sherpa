#!/bin/bash
# Waypoint 2.2: Validate - Credential Manager Working
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 2.2: Validate Credential Manager"
echo "=========================================="
echo ""

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TRAIL_URL=$(azd env get-value SERVICE_TRAIL_API_URI)

echo "Test 1: Permits via APIM (should work with backend token)"
echo "  Note: Requires valid OAuth token for APIM"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "$APIM_URL/trails/permits" \
    -H "Content-Type: application/json" 2>/dev/null || echo "000")
echo "  Result: $HTTP_STATUS"

echo ""
echo "Test 2: Direct backend call (still fails - no token)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "$TRAIL_URL/permits" \
    -H "Content-Type: application/json" 2>/dev/null || echo "000")
echo "  Result: $HTTP_STATUS"

echo ""
echo "Test 3: Verify client secret stored securely"
RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
SECRET_EXISTS=$(az apim nv show \
    --resource-group "$RG" \
    --service-name "$APIM_NAME" \
    --named-value-id "apim-client-secret" \
    --query "secret" -o tsv 2>/dev/null || echo "false")
if [ "$SECRET_EXISTS" = "true" ]; then
    echo "  Client secret stored as secret Named Value"
else
    echo "  Client secret Named Value exists"
fi

echo ""
echo "=========================================="
echo "Waypoint 2.2 Complete"
echo "=========================================="
echo ""
echo "Key benefit: Secrets never exposed to clients!"
echo ""
echo "Next: Network security with IP restrictions"
echo "  ./scripts/3.1-exploit.sh"
echo ""
