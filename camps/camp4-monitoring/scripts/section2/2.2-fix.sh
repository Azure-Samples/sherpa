#!/bin/bash
# =============================================================================
# Camp 4 - Section 2.2: Deploy Function v2 with Structured Logging
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: HIDDEN → VISIBLE
#
# This script deploys the security-function (v2) which uses:
# - Azure Monitor OpenTelemetry for structured logging
# - Custom dimensions (event_type, injection_type, correlation_id)
# - Proper severity levels for different event types
#
# After this, you can write KQL queries like:
#   AppTraces | where Properties.event_type == "INJECTION_BLOCKED"
#
# NOTE: Uses direct zip deployment - does NOT modify azure.yaml
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
    echo -e "${RED}Error: FUNCTION_APP_NAME not found. Run 'azd up' first.${NC}"
    exit 1
fi

echo -e "${YELLOW}What we're doing:${NC}"
echo "1. Package security-function (v2) with Azure Monitor telemetry"
echo "2. Deploy directly to Function App using zip deployment"
echo "3. The function will now emit structured logs with custom dimensions"
echo ""

# Deploy v2 using zip deployment (doesn't require azure.yaml changes)
echo -e "${BLUE}Step 1: Packaging security-function v2...${NC}"

# Create a temporary directory for the zip
TEMP_DIR=$(mktemp -d)
ZIP_FILE="$TEMP_DIR/function-v2.zip"

# Copy v2 function to temp and create zip
cp -r security-function/* "$TEMP_DIR/"
cd "$TEMP_DIR"
zip -r "$ZIP_FILE" . -x "*.pyc" -x "__pycache__/*" -x ".venv/*" -x "*.git*" > /dev/null
cd - > /dev/null

echo -e "${GREEN}✓ Package created${NC}"
echo ""

echo -e "${BLUE}Step 2: Deploying v2 to $FUNCTION_APP_NAME...${NC}"
echo ""

# Deploy using az functionapp deployment
az functionapp deployment source config-zip \
    --resource-group "$RG_NAME" \
    --name "$FUNCTION_APP_NAME" \
    --src "$ZIP_FILE" \
    --output none

# Clean up
rm -rf "$TEMP_DIR"

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
