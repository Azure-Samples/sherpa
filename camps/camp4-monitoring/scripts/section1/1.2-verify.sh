#!/bin/bash
# =============================================================================
# Camp 4 - Section 1.2: Verify APIM Diagnostic Configuration
# =============================================================================
# This script verifies that APIM diagnostic settings are properly configured.
# Diagnostic settings are deployed via Bicep infrastructure, not manually.
#
# This script shows you:
# - What diagnostic settings are configured
# - What log categories are enabled
# - Where logs are being sent
# - How to verify the configuration in Azure Portal
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Camp 4 - Section 1.2: Verify APIM Diagnostics${NC}"
echo -e "${CYAN}  Understanding diagnostic settings configuration${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Load environment
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
APIM_NAME=$(azd env get-value APIM_NAME 2>/dev/null)
WORKSPACE_ID=$(azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>/dev/null)
WORKSPACE_NAME=$(azd env get-value LOG_ANALYTICS_WORKSPACE_NAME 2>/dev/null)

if [ -z "$APIM_NAME" ] || [ -z "$WORKSPACE_ID" ]; then
    echo -e "${RED}Error: Missing required environment values. Run 'azd up' first.${NC}"
    exit 1
fi

# Get the full resource ID for APIM
APIM_RESOURCE_ID=$(az apim show \
    --name "$APIM_NAME" \
    --resource-group "$RG_NAME" \
    --query id -o tsv)

echo -e "${BLUE}Checking APIM diagnostic settings...${NC}"
echo ""

# Get diagnostic settings details
DIAG_JSON=$(az monitor diagnostic-settings list \
    --resource "$APIM_RESOURCE_ID" \
    -o json 2>/dev/null) || DIAG_JSON="[]"

DIAG_COUNT=$(echo "$DIAG_JSON" | jq 'length')

if [ "$DIAG_COUNT" = "0" ]; then
    echo -e "${RED}✗ No diagnostic settings found!${NC}"
    echo ""
    echo "  This is unexpected - diagnostic settings should be deployed via Bicep."
    echo ""
    echo -e "${YELLOW}Possible causes:${NC}"
    echo "  1. Bicep deployment didn't complete successfully"
    echo "  2. Diagnostic settings were manually deleted"
    echo "  3. Using an older version of the workshop that doesn't pre-configure diagnostics"
    echo ""
    echo -e "${YELLOW}To fix:${NC}"
    echo "  Run 'azd up' to redeploy infrastructure"
    echo ""
    exit 1
