#!/bin/bash
# Postprovision hook for Camp 2
# Called automatically by azd after infrastructure deployment

set -e

echo ""
echo "=========================================="
echo "Post-provision Configuration"
echo "=========================================="
echo ""

# Get deployment outputs from azd
echo "Loading deployment outputs..."
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP)
LOCATION=$(azd env get-value AZURE_LOCATION)
ACR_NAME=$(azd env get-value AZURE_CONTAINER_REGISTRY_NAME)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL)
APIM_LOCATION=$(azd env get-value APIM_LOCATION)
API_CENTER_NAME=$(azd env get-value API_CENTER_NAME)
API_CENTER_LOCATION=$(azd env get-value API_CENTER_LOCATION)
CONTENT_SAFETY_LOCATION=$(azd env get-value CONTENT_SAFETY_LOCATION)

# Show region adjustments if any
if [ "$APIM_LOCATION" != "$LOCATION" ] || [ "$API_CENTER_LOCATION" != "$LOCATION" ] || [ "$CONTENT_SAFETY_LOCATION" != "$LOCATION" ]; then
    echo ""
    echo "Region adjustments made for service availability:"
    [ "$APIM_LOCATION" != "$LOCATION" ] && echo "  API Management: $LOCATION -> $APIM_LOCATION"
    [ "$API_CENTER_LOCATION" != "$LOCATION" ] && echo "  API Center: $LOCATION -> $API_CENTER_LOCATION"
    [ "$CONTENT_SAFETY_LOCATION" != "$LOCATION" ] && echo "  Content Safety: $LOCATION -> $CONTENT_SAFETY_LOCATION"
fi

echo ""
echo "Configuration:"
echo "  Resource Group: $RG_NAME"
echo "  ACR: $ACR_NAME"
echo "  APIM: $APIM_NAME"
echo "  Gateway URL: $APIM_GATEWAY_URL"
echo ""

echo "=========================================="
echo "Post-provision Complete"
echo "=========================================="
echo ""
echo "Infrastructure deployed successfully!"
echo ""
echo "APIM Gateway URL: $APIM_GATEWAY_URL"
echo ""
echo "Next steps:"
echo ""
echo "  1. Deploy Sherpa MCP Server:"
echo "     ./scripts/1.1-deploy.sh"
echo ""
echo "  2. Follow the waypoint scripts to:"
echo "     - See vulnerabilities (exploit scripts)"
echo "     - Apply fixes (fix scripts)"
echo "     - Validate security (validate scripts)"
echo ""
