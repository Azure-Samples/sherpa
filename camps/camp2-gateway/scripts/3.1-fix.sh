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
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)

echo "Note: APIM Basic v2 Limitation"
echo "------------------------------"
echo ""
echo "APIM Basic v2 does not have static outbound IPs."
echo "This demo uses the current IP, which may change."
echo ""
echo "For production, consider:"
echo "  - APIM Standard v2 with VNet integration"
echo "  - Private Endpoints for full network isolation"
echo "  - Header-based validation (X-Azure-FDID)"
echo ""

# Get APIM IP by resolving the gateway hostname
echo "Resolving APIM gateway IP..."
APIM_HOST=$(echo "$APIM_URL" | sed 's|https://||' | sed 's|http://||' | sed 's|/.*||')
APIM_IP=$(dig +short "$APIM_HOST" A | grep -E '^[0-9]+\.' | head -1)

if [ -z "$APIM_IP" ]; then
    echo "Error: Could not resolve APIM IP address"
    exit 1
fi

echo "APIM Gateway: $APIM_HOST"
echo "APIM IP: $APIM_IP"
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
    echo "Configuring: $SHERPA_CA"
    
    # Allow APIM IP (everything else is implicitly denied)
    az containerapp ingress access-restriction set \
        --resource-group "$RG" \
        --name "$SHERPA_CA" \
        --rule-name "allow-apim" \
        --action "Allow" \
        --ip-address "$APIM_IP/32" \
        --description "Allow APIM gateway" \
        --output none
    
    echo "  ✓ Allow APIM ($APIM_IP)"
    echo "  ✓ All other IPs implicitly denied"
fi

if [ -n "$TRAIL_CA" ]; then
    echo "Configuring: $TRAIL_CA"
    
    # Allow APIM IP (everything else is implicitly denied)
    az containerapp ingress access-restriction set \
        --resource-group "$RG" \
        --name "$TRAIL_CA" \
        --rule-name "allow-apim" \
        --action "Allow" \
        --ip-address "$APIM_IP/32" \
        --description "Allow APIM gateway" \
        --output none
    
    echo "  ✓ Allow APIM ($APIM_IP)"
    echo "  ✓ All other IPs implicitly denied"
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
