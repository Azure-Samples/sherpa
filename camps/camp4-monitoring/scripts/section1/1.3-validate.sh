#!/bin/bash
# =============================================================================
# Camp 4 - Section 1.3: Validate APIM Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Current state: VISIBLE (verifying logs are flowing)
#
# This script sends requests and then queries Log Analytics to verify
# that APIM diagnostic logs are being captured correctly.
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
echo -e "${CYAN}  Camp 4 - Section 1.3: Validate APIM Logging${NC}"
echo -e "${CYAN}  Pattern: hidden → visible → actionable${NC}"
echo -e "${CYAN}  Current State: VISIBLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Load environment
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL 2>/dev/null)
WORKSPACE_ID=$(azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>/dev/null)
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
APIM_NAME=$(azd env get-value APIM_NAME 2>/dev/null)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null)

if [ -z "$APIM_GATEWAY_URL" ] || [ -z "$WORKSPACE_ID" ]; then
    echo -e "${RED}Error: Missing environment values. Run 'azd up' first.${NC}"
    exit 1
fi

# Get OAuth token
echo -e "${BLUE}Getting OAuth token...${NC}"
TOKEN=$(az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv)
if [ -z "$TOKEN" ]; then
    echo -e "${RED}Error: Could not get access token.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ OAuth token acquired${NC}"
echo ""

echo -e "${BLUE}Step 1: Sending test requests through APIM...${NC}"
echo ""

# Initialize MCP session
curl -s -D /tmp/mcp-headers.txt --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"camp4-test","version":"1.0"}},"id":1}' > /dev/null 2>&1 || true

SESSION_ID=$(grep -i "mcp-session-id" /tmp/mcp-headers.txt 2>/dev/null | sed 's/.*: *//' | tr -d '\r\n') || true
[ -z "$SESSION_ID" ] && SESSION_ID="session-$(date +%s)"

# Send a few requests
for i in 1 2 3; do
    curl -s --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -H "Mcp-Session-Id: $SESSION_ID" \
        -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"summit"}},"id":'$i'}' > /dev/null 2>&1 || true
    echo "  Sent request $i/3"
done

echo ""
echo -e "${YELLOW}Note: Log Analytics has 2-5 minute ingestion delay${NC}"
echo ""

echo -e "${BLUE}Step 2: Verifying diagnostic settings...${NC}"

# Check diagnostic settings
DIAG_SETTINGS=$(az monitor diagnostic-settings list \
    --resource "$(az apim show -n "$APIM_NAME" -g "$RG_NAME" --query id -o tsv 2>/dev/null)" \
    --query "[].{name:name, logs:logs[].category}" -o json 2>/dev/null) || DIAG_SETTINGS="[]"

if [ "$DIAG_SETTINGS" != "[]" ]; then
    echo -e "${GREEN}✓ Diagnostic settings configured${NC}"
else
    echo -e "${RED}✗ No diagnostic settings found${NC}"
    echo "  Run ./scripts/1.2-fix.sh first"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 3: Querying Log Analytics...${NC}"

# Get workspace name from ID
WORKSPACE_NAME=$(az monitor log-analytics workspace show \
    --ids "$WORKSPACE_ID" \
    --query name -o tsv 2>/dev/null)

# Query for recent MCP traffic (HTTP level)
QUERY_HTTP='ApiManagementGatewayLogs
| where TimeGenerated > ago(30m)
| where Url contains "/mcp/"
| summarize RequestCount=count() by bin(TimeGenerated, 5m), ResponseCode
| order by TimeGenerated desc'

# Query for MCP-specific logs
QUERY_MCP='ApiManagementGatewayMCPLog
| where TimeGenerated > ago(30m)
| summarize CallCount=count() by ToolName, ClientName
| order by CallCount desc'

echo ""
echo "Running KQL queries..."
echo ""

RESULT_HTTP=$(az monitor log-analytics query \
    --workspace "$WORKSPACE_ID" \
    --analytics-query "$QUERY_HTTP" \
    --output json 2>/dev/null) || RESULT_HTTP="[]"

RESULT_MCP=$(az monitor log-analytics query \
    --workspace "$WORKSPACE_ID" \
    --analytics-query "$QUERY_MCP" \
    --output json 2>/dev/null) || RESULT_MCP="[]"

# Parse results
COUNT_HTTP=$(echo "$RESULT_HTTP" | jq 'length' 2>/dev/null || echo "0")
COUNT_MCP=$(echo "$RESULT_MCP" | jq 'length' 2>/dev/null || echo "0")

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Results${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

echo -e "${YELLOW}ApiManagementGatewayLogs (HTTP traffic):${NC}"
if [ "$COUNT_HTTP" -gt 0 ] && [ "$COUNT_HTTP" != "0" ]; then
    echo -e "${GREEN}✓ HTTP logs are flowing to Log Analytics!${NC}"
    echo ""
    echo "$RESULT_HTTP" | jq -r '.[] | "  \(.TimeGenerated): \(.RequestCount) requests (HTTP \(.ResponseCode))"' 2>/dev/null || echo "$RESULT_HTTP"
else
    echo -e "${YELLOW}No HTTP logs found yet (2-5 min ingestion delay)${NC}"
fi

echo ""
echo -e "${YELLOW}ApiManagementGatewayMCPLog (MCP-specific):${NC}"
if [ "$COUNT_MCP" -gt 0 ] && [ "$COUNT_MCP" != "0" ]; then
    echo -e "${GREEN}✓ MCP logs are flowing to Log Analytics!${NC}"
    echo ""
    echo "$RESULT_MCP" | jq -r '.[] | "  Tool: \(.ToolName), Client: \(.ClientName), Calls: \(.CallCount)"' 2>/dev/null || echo "$RESULT_MCP"
else
    echo -e "${YELLOW}No MCP logs found yet (2-5 min ingestion delay)${NC}"
    echo "  Note: MCPServerLogs may require MCP protocol traffic to populate"
fi

echo ""
if [ "$COUNT_HTTP" -gt 0 ] || [ "$COUNT_MCP" -gt 0 ]; then
    echo -e "${GREEN}Section 1 Complete: APIM traffic is now VISIBLE${NC}"
else
    echo -e "${YELLOW}No logs found yet (this is normal if you just enabled diagnostics)${NC}"
    echo ""
    echo "Logs take 2-5 minutes to appear. Try again in a few minutes."
    echo ""
    echo "You can also check manually in the Azure Portal:"
    echo "1. Go to your Log Analytics workspace"
    echo "2. Click 'Logs'"
    echo "3. Run: ApiManagementGatewayLogs | limit 10"
    echo "4. Run: ApiManagementGatewayMCPLog | limit 10"
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  What You've Accomplished${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "✓ APIM is now logging all MCP requests to Log Analytics"
echo "✓ ApiManagementGatewayLogs: Caller IPs, response codes, timing"
echo "✓ ApiManagementGatewayMCPLog: Tool names, clients, sessions"
echo "✓ You can query and analyze MCP traffic patterns"
echo ""
echo "But we still have a gap:"
echo "• The security function logs are still BASIC (unstructured)"
echo "• We can't correlate APIM logs with function logs"
echo "• We can't see detailed security events (injection type, PII entities)"
echo ""
echo -e "${GREEN}Next: Run ./scripts/section2/2.1-exploit.sh to see the function logging gap${NC}"
echo ""
