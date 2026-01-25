#!/bin/bash
# =============================================================================
# Camp 4 - Section 1.2: Enable APIM Diagnostic Settings
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: HIDDEN → VISIBLE
#
# This script enables Azure Monitor diagnostic settings on APIM to capture:
# - ApiManagementGatewayLogs: All HTTP requests with caller IP, response codes
#
# After running this, all MCP traffic will be logged to Log Analytics.
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
echo -e "${CYAN}  Camp 4 - Section 1.2: Enable APIM Diagnostics${NC}"
echo -e "${CYAN}  Pattern: hidden → visible → actionable${NC}"
echo -e "${CYAN}  Transition: HIDDEN → VISIBLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Load environment
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
APIM_NAME=$(azd env get-value APIM_NAME 2>/dev/null)
WORKSPACE_ID=$(azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>/dev/null)

if [ -z "$APIM_NAME" ] || [ -z "$WORKSPACE_ID" ]; then
    echo -e "${RED}Error: Missing required environment values. Run 'azd up' first.${NC}"
    exit 1
fi

echo -e "${YELLOW}What we're doing:${NC}"
echo "1. Creating diagnostic settings on APIM"
echo "2. Enabling ApiManagementGatewayLogs (HTTP request details)"
echo "3. Sending logs to Log Analytics workspace"
echo ""

# Get the full resource ID for APIM
APIM_RESOURCE_ID=$(az apim show \
    --name "$APIM_NAME" \
    --resource-group "$RG_NAME" \
    --query id -o tsv)

# Check if diagnostic settings already exist
EXISTING=$(az monitor diagnostic-settings list \
    --resource "$APIM_RESOURCE_ID" \
    --query "[?name=='mcp-security-logs'].name" -o tsv 2>/dev/null) || true

if [ -n "$EXISTING" ]; then
    echo -e "${YELLOW}Diagnostic settings 'mcp-security-logs' already exist. Updating...${NC}"
fi

echo -e "${BLUE}Creating/updating diagnostic settings...${NC}"

# Create diagnostic settings with all MCP-relevant log categories
# 
# Available Log Categories:
# - GatewayLogs -> ApiManagementGatewayLogs: All HTTP requests, IPs, response codes
# - GatewayLlmLogs -> ApiManagementGatewayLlmLog: LLM/AI token usage, model info
# - WebSocketConnectionLogs -> ApiManagementWebSocketConnectionLogs: WebSocket events
# - DeveloperPortalAuditLogs -> APIMDevPortalAuditDiagnosticLog: Portal activity

# First, try with all available log categories including GatewayLlmLogs for AI monitoring
# Use --export-to-resource-specific to get dedicated tables (e.g., ApiManagementGatewayLogs)
# instead of the legacy AzureDiagnostics table
echo -e "${BLUE}Attempting to enable all log categories with dedicated tables...${NC}"

if az monitor diagnostic-settings create \
    --name "mcp-security-logs" \
    --resource "$APIM_RESOURCE_ID" \
    --workspace "$WORKSPACE_ID" \
    --export-to-resource-specific true \
    --logs '[
        {"category": "GatewayLogs", "enabled": true},
        {"category": "GatewayLlmLogs", "enabled": true},
        {"category": "WebSocketConnectionLogs", "enabled": true},
        {"category": "DeveloperPortalAuditLogs", "enabled": true}
    ]' \
    --metrics '[{"category": "AllMetrics", "enabled": true}]' \
    --output none 2>/dev/null; then
    echo -e "${GREEN}✓ All log categories enabled with dedicated tables${NC}"
    echo -e "${GREEN}  (GatewayLogs, GatewayLlmLogs, WebSocket, DevPortal)${NC}"
    LLM_LOGS_ENABLED=true
else
    echo -e "${YELLOW}Some log categories not available in this SKU. Trying core categories...${NC}"
    
    # Fall back to GatewayLogs only (always available in all SKUs)
    if az monitor diagnostic-settings create \
        --name "mcp-security-logs" \
        --resource "$APIM_RESOURCE_ID" \
        --workspace "$WORKSPACE_ID" \
        --export-to-resource-specific true \
        --logs '[{"category": "GatewayLogs", "enabled": true}]' \
        --metrics '[{"category": "AllMetrics", "enabled": true}]' \
        --output none 2>/dev/null; then
        echo -e "${GREEN}✓ GatewayLogs enabled with dedicated table${NC}"
        LLM_LOGS_ENABLED=false
    else
        echo -e "${RED}Failed to create diagnostic settings${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✓ Diagnostic settings enabled!${NC}"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Log Tables Now Enabled${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo -e "${YELLOW}1. ApiManagementGatewayLogs${NC} (HTTP request details)"
echo "   • CallerIpAddress   - Who made the request"
echo "   • ResponseCode      - HTTP response code"
echo "   • RequestBody       - Full request content"
echo "   • ResponseBody      - Full response content"
echo "   • DurationMs        - Total request time"
echo "   • CorrelationId     - For cross-service tracing"
echo "   • Url, Method       - Request path and HTTP method"

if [ "$LLM_LOGS_ENABLED" = true ]; then
echo ""
echo -e "${YELLOW}2. ApiManagementGatewayLlmLog${NC} (AI/LLM gateway - if AI APIs configured)"
echo "   • PromptTokens      - Input token count"
echo "   • CompletionTokens  - Output token count"
echo "   • ModelName         - LLM model used"
echo "   • CorrelationId     - Links to GatewayLogs"
echo ""
echo -e "${YELLOW}3. ApiManagementWebSocketConnectionLogs${NC} (WebSocket connections)"
echo "   • EventName         - Connection lifecycle events"
echo "   • Source/Destination- Connection endpoints"
else
echo ""
echo -e "${YELLOW}Note:${NC} Only GatewayLogs enabled. Some categories may not be available"
echo "      in this SKU. GatewayLogs still captures all HTTP-level MCP traffic"
echo "      including request/response bodies and timing information."
fi
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Sample KQL Queries${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "HTTP traffic analysis (ApiManagementGatewayLogs):"
echo ""
echo -e "${YELLOW}  ApiManagementGatewayLogs"
echo "  | where TimeGenerated > ago(1h)"
echo "  | where ApiId contains 'mcp' or ApiId contains 'sherpa'"
echo "  | project TimeGenerated, CallerIpAddress, Method, ResponseCode, ApiId"
echo "  | order by TimeGenerated desc"
echo -e "  | limit 20${NC}"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Note: Log Ingestion Delay${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "Azure Monitor logs have a 2-5 minute ingestion delay."
echo "Run 1.3-validate.sh after a few minutes to verify logs appear."
echo ""
echo -e "${GREEN}Next: Wait 2-5 minutes, then run ./scripts/1.3-validate.sh${NC}"
echo ""
