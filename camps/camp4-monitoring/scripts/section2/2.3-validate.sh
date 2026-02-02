#!/bin/bash
# =============================================================================
# Camp 4 - Section 2.3: Validate Structured Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Current state: VISIBLE (verifying structured logs)
#
# This script queries Log Analytics to verify that structured logs
# with custom dimensions are being captured from 2.2-fix.sh.
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
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)

# Get workspace GUID (az monitor log-analytics query needs GUID, not resource ID)
WORKSPACE_ID=$(az monitor log-analytics workspace list -g "$RG_NAME" --query "[0].customerId" -o tsv 2>/dev/null)

if [ -z "$WORKSPACE_ID" ]; then
    echo -e "${RED}Error: Could not find Log Analytics workspace. Run 'azd up' first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Note: Log Analytics has a 2-5 minute ingestion delay.${NC}"
echo -e "${YELLOW}This script queries for structured logs sent by 2.2-fix.sh.${NC}"
echo ""

echo -e "${BLUE}Querying for structured security events...${NC}"
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
else
    echo -e "${YELLOW}No structured logs found yet${NC}"
    echo ""
    echo "This could mean:"
    echo "  1. Logs haven't ingested yet (wait 2-5 minutes and try again)"
    echo "  2. APIM isn't pointing to v2 (run ./scripts/section2/2.2-fix.sh)"
    echo ""
    echo "Try again in a few minutes."
fi

echo ""
