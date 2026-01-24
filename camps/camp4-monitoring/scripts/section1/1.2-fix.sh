#!/bin/bash
# =============================================================================
# Camp 4 - Section 1.2: Enable APIM Diagnostic Settings
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: HIDDEN → VISIBLE
#
# This script enables Azure Monitor diagnostic settings on APIM to capture:
# - ApiManagementGatewayLogs: All HTTP requests with caller IP, response codes
# - ApiManagementGatewayMCPLog: MCP-specific fields (ToolName, SessionId, etc.)
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
# Key Log Tables enabled:
# - ApiManagementGatewayLogs: CallerIpAddress, ResponseCode, DurationMs, CorrelationId
# - ApiManagementGatewayMCPLog: ToolName, ClientName, SessionId, ServerName, Error (MCP-specific!)
# - ApiManagementGatewayLlmLog: PromptTokens, CompletionTokens, ModelName (AI gateway)
#
# Note: ApiManagementGatewayMCPLog requires the MCPServerLogs category
# Note: ApiManagementGatewayLlmLog requires the GenerativeAIGatewayLogs category
az monitor diagnostic-settings create \
    --name "mcp-security-logs" \
    --resource "$APIM_RESOURCE_ID" \
    --workspace "$WORKSPACE_ID" \
    --logs '[
        {
            "category": "GatewayLogs",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 0
            }
        },
        {
            "category": "MCPServerLogs",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 0
            }
        },
        {
            "category": "GenerativeAIGatewayLogs",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 0
            }
        }
    ]' \
    --metrics '[
        {
            "category": "AllMetrics",
            "enabled": true,
            "retentionPolicy": {
                "enabled": false,
                "days": 0
            }
        }
    ]' \
    --output none

echo ""
echo -e "${GREEN}✓ Diagnostic settings enabled!${NC}"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Key Log Tables Now Enabled${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo -e "${YELLOW}1. ApiManagementGatewayLogs${NC} (HTTP request details)"
echo "   • CallerIpAddress   - Who made the request"
echo "   • ResponseCode      - HTTP response code"
echo "   • RequestBody       - Full request content"
echo "   • ResponseBody      - Full response content"
echo "   • DurationMs        - Total request time"
echo "   • CorrelationId     - For cross-service tracing"
echo ""
echo -e "${YELLOW}2. ApiManagementGatewayMCPLog${NC} (MCP-specific fields!)"
echo "   • ToolName          - Which MCP tool was called"
echo "   • ClientName        - MCP client identifier"
echo "   • ClientVersion     - Client version"
echo "   • AuthenticationMethod - How the client authenticated"
echo "   • SessionId         - MCP session identifier"
echo "   • ServerName        - Target MCP server"
echo "   • Error             - Error details if any"
echo "   • CorrelationId     - For cross-service tracing"
echo ""
echo -e "${YELLOW}3. ApiManagementGatewayLlmLog${NC} (AI/LLM gateway)"
echo "   • PromptTokens      - Input token count"
echo "   • CompletionTokens  - Output token count"
echo "   • ModelName         - LLM model used"
echo "   • CorrelationId     - For cross-service tracing"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Sample KQL Queries${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "HTTP traffic analysis (ApiManagementGatewayLogs):"
echo ""
echo -e "${YELLOW}  ApiManagementGatewayLogs"
echo "  | where TimeGenerated > ago(1h)"
echo "  | where Url contains '/mcp/'"
echo "  | project TimeGenerated, CallerIpAddress, Method, ResponseCode, DurationMs"
echo "  | order by TimeGenerated desc"
echo -e "  | limit 20${NC}"
echo ""
echo "MCP tool usage analysis (ApiManagementGatewayMCPLog):"
echo ""
echo -e "${YELLOW}  ApiManagementGatewayMCPLog"
echo "  | where TimeGenerated > ago(1h)"
echo "  | summarize CallCount=count() by ToolName, ClientName"
echo "  | order by CallCount desc"
echo -e "  | limit 10${NC}"
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
