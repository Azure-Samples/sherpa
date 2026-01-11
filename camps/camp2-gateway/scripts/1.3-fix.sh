#!/bin/bash
# Waypoint 1.3: Fix - Apply Rate Limiting
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.3: Apply Rate Limiting"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)

echo "Applying rate limiting to Trail API..."
echo "  Rate: 10 requests per minute per subscription key"
echo ""

az deployment group create \
  --resource-group "$RG" \
  --template-file infra/waypoints/1.3-ratelimit.bicep \
  --parameters apimName="$APIM_NAME" \
  --output none

echo ""
echo "=========================================="
echo "Rate Limiting Applied"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  ✅ Added rate-limit-by-key policy to Trail API"
echo "  ✅ Limited to 10 requests/minute per subscription key"
echo "  ✅ Returns 429 when quota exceeded"
echo ""
echo "Next: Validate rate limiting works"
echo "  ./scripts/1.3-validate.sh"
echo ""