fi

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Diagnostic Settings Configuration${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Parse and display each diagnostic setting
echo "$DIAG_JSON" | jq -r '.[] | "Setting: \(.name)"' | while read -r line; do
    echo -e "${GREEN}$line${NC}"
done
echo ""

# Get the first (and typically only) diagnostic setting details
SETTING_NAME=$(echo "$DIAG_JSON" | jq -r '.[0].name')
DEST_TYPE=$(echo "$DIAG_JSON" | jq -r '.[0].logAnalyticsDestinationType // "AzureDiagnostics"')
WORKSPACE=$(echo "$DIAG_JSON" | jq -r '.[0].workspaceId | split("/")[-1]')
ENABLED_LOGS=$(echo "$DIAG_JSON" | jq -r '.[0].logs[] | select(.enabled == true) | .category')
ENABLED_METRICS=$(echo "$DIAG_JSON" | jq -r '.[0].metrics[] | select(.enabled == true) | .category')

echo -e "${YELLOW}Destination Type:${NC} $DEST_TYPE"
if [ "$DEST_TYPE" = "Dedicated" ]; then
    echo -e "  ${GREEN}✓${NC} Using resource-specific tables (recommended)"
    echo "    Logs go to: ApiManagementGatewayLogs, ApiManagementGatewayLlmLog"
else
    echo -e "  ${YELLOW}⚠${NC} Using legacy AzureDiagnostics table"
    echo "    Consider migrating to Dedicated mode for better query performance"
fi
echo ""

echo -e "${YELLOW}Log Analytics Workspace:${NC} $WORKSPACE"
echo ""

echo -e "${YELLOW}Enabled Log Categories:${NC}"
echo "$ENABLED_LOGS" | while read -r cat; do
    [ -n "$cat" ] && echo -e "  ${GREEN}✓${NC} $cat"
done
echo ""

echo -e "${YELLOW}Enabled Metrics:${NC}"
echo "$ENABLED_METRICS" | while read -r met; do
    [ -n "$met" ] && echo -e "  ${GREEN}✓${NC} $met"
done
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  APIM Internal Diagnostics${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

echo -e "${BLUE}Checking APIM azuremonitor logger...${NC}"
LOGGER_EXISTS=$(az rest --method GET \
    --uri "${APIM_RESOURCE_ID}/loggers/azuremonitor?api-version=2022-08-01" \
    --query "properties.loggerType" -o tsv 2>/dev/null) || LOGGER_EXISTS=""

if [ "$LOGGER_EXISTS" = "azureMonitor" ]; then
    echo -e "  ${GREEN}✓${NC} azuremonitor logger configured"
else
    echo -e "  ${YELLOW}⚠${NC} azuremonitor logger not found (may affect log flow)"
fi

echo -e "${BLUE}Checking APIM azuremonitor diagnostic...${NC}"
DIAG_SAMPLING=$(az rest --method GET \
    --uri "${APIM_RESOURCE_ID}/diagnostics/azuremonitor?api-version=2022-08-01" \
    --query "properties.sampling.percentage" -o tsv 2>/dev/null) || DIAG_SAMPLING=""
DIAG_CLIENT_IP=$(az rest --method GET \
    --uri "${APIM_RESOURCE_ID}/diagnostics/azuremonitor?api-version=2022-08-01" \
    --query "properties.logClientIp" -o tsv 2>/dev/null) || DIAG_CLIENT_IP=""

if [ -n "$DIAG_SAMPLING" ]; then
    echo -e "  ${GREEN}✓${NC} azuremonitor diagnostic configured"
    echo "    Sampling: ${DIAG_SAMPLING}%"
    echo "    Log Client IP: ${DIAG_CLIENT_IP}"
else
    echo -e "  ${YELLOW}⚠${NC} azuremonitor diagnostic not found"
    echo "    This may cause logs to not flow to ApiManagementGatewayLogs"
fi
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Log Tables Available${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo -e "${YELLOW}1. ApiManagementGatewayLogs${NC} (HTTP request details)"
echo "   - CallerIpAddress   - Who made the request"
echo "   - ResponseCode      - HTTP response code"
echo "   - CorrelationId     - For cross-service tracing"
echo "   - Url, Method       - Request path and HTTP method"
echo "   - ApiId             - API identifier for filtering"
echo ""
echo -e "${YELLOW}2. ApiManagementGatewayLlmLog${NC} (AI/LLM gateway)"
echo "   - PromptTokens      - Input token count"
echo "   - CompletionTokens  - Output token count"
echo "   - ModelName         - LLM model used"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  How to Verify in Azure Portal${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "1. Go to your APIM resource in Azure Portal"
echo "2. Navigate to: Monitoring -> Diagnostic settings"
echo "3. You should see: mcp-security-logs"
echo "4. Click to view enabled categories and destination"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Sample KQL Query${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "Run this in Log Analytics to see recent traffic:"
echo ""
echo -e "${YELLOW}  ApiManagementGatewayLogs"
echo "  | where TimeGenerated > ago(1h)"
echo "  | where ApiId contains 'mcp' or ApiId contains 'sherpa'"
echo "  | project TimeGenerated, CallerIpAddress, Method, ResponseCode, ApiId"
echo "  | order by TimeGenerated desc"
echo -e "  | limit 20${NC}"
echo ""

echo -e "${GREEN}Diagnostic settings verification complete!${NC}"
echo ""
echo -e "${YELLOW}Note on Log Ingestion Delay:${NC}"
echo "  Azure Monitor logs have a 2-5 minute ingestion delay."
echo "  For new deployments, the first logs may take 5-10 minutes."
echo ""
echo -e "${GREEN}Next: Run ./scripts/section1/1.3-validate.sh to query logs${NC}"
