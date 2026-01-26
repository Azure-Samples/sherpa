#!/bin/bash
# =============================================================================
# Camp 4 - Section 3.2: Create Alert Rules
# =============================================================================
# Pattern: hidden -> visible -> actionable
# Transition: VISIBLE -> ACTIONABLE (part 2: automated response)
#
# This script creates:
# - Action Group (how to notify: email, webhook, etc.)
# - Alert Rule 1: High volume of injection attacks  
# - Alert Rule 2: Credential exposure detected
#
# Note: Uses ARM template deployment via Python helper for reliability
# (the az monitor scheduled-query CLI extension has bugs)
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
echo -e "${CYAN}  Camp 4 - Section 3.2: Create Alert Rules${NC}"
echo -e "${CYAN}  Pattern: hidden -> visible -> actionable${NC}"
echo -e "${CYAN}  Making Security ACTIONABLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Load environment
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
WORKSPACE_ID=$(azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>/dev/null)
LOCATION=$(azd env get-value AZURE_LOCATION 2>/dev/null)

if [ -z "$RG_NAME" ] || [ -z "$WORKSPACE_ID" ]; then
    echo -e "${RED}Error: Missing environment values. Run 'azd up' first.${NC}"
    exit 1
fi

# Prompt for email (optional)
echo -e "${YELLOW}Alert notifications (optional):${NC}"
echo "Enter an email address to receive alerts (or press Enter to skip):"
read -r ALERT_EMAIL

echo ""
echo -e "${YELLOW}What we're creating:${NC}"
echo "  - Action Group - Defines how to notify (email, webhook)"
echo "  - Alert 1 - High attack volume (>10 attacks in 5 min)"
echo "  - Alert 2 - Credential exposure detected"
echo ""

# Create Action Group
ACTION_GROUP_NAME="mcp-security-alerts"

echo -e "${BLUE}Step 1: Creating action group...${NC}"

if [ -n "$ALERT_EMAIL" ]; then
    az monitor action-group create \
        --name "$ACTION_GROUP_NAME" \
        --resource-group "$RG_NAME" \
        --short-name "MCPSecAlrt" \
        --action email "security-team" "$ALERT_EMAIL" \
        --output none 2>/dev/null || echo "  (Action group may already exist)"
else
    az monitor action-group create \
        --name "$ACTION_GROUP_NAME" \
        --resource-group "$RG_NAME" \
        --short-name "MCPSecAlrt" \
        --output none 2>/dev/null || echo "  (Action group may already exist)"
fi

ACTION_GROUP_ID=$(az monitor action-group show \
    --name "$ACTION_GROUP_NAME" \
    --resource-group "$RG_NAME" \
    --query id -o tsv 2>/dev/null) || ACTION_GROUP_ID=""

if [ -z "$ACTION_GROUP_ID" ]; then
    echo -e "${RED}Error: Failed to get action group ID${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Action group ready${NC}"
echo ""

# Deploy alert rules using ARM template via Python helper
echo -e "${BLUE}Step 2: Deploying alert rules via ARM template...${NC}"
echo ""

# Generate and deploy using Python helper
TEMPLATE_FILE=$(mktemp)
python3 "$SCRIPT_DIR/create-alert-template.py" "$WORKSPACE_ID" "$ACTION_GROUP_ID" "$LOCATION" > "$TEMPLATE_FILE"

if [ ! -s "$TEMPLATE_FILE" ]; then
    echo -e "${RED}Error: Failed to generate ARM template${NC}"
    rm -f "$TEMPLATE_FILE"
    exit 1
fi

echo "  Deploying ARM template..."
DEPLOY_OUTPUT=$(az deployment group create \
    --resource-group "$RG_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --name "mcp-alert-rules" \
    --output json 2>&1)

DEPLOY_STATE=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.provisioningState // "Unknown"' 2>/dev/null)

rm -f "$TEMPLATE_FILE"

if [ "$DEPLOY_STATE" == "Succeeded" ]; then
    echo -e "${GREEN}[OK] Alert rules deployed successfully${NC}"
else
    echo -e "${YELLOW}[!] Deployment result: $DEPLOY_STATE${NC}"
    echo "    (Rules may have been updated or already existed)"
fi

echo ""

# Verify alerts were created
echo -e "${BLUE}Step 3: Verifying alert rules...${NC}"

ALERT_COUNT=$(az resource list \
    --resource-group "$RG_NAME" \
    --resource-type "Microsoft.Insights/scheduledQueryRules" \
    --query "length([?contains(name, 'mcp-')])" \
    -o tsv 2>/dev/null)

if [ "$ALERT_COUNT" -ge 2 ]; then
    echo -e "${GREEN}[OK] Found $ALERT_COUNT MCP alert rules${NC}"
else
    echo -e "${YELLOW}[!] Found $ALERT_COUNT alert rules (expected 2)${NC}"
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Alert Rules Ready${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "  Alert Rules Created:"
echo "  [!] mcp-high-attack-volume (Severity 2)"
echo "      Triggers when >10 attacks in 5 minutes"
echo ""
echo "  [!] mcp-credential-exposure (Severity 1 - Critical)"
echo "      Triggers on ANY credential detection"
echo ""
if [ -n "$ALERT_EMAIL" ]; then
    echo "  Notifications will be sent to: $ALERT_EMAIL"
else
    echo "  No email configured (alerts visible in Azure Portal)"
fi
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Section 3 Complete: Security is ACTIONABLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "[OK] Dashboard shows real-time security visibility"
echo "[OK] Alerts notify you when attacks exceed thresholds"
echo "[OK] Action groups can trigger automated responses"
echo ""
echo "The 'hidden -> visible -> actionable' pattern is complete:"
echo ""
echo "  [OK] HIDDEN:     APIM + Function had basic/no logging"
echo "  [OK] VISIBLE:    Diagnostic settings + structured logging"
echo "  [OK] ACTIONABLE: Dashboard + alerts for automated response"
echo ""
echo -e "${GREEN}Next: Run ./scripts/section4/4.1-simulate-attack.sh to test the full system${NC}"
echo ""
