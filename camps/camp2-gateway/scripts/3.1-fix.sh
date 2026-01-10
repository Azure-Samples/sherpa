#!/bin/bash
# Waypoint 3.1: Fix - Apply IP Restrictions
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 3.1: Apply IP Restrictions"
echo "=========================================="
echo ""

RG=$(azd env get-value AZURE_RESOURCE_GROUP)

echo "Note: APIM Basic v2 Limitation"
echo "------------------------------"
echo ""
echo "APIM Basic v2 does not have static outbound IPs."
echo "For production, consider:"
echo "  - APIM Standard v2 with VNet integration"
echo "  - Private Endpoints for full network isolation"
echo "  - Header-based validation (X-Azure-FDID)"
echo ""

echo "Applying Container Apps IP restrictions..."
echo ""

# Get Container App names
SHERPA_CA=$(az containerapp list \
    --resource-group "$RG" \
    --query "[?contains(name, 'sherpa')].name" -o tsv 2>/dev/null | head -1)
TRAIL_CA=$(az containerapp list \
    --resource-group "$RG" \
    --query "[?contains(name, 'trail')].name" -o tsv 2>/dev/null | head -1)

if [ -n "$SHERPA_CA" ]; then
    echo "Sherpa Container App: $SHERPA_CA"
    
    # For workshop demonstration, we'll add a restrictive rule
    # In production, you'd use the actual APIM IPs or VNet
    az containerapp ingress access-restriction set \
        --resource-group "$RG" \
        --name "$SHERPA_CA" \
        --rule-name "deny-direct-access" \
        --action "Deny" \
        --ip-address "0.0.0.0/0" \
        --description "Block direct access - route through APIM" \
        --output none 2>/dev/null || echo "  Note: Access restriction requires Premium tier"
fi

if [ -n "$TRAIL_CA" ]; then
    echo "Trail Container App: $TRAIL_CA"
    
    az containerapp ingress access-restriction set \
        --resource-group "$RG" \
        --name "$TRAIL_CA" \
        --rule-name "deny-direct-access" \
        --action "Deny" \
        --ip-address "0.0.0.0/0" \
        --description "Block direct access - route through APIM" \
        --output none 2>/dev/null || echo "  Note: Access restriction requires Premium tier"
fi

echo ""
echo "=========================================="
echo "IP Restrictions Applied (Workshop Demo)"
echo "=========================================="
echo ""
echo "For production environments, see:"
echo "  docs/network-concepts.md"
echo ""
echo "Options for full network isolation:"
echo "  1. APIM Standard v2 + VNet integration"
echo "  2. Private Endpoints"
echo "  3. Azure Front Door + header validation"
echo ""
echo "Next: Validate the fix"
echo "  ./scripts/3.1-validate.sh"
echo ""
