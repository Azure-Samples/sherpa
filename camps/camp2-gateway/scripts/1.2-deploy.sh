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

# Extract and save subscription key
SUB_KEY=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.subscriptionKey.value')
azd env set TRAIL_API_SUBSCRIPTION_KEY "$SUB_KEY"

echo ""
echo "=========================================="
echo "Trail API Deployed"
echo "=========================================="
echo ""
echo "Endpoint: $APIM_URL/trailapi/trails"
echo "Subscription Key: $SUB_KEY"
echo ""
echo "Current security: Subscription key only"
echo ""
echo "Next: See why subscription keys aren't enough"
echo "  ./scripts/1.2-exploit.sh"
echo ""
