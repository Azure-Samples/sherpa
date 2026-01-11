#!/bin/bash
# Waypoint 1.2: Deploy Trail API
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.2: Deploy Trail API"
echo "=========================================="
echo ""

# Deploy the container service
echo "Building and deploying Trail API..."
azd deploy trail-api

# Get environment values
RG=$(azd env get-value AZURE_RESOURCE_GROUP)
APIM_NAME=$(azd env get-value APIM_NAME)
APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
TRAIL_URL=$(azd env get-value TRAIL_API_URL)

echo ""
echo "Configuring APIM backend and API with subscription key..."

# Build bicep to ARM JSON (workaround for CLI issues)
az bicep build --file infra/waypoints/1.2-deploy-trail.bicep --outfile /tmp/trail-api.json 2>/dev/null

# Deploy APIM configuration
DEPLOYMENT_OUTPUT=$(az deployment group create \
  --resource-group "$RG" \
  --template-file /tmp/trail-api.json \
  --parameters apimName="$APIM_NAME" \
               backendUrl="$TRAIL_URL" \
  --query "properties.outputs" -o json)

# Extract and save subscription key (for Trail Services Product)
SUB_KEY=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.subscriptionKey.value')
azd env set TRAIL_SUBSCRIPTION_KEY "$SUB_KEY"

echo ""
echo "Exporting Trail API as MCP server..."

# Build and deploy MCP export layer
az bicep build --file infra/waypoints/1.2-deploy-trail-mcp.bicep --outfile /tmp/trail-mcp.json 2>/dev/null

MCP_OUTPUT=$(az deployment group create \
  --resource-group "$RG" \
  --template-file /tmp/trail-mcp.json \
  --parameters apimName="$APIM_NAME" \
  --query "properties.outputs" -o json)

MCP_ENDPOINT=$(echo "$MCP_OUTPUT" | jq -r '.mcpEndpoint.value')

echo ""
echo "=========================================="
echo "Trail API Deployed as MCP Server"
echo "=========================================="
echo ""
echo "Trail Services Product:"
echo "  Subscription Key: ${SUB_KEY:0:8}...${SUB_KEY: -4}"
echo ""
echo "REST Endpoint: $APIM_URL/trailapi/trails"
echo "MCP Endpoint:  $MCP_ENDPOINT"
echo ""
echo "MCP Tools available:"
echo "  - list_trails: List all available hiking trails"
echo "  - get_trail: Get details for a specific trail"
echo "  - check_conditions: Current trail conditions and hazards"
echo "  - get_permit: Retrieve a trail permit"
echo "  - request_permit: Request a new trail permit"
echo ""
echo "Current security: Subscription key only (no authentication!)"
echo ""
