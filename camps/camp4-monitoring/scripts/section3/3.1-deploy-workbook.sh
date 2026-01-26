#!/bin/bash
# =============================================================================
# Camp 4 - Section 3.1: Deploy Security Workbook (Dashboard)
# =============================================================================
# Pattern: hidden → visible → actionable
# Transition: VISIBLE → ACTIONABLE (part 1: visibility)
#
# This script deploys an Azure Workbook that visualizes:
# - MCP request volume over time
# - Attack attempts by type
# - Top targeted tools
# - Caller IP analysis
# - Security event timeline
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
echo -e "${CYAN}  Camp 4 - Section 3.1: Deploy Security Workbook${NC}"
echo -e "${CYAN}  Pattern: hidden → visible → actionable${NC}"
echo -e "${CYAN}  Transition: VISIBLE → ACTIONABLE${NC}"
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

echo -e "${YELLOW}What we're creating:${NC}"
echo "An Azure Workbook with pre-built visualizations for MCP security:"
echo ""
echo "  - Request volume over time"
echo "  - Attack attempts by injection type"
echo "  - Top targeted MCP tools"
echo "  - Caller IP analysis"
echo "  - Security event timeline"
echo ""

WORKBOOK_DISPLAY="MCP Security Dashboard"

# Generate a deterministic GUID for the workbook (so re-runs update instead of creating duplicates)
# Use md5 on macOS, md5sum on Linux
if command -v md5 &> /dev/null; then
    WORKBOOK_GUID=$(echo -n "$RG_NAME-mcp-security-dashboard" | md5 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\).*/\1-\2-\3-\4-\5/')
else
    WORKBOOK_GUID=$(echo -n "$RG_NAME-mcp-security-dashboard" | md5sum | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\).*/\1-\2-\3-\4-\5/')
fi

echo -e "${BLUE}Creating workbook (ID: $WORKBOOK_GUID)...${NC}"

# Create ARM template using Python helper script for proper JSON escaping
# The workbook JSON has complex nested escaping that's error-prone in bash
WORKSPACE_ID="$WORKSPACE_ID" \
WORKBOOK_GUID="$WORKBOOK_GUID" \
LOCATION="$LOCATION" \
OUTPUT_FILE="/tmp/mcp-workbook-template.json" \
python3 "$SCRIPT_DIR/create-workbook-template.py"

# Deploy the workbook via ARM template
az deployment group create \
    --resource-group "$RG_NAME" \
    --template-file /tmp/mcp-workbook-template.json \
    --output none

echo ""
echo -e "${GREEN}✓ Security workbook created!${NC}"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Access Your Dashboard${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "Open the Azure Portal and navigate to:"
echo ""
echo "  1. Go to your Log Analytics workspace"
echo "  2. Click 'Workbooks' in the left menu"
echo "  3. Select '$WORKBOOK_DISPLAY' from the list"
echo ""

# Get workspace name for the URL
WORKSPACE_NAME=$(az monitor log-analytics workspace show --ids "$WORKSPACE_ID" --query name -o tsv 2>/dev/null)
SUB_ID=$(az account show --query id -o tsv)
echo "Direct link to workbooks:"
echo "  https://portal.azure.com/#@/resource/subscriptions/$SUB_ID/resourceGroups/$RG_NAME/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME/workbooks"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Dashboard Panels${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "  [✓] MCP Request Volume - Shows traffic patterns over 24h"
echo "  [✓] Attacks by Type - Pie chart of injection types"
echo "  [✓] Top Targeted Tools - Which MCP tools attackers target"
echo "  [✓] Error Sources - IPs generating the most errors"
echo "  [✓] Recent Events - Live feed of security events"
echo ""
echo "The dashboard updates in near-real-time as logs are ingested."
echo ""
echo -e "${YELLOW}Tip: If the dashboard appears empty, do a hard refresh (Cmd+Shift+R or Ctrl+Shift+R)${NC}"
echo ""
echo -e "${GREEN}Next: Run ./scripts/section3/3.2-create-alerts.sh to set up alerting${NC}"
echo ""
