#!/bin/bash
# Postprovision hook for Camp 4
# Called automatically by azd after infrastructure deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

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
CONTENT_SAFETY_ENDPOINT=$(azd env get-value CONTENT_SAFETY_ENDPOINT)
CONTENT_SAFETY_LOCATION=$(azd env get-value CONTENT_SAFETY_LOCATION)
FUNCTION_APP_NAME=$(azd env get-value FUNCTION_APP_NAME)
FUNCTION_APP_URL=$(azd env get-value FUNCTION_APP_URL)
SHERPA_SERVER_URL=$(azd env get-value SHERPA_SERVER_URL)
TRAIL_API_URL=$(azd env get-value TRAIL_API_URL)

# Show region adjustments if any
if [ "$APIM_LOCATION" != "$LOCATION" ] || [ "$CONTENT_SAFETY_LOCATION" != "$LOCATION" ]; then
    echo ""
    echo "Region adjustments made for service availability:"
    [ "$APIM_LOCATION" != "$LOCATION" ] && echo "  API Management: $LOCATION -> $APIM_LOCATION"
    [ "$CONTENT_SAFETY_LOCATION" != "$LOCATION" ] && echo "  Content Safety: $LOCATION -> $CONTENT_SAFETY_LOCATION"
fi

# Load Entra ID app IDs from environment
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)
TENANT_ID=$(azd env get-value AZURE_TENANT_ID 2>/dev/null || az account show --query tenantId -o tsv)

echo ""
echo "Configuration:"
echo "  Resource Group: $RG_NAME"
echo "  ACR: $ACR_NAME"
echo "  APIM: $APIM_NAME"
echo "  Gateway URL: $APIM_GATEWAY_URL"
echo "  Function App: $FUNCTION_APP_NAME"
echo "  Function URL: $FUNCTION_APP_URL"
echo "  Sherpa Server: $SHERPA_SERVER_URL"
echo "  Trail API: $TRAIL_API_URL"
echo "  Tenant ID: $TENANT_ID"
echo "  MCP App Client ID: $MCP_APP_CLIENT_ID"
echo ""

# Configure APIM APIs and backends with full I/O security (Layer 1 + 2)
echo "Configuring APIM APIs with full security..."
az deployment group create \
    --resource-group "$RG_NAME" \
    --template-file infra/waypoints/initial-api-setup.bicep \
    --parameters \
        apimName="$APIM_NAME" \
        sherpaServerUrl="$SHERPA_SERVER_URL" \
        trailApiUrl="$TRAIL_API_URL" \
        contentSafetyEndpoint="$CONTENT_SAFETY_ENDPOINT" \
        tenantId="$TENANT_ID" \
        mcpAppClientId="$MCP_APP_CLIENT_ID" \
        functionAppUrl="$FUNCTION_APP_URL" \
    --output none

echo "APIM APIs configured with Layer 1 + Layer 2 security"

# Update Entra ID redirect URI with actual APIM gateway URL
if [ -n "$MCP_APP_CLIENT_ID" ] && [ -n "$APIM_GATEWAY_URL" ]; then
    echo "Updating Entra ID redirect URI..."
    az ad app update --id "$MCP_APP_CLIENT_ID" \
        --web-redirect-uris "$APIM_GATEWAY_URL/auth/callback" 2>/dev/null || \
        echo "Note: Could not update redirect URI. You may need to update it manually."
fi

echo ""
echo "=========================================="
echo "Post-provision Complete"
echo "=========================================="
echo ""
echo "Infrastructure deployed successfully!"
echo ""
echo "Camp 4: Monitoring & Telemetry"
echo "=============================="
echo ""
echo "What's deployed:"
echo "  - APIM with full I/O security (Layer 1 + Layer 2)"
echo "  - Sherpa MCP Server (Container App)"
echo "  - Trail API with PII endpoint (Container App)"
echo "  - Security Function (wired to APIM)"
echo "  - Log Analytics workspace (not yet connected to APIM)"
echo ""
echo "Security layers enabled:"
echo "  - Layer 1: OAuth + Content Safety (on MCP APIs)"
echo "  - Layer 2: Security Function (input validation + output sanitization)"
echo ""
echo "The monitoring gap:"
echo "  APIM diagnostic settings are NOT configured."
echo "  Security events are happening but NOT being logged."
echo ""
echo "Next steps (Section 1: The Blind Spot):"
echo ""
echo "  1. Demonstrate the monitoring gap:"
echo "     ./scripts/section1/1.1-exploit.sh"
echo ""
echo "  2. Enable APIM diagnostics:"
echo "     ./scripts/section1/1.2-fix.sh"
echo ""
echo "  3. Validate logging is working:"
echo "     ./scripts/section1/1.3-validate.sh"
echo ""
