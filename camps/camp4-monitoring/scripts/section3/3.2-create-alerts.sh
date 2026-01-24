#!/bin/bash
# =============================================================================
# Camp 4 - Section 3.2: Create Alert Rules
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: VISIBLE → ACTIONABLE (part 2: automated response)
#
# This script creates:
# - Action Group (how to notify: email, webhook, etc.)
# - Alert Rule 1: High volume of injection attacks
# - Alert Rule 2: New attack vector detected (unusual injection type)
# - Alert Rule 3: Credential exposure detected
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
echo -e "${CYAN}  Pattern: hidden → visible → actionable${NC}"
echo -e "${CYAN}  Making Security ACTIONABLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Load environment
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
WORKSPACE_ID=$(azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>/dev/null)
LOCATION=$(azd env get-value AZURE_LOCATION 2>/dev/null)

if [ -z "$RG_NAME" ] || [ -z "$WORKSPACE_ID" ]; then
    echo -e "${RED}Error: Missing environment values. Run 'azd provision' first.${NC}"
    exit 1
fi

# Prompt for email (optional)
echo -e "${YELLOW}Alert notifications (optional):${NC}"
echo "Enter an email address to receive alerts (or press Enter to skip):"
read -r ALERT_EMAIL

echo ""
echo -e "${YELLOW}What we're creating:${NC}"
echo "  📧 Action Group - Defines how to notify (email, webhook)"
echo "  🚨 Alert 1 - High attack volume (>10 attacks in 5 min)"
echo "  🆕 Alert 2 - Credential exposure detected"
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
        --output none 2>/dev/null || echo "Action group may already exist"
else
    az monitor action-group create \
        --name "$ACTION_GROUP_NAME" \
        --resource-group "$RG_NAME" \
        --short-name "MCPSecAlrt" \
        --output none 2>/dev/null || echo "Action group may already exist"
fi

ACTION_GROUP_ID=$(az monitor action-group show \
    --name "$ACTION_GROUP_NAME" \
    --resource-group "$RG_NAME" \
    --query id -o tsv 2>/dev/null) || ACTION_GROUP_ID=""

echo -e "${GREEN}✓ Action group created${NC}"
echo ""

# Create Alert Rule 1: High attack volume
echo -e "${BLUE}Step 2: Creating 'High Attack Volume' alert rule...${NC}"

ALERT1_NAME="mcp-high-attack-volume"
ALERT1_QUERY='AppTraces
| where TimeGenerated > ago(5m)
| where Properties has "event_type"
| extend EventType = tostring(Properties.event_type)
| where EventType == "INJECTION_BLOCKED"
| summarize AttackCount=count()
| where AttackCount > 10'

az monitor scheduled-query create \
    --name "$ALERT1_NAME" \
    --resource-group "$RG_NAME" \
    --scopes "$WORKSPACE_ID" \
    --condition "count 'HighAttackVolume' > 0" \
    --condition-query "$ALERT1_QUERY" \
    --evaluation-frequency 5m \
    --window-size 5m \
    --severity 2 \
    --description "More than 10 injection attacks detected in 5 minutes" \
    --action-groups "$ACTION_GROUP_ID" \
    --output none 2>/dev/null || echo "Alert rule may already exist"

echo -e "${GREEN}✓ High attack volume alert created${NC}"
echo ""

# Create Alert Rule 2: Credential exposure
echo -e "${BLUE}Step 3: Creating 'Credential Exposure' alert rule...${NC}"

ALERT2_NAME="mcp-credential-exposure"
ALERT2_QUERY='AppTraces
| where TimeGenerated > ago(5m)
| where Properties has "event_type"
| extend EventType = tostring(Properties.event_type)
| where EventType == "CREDENTIAL_DETECTED"
| summarize CredentialCount=count()
| where CredentialCount > 0'

az monitor scheduled-query create \
    --name "$ALERT2_NAME" \
    --resource-group "$RG_NAME" \
    --scopes "$WORKSPACE_ID" \
    --condition "count 'CredentialExposure' > 0" \
    --condition-query "$ALERT2_QUERY" \
    --evaluation-frequency 5m \
    --window-size 5m \
    --severity 1 \
    --description "Credentials detected in MCP response (redacted but concerning)" \
    --action-groups "$ACTION_GROUP_ID" \
    --output none 2>/dev/null || echo "Alert rule may already exist"

echo -e "${GREEN}✓ Credential exposure alert created${NC}"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Alert Rules Created${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "  🚨 $ALERT1_NAME"
echo "     Triggers: >10 injection attacks in 5 minutes"
echo "     Severity: Warning (2)"
echo ""
echo "  🚨 $ALERT2_NAME"
echo "     Triggers: Any credential exposure detected"
echo "     Severity: Error (1)"
echo ""
if [ -n "$ALERT_EMAIL" ]; then
    echo "  📧 Notifications will be sent to: $ALERT_EMAIL"
else
    echo "  📧 No email configured (alerts visible in Azure Portal)"
fi
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Section 3 Complete: Security is ACTIONABLE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "✓ Dashboard shows real-time security visibility"
echo "✓ Alerts notify you when attacks exceed thresholds"
echo "✓ Action groups can trigger automated responses"
echo ""
echo "The 'hidden → visible → actionable' pattern is complete:"
echo ""
echo "  ✓ HIDDEN:     APIM + Function had basic/no logging"
echo "  ✓ VISIBLE:    Diagnostic settings + structured logging"
echo "  ✓ ACTIONABLE: Dashboard + alerts for automated response"
echo ""
echo -e "${GREEN}Next: Run ./scripts/section4/4.1-simulate-attack.sh to test the full system${NC}"
echo ""
