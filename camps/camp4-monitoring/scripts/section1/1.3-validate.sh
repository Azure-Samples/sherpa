#!/bin/bash
# =============================================================================
# Camp 4 - Section 1.3: Validate APIM Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Current state: VISIBLE (verifying logs are flowing)
#
# This script queries Log Analytics to verify that APIM diagnostic logs
# from 1.2-fix.sh are being captured correctly.
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
WORKSPACE_RESOURCE_ID=$(azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>/dev/null)
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
APIM_NAME=$(azd env get-value APIM_NAME 2>/dev/null)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null)
WORKSPACE_NAME=$(azd env get-value LOG_ANALYTICS_WORKSPACE_NAME 2>/dev/null)

if [ -z "$APIM_GATEWAY_URL" ] || [ -z "$WORKSPACE_RESOURCE_ID" ]; then
    echo -e "${RED}Error: Missing environment values. Run 'azd up' first.${NC}"
    exit 1
fi

# Get workspace GUID (customerId) - required for az monitor log-analytics query
WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --ids "$WORKSPACE_RESOURCE_ID" \
    --query customerId -o tsv 2>/dev/null)

if [ -z "$WORKSPACE_ID" ]; then
    echo -e "${RED}Error: Could not get workspace GUID.${NC}"
    exit 1
fi

echo -e "${YELLOW}Note: Log Analytics has a 2-5 minute ingestion delay.${NC}"
echo -e "${YELLOW}This script queries for logs sent by 1.2-fix.sh.${NC}"
echo ""

echo -e "${BLUE}Step 1: Verifying diagnostic settings...${NC}"

# Check diagnostic settings
DIAG_SETTINGS=$(az monitor diagnostic-settings list \
    --resource "$(az apim show -n "$APIM_NAME" -g "$RG_NAME" --query id -o tsv 2>/dev/null)" \
    --query "[].{name:name, logs:logs[].category}" -o json 2>/dev/null) || DIAG_SETTINGS="[]"

if [ "$DIAG_SETTINGS" != "[]" ]; then
    echo -e "${GREEN}✓ Diagnostic settings configured${NC}"
else
    echo -e "${RED}✗ No diagnostic settings found${NC}"
    echo "  Run ./scripts/section1/1.2-fix.sh first"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 2: Querying Log Analytics...${NC}"

# Query for recent MCP traffic (HTTP level) - using dedicated table column names
QUERY_HTTP='ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where ApiId contains "mcp" or ApiId contains "sherpa"
| project TimeGenerated, CallerIpAddress, Method, Url, ResponseCode, ApiId
| order by TimeGenerated desc
| limit 10'

echo ""
echo "Running KQL query..."
echo ""

RESULT_HTTP=$(az monitor log-analytics query \
    --workspace "$WORKSPACE_ID" \
    --analytics-query "$QUERY_HTTP" \
    --output json 2>/dev/null) || RESULT_HTTP="[]"

# Parse results
COUNT_HTTP=$(echo "$RESULT_HTTP" | jq 'length' 2>/dev/null || echo "0")

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Results${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

echo -e "${YELLOW}ApiManagementGatewayLogs (HTTP traffic):${NC}"
if [ "$COUNT_HTTP" -gt 0 ] && [ "$COUNT_HTTP" != "0" ]; then
    echo -e "${GREEN}✓ HTTP logs are flowing to Log Analytics!${NC}"
    echo ""
    echo "$RESULT_HTTP" | jq -r '.[] | "  \(.TimeGenerated) | \(.Method) \(.ApiId) | HTTP \(.ResponseCode) | \(.CallerIpAddress)"' 2>/dev/null || echo "$RESULT_HTTP"
else
    echo -e "${YELLOW}No HTTP logs found yet (2-5 min ingestion delay)${NC}"
fi

echo ""
if [ "$COUNT_HTTP" -gt 0 ]; then
    echo -e "${GREEN}Section 1 Complete: APIM traffic is now VISIBLE${NC}"
else
    echo -e "${YELLOW}No logs found yet (this is normal if you just enabled diagnostics)${NC}"
    echo ""
    echo "Logs take 2-5 minutes to appear. Try again in a few minutes."
    echo ""
    echo "You can also check manually in the Azure Portal:"
    echo "1. Go to your Log Analytics workspace"
    echo "2. Click 'Logs'"
    echo "3. Run: ApiManagementGatewayLogs | where ApiId contains 'mcp' | limit 10"
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  What You've Accomplished${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "✓ APIM is now logging all MCP requests to Log Analytics"
echo "✓ ApiManagementGatewayLogs captures: Caller IPs, response codes, timing, URLs"
echo "✓ You can query and analyze MCP traffic patterns using ApiId filtering"
echo ""
echo "But we still have a gap:"
echo "• The security function logs are still BASIC (unstructured)"
echo "• We can't correlate APIM logs with function logs"
echo "• We can't see detailed security events (injection type, PII entities)"
echo ""
echo -e "${GREEN}Next: Run ./scripts/section2/2.1-exploit.sh to see the function logging gap${NC}"
echo ""
