#!/bin/bash
# =============================================================================
# Camp 4 - Section 2.3: Validate Structured Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Current state: VISIBLE (verifying structured logs)
#
# This script sends attacks, then queries Log Analytics to verify
# that structured logs with custom dimensions are being captured.
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
echo -e "${CYAN}  Camp 4 - Section 2.3: Validate Structured Logging${NC}"
echo -e "${CYAN}  Pattern: hidden → visible → actionable${NC}"
echo -e "${CYAN}  Current State: VISIBLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Load environment
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL 2>/dev/null)
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null)

# Get workspace GUID (az monitor log-analytics query needs GUID, not resource ID)
WORKSPACE_ID=$(az monitor log-analytics workspace list -g "$RG_NAME" --query "[0].customerId" -o tsv 2>/dev/null)

if [ -z "$APIM_GATEWAY_URL" ] || [ -z "$WORKSPACE_ID" ]; then
    echo -e "${RED}Error: Missing environment values. Run 'azd up' first.${NC}"
    exit 1
fi

if [ -z "$MCP_APP_CLIENT_ID" ]; then
    echo -e "${RED}Error: MCP_APP_CLIENT_ID not found. Run 'azd up' first.${NC}"
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

echo -e "${BLUE}Step 1: Generating security events with v2 function...${NC}"
echo ""

# Initialize MCP session
curl -s -D /tmp/mcp-headers.txt --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"camp4-test","version":"1.0"}},"id":1}' > /dev/null 2>&1 || true

SESSION_ID=$(grep -i "mcp-session-id" /tmp/mcp-headers.txt 2>/dev/null | sed 's/.*: *//' | tr -d '\r\n') || true
[ -z "$SESSION_ID" ] && SESSION_ID="session-$(date +%s)"

# Generate a correlation ID for tracking
CORRELATION_ID="test-$(date +%s)"
echo "Using session ID: $SESSION_ID"
echo ""

# Send attacks through APIM to the real MCP endpoint
echo "Sending SQL injection..."
curl -s --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"'"'"'; DROP TABLE users; --"}},"id":2}' > /dev/null 2>&1 || true

echo "Sending path traversal..."
curl -s --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check_trail_conditions","arguments":{"trail_id":"../../../etc/passwd"}},"id":3}' > /dev/null 2>&1 || true

echo "Sending shell injection..."
curl -s --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"summit; cat /etc/passwd"}},"id":4}' > /dev/null 2>&1 || true

echo ""
echo -e "${GREEN}✓ Security events generated${NC}"
echo ""

echo -e "${YELLOW}Note: Log Analytics has 2-5 minute ingestion delay${NC}"
echo ""

echo -e "${BLUE}Step 2: Querying structured logs...${NC}"
echo ""

# Query for structured security events
# Note: custom_dimensions is stored as a Python dict string (single quotes)
# We need to convert to JSON format before parsing
QUERY='AppTraces
| where TimeGenerated > ago(30m)
| where Properties has "event_type"
| extend CustomDims = parse_json(replace_string(replace_string(tostring(Properties.custom_dimensions), "'"'"'", "\""), "None", "null"))
| extend EventType = tostring(CustomDims.event_type),
         InjectionType = tostring(CustomDims.injection_type),
         CorrelationId = tostring(CustomDims.correlation_id),
         ToolName = tostring(CustomDims.tool_name)
| where EventType == "INJECTION_BLOCKED"
| project TimeGenerated, EventType, InjectionType, ToolName, CorrelationId
| order by TimeGenerated desc
| limit 20'

RESULT=$(az monitor log-analytics query \
    --workspace "$WORKSPACE_ID" \
    --analytics-query "$QUERY" \
    --output json 2>/dev/null) || RESULT="[]"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Structured Log Results${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

COUNT=$(echo "$RESULT" | jq 'length' 2>/dev/null || echo "0")

if [ "$COUNT" -gt 0 ] && [ "$COUNT" != "0" ]; then
    echo -e "${GREEN}✓ Structured logs are flowing!${NC}"
    echo ""
    echo "Recent security events:"
    echo ""
    echo "$RESULT" | jq -r '.[] | "  \(.TimeGenerated) | \(.EventType) | \(.InjectionType) | Tool: \(.ToolName)"' 2>/dev/null | head -10
    echo ""
    
    # Count by injection type
    echo ""
    echo -e "${BLUE}Summary by injection type:${NC}"
    SUMMARY_QUERY='AppTraces
    | where TimeGenerated > ago(1h)
    | where Properties has "event_type"
    | extend CustomDims = parse_json(replace_string(replace_string(tostring(Properties.custom_dimensions), "'"'"'", "\""), "None", "null"))
    | extend EventType = tostring(CustomDims.event_type),
             InjectionType = tostring(CustomDims.injection_type)
    | where EventType == "INJECTION_BLOCKED"
    | summarize Count=count() by InjectionType
    | order by Count desc'
    
    SUMMARY=$(az monitor log-analytics query \
        --workspace "$WORKSPACE_ID" \
        --analytics-query "$SUMMARY_QUERY" \
        --output json 2>/dev/null) || SUMMARY="[]"
    
    echo "$SUMMARY" | jq -r '.[] | "  \(.InjectionType): \(.Count) attacks"' 2>/dev/null || echo "  (No summary available)"
else
    echo -e "${YELLOW}No structured logs found yet${NC}"
    echo ""
    echo "This could mean:"
    echo "  1. Logs haven't ingested yet (wait 2-5 minutes)"
    echo "  2. Function v2 wasn't deployed (run 2.2-fix.sh)"
    echo "  3. The function isn't using structured logging"
    echo ""
    echo "Try again in a few minutes."
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Section 2 Complete: Function Logs are VISIBLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "✓ APIM logs show HTTP requests with caller IPs"
echo "✓ Function logs show security events with custom dimensions"
echo "✓ You can correlate across services using correlation_id"
echo "✓ You can query by injection type, tool name, etc."
echo ""
echo "But security is still not ACTIONABLE:"
echo "• No dashboard to visualize attack patterns"
echo "• No alerts to notify you of attacks in real-time"
echo "• You have to manually run KQL queries to see what's happening"
echo ""
echo -e "${GREEN}Next: Run ./scripts/section3/3.1-deploy-workbook.sh to create a dashboard${NC}"
echo ""
