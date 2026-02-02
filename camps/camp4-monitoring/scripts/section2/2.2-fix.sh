#!/bin/bash
# =============================================================================
# Camp 4 - Section 2.2: Switch to Function v2 with Structured Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: HIDDEN → VISIBLE
#
# Both function versions are already deployed:
# - v1: Basic logging (logging.warning()) - currently active
# - v2: Structured logging with Azure Monitor OpenTelemetry
#
# This script simply updates the APIM named value to point to v2.
# No redeployment needed!
#
# After this, security events are queryable with KQL:
#   AppTraces | where Properties.event_type == "INJECTION_BLOCKED"
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
echo -e "${CYAN}  Camp 4 - Section 2.2: Enable Structured Logging${NC}"
echo -e "${CYAN}  Pattern: hidden → visible → actionable${NC}"
echo -e "${CYAN}  Transition: HIDDEN → VISIBLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Load environment
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
APIM_NAME=$(azd env get-value APIM_NAME 2>/dev/null)
FUNC_V1_URL=$(azd env get-value FUNCTION_APP_V1_URL 2>/dev/null)
FUNC_V2_URL=$(azd env get-value FUNCTION_APP_V2_URL 2>/dev/null)

if [ -z "$APIM_NAME" ] || [ -z "$FUNC_V2_URL" ]; then
    echo -e "${RED}Error: Required environment values not found. Run 'azd up' first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Current Architecture:${NC}"
echo "Both function versions are already deployed:"
echo "  v1: $FUNC_V1_URL (basic logging - currently active)"
echo "  v2: $FUNC_V2_URL (structured logging)"
echo ""
echo -e "${YELLOW}What we're doing:${NC}"
echo "1. Update APIM named value 'function-app-url' to point to v2"
echo "2. That's it! APIM policies automatically use the new URL"
echo ""

# Check current value
echo -e "${BLUE}Step 1: Checking current APIM configuration...${NC}"
CURRENT_URL=$(az apim nv show \
    --resource-group "$RG_NAME" \
    --service-name "$APIM_NAME" \
    --named-value-id "function-app-url" \
    --query "value" -o tsv 2>/dev/null)

echo "Current function-app-url: $CURRENT_URL"
echo ""

if [[ "$CURRENT_URL" == *"funcv2"* ]]; then
    echo -e "${YELLOW}Already pointing to v2! No change needed.${NC}"
else
    echo -e "${BLUE}Step 2: Switching APIM to use v2...${NC}"
    
    az apim nv update \
        --resource-group "$RG_NAME" \
        --service-name "$APIM_NAME" \
        --named-value-id "function-app-url" \
        --value "$FUNC_V2_URL" \
        --output none
    
    echo ""
    echo -e "${GREEN}✓ APIM now points to v2!${NC}"
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  What Changed: v1 vs v2${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "v1 (basic logging):"
echo -e "  ${RED}logging.warning(f'Injection blocked: {category}')${NC}"
echo ""
echo "v2 (structured logging):"
echo -e "  ${GREEN}log_injection_blocked(${NC}"
echo -e "  ${GREEN}    injection_type=result.category,${NC}"
echo -e "  ${GREEN}    reason=result.reason,${NC}"
echo -e "  ${GREEN}    correlation_id=correlation_id,${NC}"
echo -e "  ${GREEN}    tool_name=tool_name${NC}"
echo -e "  ${GREEN})${NC}"
echo ""
echo "This creates structured log entries with custom dimensions:"
echo ""
echo "  {\"event_type\": \"INJECTION_BLOCKED\","
echo "   \"injection_type\": \"sql_injection\","
echo "   \"correlation_id\": \"abc-123\","
echo "   \"tool_name\": \"search\","
echo "   \"severity\": \"WARNING\"}"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  KQL Queries Now Possible${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "Count attacks by type:"
echo -e "${YELLOW}  AppTraces"
echo "  | where Properties.event_type == 'INJECTION_BLOCKED'"
echo "  | summarize Count=count() by tostring(Properties.injection_type)"
echo -e "  | order by Count desc${NC}"
echo ""
echo "Find all requests for a specific correlation ID:"
echo -e "${YELLOW}  let correlationId = 'abc-123';"
echo "  AppTraces"
echo "  | where Properties.correlation_id == correlationId"
echo "  | union (ApiManagementGatewayLogs | where CorrelationId == correlationId)"
echo -e "  | order by TimeGenerated${NC}"
echo ""
echo "Top targeted tools:"
echo -e "${YELLOW}  AppTraces"
echo "  | where Properties.event_type == 'INJECTION_BLOCKED'"
echo "  | summarize Attacks=count() by tostring(Properties.tool_name)"
echo -e "  | order by Attacks desc${NC}"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Generating Test Events (for 2.3-validate.sh)${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "Now that v2 is active, we'll send a few attacks to generate"
echo "structured log entries for validation..."
echo ""

# Get OAuth token and send test attacks
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL 2>/dev/null)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null)

if [ -n "$APIM_GATEWAY_URL" ] && [ -n "$MCP_APP_CLIENT_ID" ]; then
    TOKEN=$(az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>/dev/null) || true
    
    if [ -n "$TOKEN" ]; then
        # Initialize MCP session
        curl -s -D /tmp/mcp-headers.txt --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json, text/event-stream" \
            -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"camp4-v2-test","version":"1.0"}},"id":1}' > /dev/null 2>&1 || true

        SESSION_ID=$(grep -i "mcp-session-id" /tmp/mcp-headers.txt 2>/dev/null | sed 's/.*: *//' | tr -d '\r\n') || true
        [ -z "$SESSION_ID" ] && SESSION_ID="session-$(date +%s)"

        echo -e "${BLUE}Sending SQL injection...${NC}"
        HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json, text/event-stream" \
            -H "Mcp-Session-Id: $SESSION_ID" \
            -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"'"'"'; DROP TABLE users; --"}},"id":2}') || HTTP_CODE="error"
        echo "  Status: $HTTP_CODE (expected: 400)"

        echo -e "${BLUE}Sending path traversal...${NC}"
        HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json, text/event-stream" \
            -H "Mcp-Session-Id: $SESSION_ID" \
            -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check_trail_conditions","arguments":{"trail_id":"../../../etc/passwd"}},"id":3}') || HTTP_CODE="error"
        echo "  Status: $HTTP_CODE (expected: 400)"

        echo -e "${BLUE}Sending shell injection...${NC}"
        HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json, text/event-stream" \
            -H "Mcp-Session-Id: $SESSION_ID" \
            -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"summit; cat /etc/passwd"}},"id":4}') || HTTP_CODE="error"
        echo "  Status: $HTTP_CODE (expected: 400)"
        
        echo ""
        echo -e "${GREEN}✓ Test attacks sent! These will appear as structured events.${NC}"
    else
        echo -e "${YELLOW}Warning: Could not get access token. Skipping test events.${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Missing APIM URL or client ID. Skipping test events.${NC}"
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Note: Log Ingestion Delay${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "Azure Monitor logs have a 2-5 minute ingestion delay."
echo "Run 2.3-validate.sh after a few minutes to verify structured logs appear."
echo ""
echo -e "${GREEN}Next: Wait 2-5 minutes, then run ./scripts/section2/2.3-validate.sh${NC}"
echo ""
