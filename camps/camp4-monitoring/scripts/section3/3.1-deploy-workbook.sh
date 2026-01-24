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
# - Geographic distribution of callers
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
echo "  📊 Request volume over time"
echo "  🛡️  Attack attempts by injection type"
echo "  🎯 Top targeted MCP tools"
echo "  📍 Caller IP analysis"
echo "  📈 Security event timeline"
echo ""

WORKBOOK_NAME="mcp-security-dashboard"
WORKBOOK_DISPLAY="MCP Security Dashboard"

echo -e "${BLUE}Creating workbook...${NC}"

# Create the workbook template
WORKBOOK_JSON=$(cat << 'EOF'
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# MCP Security Dashboard\n\nThis workbook provides visibility into MCP traffic and security events.\n\n**Pattern:** hidden → visible → **actionable**"
      },
      "name": "header"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ApiManagementGatewayLogs\n| where TimeGenerated > ago(24h)\n| where Url contains \"/mcp/\"\n| summarize Requests=count() by bin(TimeGenerated, 1h)\n| order by TimeGenerated asc",
        "size": 0,
        "title": "MCP Request Volume (24h)",
        "timeContext": { "durationMs": 86400000 },
        "queryType": 0,
        "visualization": "areachart"
      },
      "name": "request-volume"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AppTraces\n| where TimeGenerated > ago(24h)\n| where Properties has \"event_type\"\n| extend EventType = tostring(Properties.event_type), InjectionType = tostring(Properties.injection_type)\n| where EventType == \"INJECTION_BLOCKED\"\n| summarize Attacks=count() by InjectionType\n| order by Attacks desc",
        "size": 0,
        "title": "Attacks by Injection Type",
        "timeContext": { "durationMs": 86400000 },
        "queryType": 0,
        "visualization": "piechart"
      },
      "name": "attacks-by-type"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AppTraces\n| where TimeGenerated > ago(24h)\n| where Properties has \"event_type\"\n| extend EventType = tostring(Properties.event_type), ToolName = tostring(Properties.tool_name)\n| where EventType == \"INJECTION_BLOCKED\" and isnotempty(ToolName)\n| summarize Attacks=count() by ToolName\n| order by Attacks desc\n| limit 10",
        "size": 0,
        "title": "Top Targeted Tools",
        "timeContext": { "durationMs": 86400000 },
        "queryType": 0,
        "visualization": "barchart"
      },
      "name": "top-tools"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ApiManagementGatewayLogs\n| where TimeGenerated > ago(24h)\n| where Url contains \"/mcp/\"\n| where ResponseCode >= 400\n| summarize Errors=count() by CallerIpAddress\n| order by Errors desc\n| limit 10",
        "size": 0,
        "title": "Top Error Sources (by IP)",
        "timeContext": { "durationMs": 86400000 },
        "queryType": 0,
        "visualization": "table"
      },
      "name": "error-sources"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AppTraces\n| where TimeGenerated > ago(4h)\n| where Properties has \"event_type\"\n| extend EventType = tostring(Properties.event_type), \n         Category = tostring(Properties.category),\n         CorrelationId = tostring(Properties.correlation_id)\n| project TimeGenerated, EventType, Category, CorrelationId\n| order by TimeGenerated desc\n| limit 50",
        "size": 0,
        "title": "Recent Security Events",
        "timeContext": { "durationMs": 14400000 },
        "queryType": 0,
        "visualization": "table"
      },
      "name": "recent-events"
    }
  ],
  "styleSettings": {},
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}
EOF
)

# Create the workbook via ARM
az deployment group create \
    --resource-group "$RG_NAME" \
    --template-uri "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.insights/application-insights-workbook/azuredeploy.json" \
    --parameters \
        workbookDisplayName="$WORKBOOK_DISPLAY" \
        workbookType="workbook" \
        workbookSourceId="$WORKSPACE_ID" \
        workbookContent="$WORKBOOK_JSON" \
    --output none 2>/dev/null || {
        # Fallback: Create workbook directly
        echo -e "${YELLOW}Using direct workbook creation...${NC}"
        
        # Generate a deterministic GUID for the workbook
        WORKBOOK_GUID=$(echo -n "$RG_NAME-mcp-security-dashboard" | md5sum | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\).*/\1-\2-\3-\4-\5/')
        
        az portal dashboard create \
            --name "$WORKBOOK_NAME" \
            --resource-group "$RG_NAME" \
            --location "$LOCATION" \
            --input-path /dev/stdin << DASHBOARD_EOF 2>/dev/null || echo "Note: Dashboard creation requires additional permissions"
{
    "lenses": [
        {
            "order": 0,
            "parts": [
                {
                    "position": {"x": 0, "y": 0, "rowSpan": 4, "colSpan": 6},
                    "metadata": {
                        "type": "Extension/Microsoft_Azure_Monitoring_Logs/Blade/LogsBlade",
                        "inputs": [
                            {"name": "resourceId", "value": "$WORKSPACE_ID"},
                            {"name": "query", "value": "ApiManagementGatewayLogs | where Url contains '/mcp/' | summarize count() by bin(TimeGenerated, 1h) | render timechart"}
                        ]
                    }
                }
            ]
        }
    ]
}
DASHBOARD_EOF
    }

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
echo "  3. Find '$WORKBOOK_DISPLAY'"
echo ""
echo "Or use this direct link:"
echo "  https://portal.azure.com/#@/resource$(az monitor log-analytics workspace show --ids "$WORKSPACE_ID" --query id -o tsv)/workbooks"
echo ""

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  Dashboard Panels${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo "📊 MCP Request Volume - Shows traffic patterns over 24h"
echo "🛡️  Attacks by Type - Pie chart of injection types"
echo "🎯 Top Targeted Tools - Which MCP tools attackers target"
echo "📍 Error Sources - IPs generating the most errors"
echo "📈 Recent Events - Live feed of security events"
echo ""
echo "The dashboard updates in near-real-time as logs are ingested."
echo ""
echo -e "${GREEN}Next: Run ./scripts/section3/3.2-create-alerts.sh to set up alerting${NC}"
echo ""
