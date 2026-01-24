#!/bin/bash
# =============================================================================
# Camp 4 - Section 2.2: Deploy Function v2 with Structured Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: HIDDEN → VISIBLE
#
# This script deploys the security-function-v2 which uses:
# - Azure Monitor OpenTelemetry for structured logging
# - Custom dimensions (event_type, injection_type, correlation_id)
# - Proper severity levels for different event types
#
# After this, you can write KQL queries like:
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
echo -e "${CYAN}  Camp 4 - Section 2.2: Deploy Structured Logging${NC}"
echo -e "${CYAN}  Pattern: hidden → visible → actionable${NC}"
echo -e "${CYAN}  Transition: HIDDEN → VISIBLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Load environment
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
FUNCTION_APP_NAME=$(azd env get-value FUNCTION_APP_NAME 2>/dev/null)

if [ -z "$FUNCTION_APP_NAME" ]; then
    echo -e "${RED}Error: FUNCTION_APP_NAME not found. Run 'azd provision' first.${NC}"
    exit 1
fi

echo -e "${YELLOW}What we're doing:${NC}"
echo "1. Update azure.yaml to use security-function (v2)"
echo "2. Deploy the updated function with 'azd deploy'"
echo "3. The function will now emit structured logs with custom dimensions"
echo ""

# Update azure.yaml to point to v2
echo -e "${BLUE}Step 1: Updating azure.yaml to use v2...${NC}"

# Check current azure.yaml
CURRENT_PROJECT=$(grep -A1 "security-function:" azure.yaml | grep "project:" | awk '{print $2}')

if [ "$CURRENT_PROJECT" = "./security-function" ]; then
    echo -e "${GREEN}✓ azure.yaml already points to security-function (v2)${NC}"
else
    # Update to use v2
    sed -i.bak 's|project: ./security-function-v1|project: ./security-function|' azure.yaml
    echo -e "${GREEN}✓ Updated azure.yaml to use security-function (v2)${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Deploying v2 with structured logging...${NC}"
echo ""

# Deploy only the security function
azd deploy security-function --no-prompt

echo ""
echo -e "${GREEN}✓ Security function v2 deployed!${NC}"
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
echo -e "${GREEN}Next: Wait 2-5 minutes for logs to ingest, then run ./scripts/section2/2.3-validate.sh${NC}"
echo ""
