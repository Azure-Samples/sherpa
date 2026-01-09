#!/bin/bash
# Full deployment orchestration for Camp 2

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAMP_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Camp 2: Gateway Security - Full Deployment"
echo "=========================================="

# Check prerequisites
echo "Checking prerequisites..."
command -v az >/dev/null 2>&1 || { echo "Azure CLI required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required but not installed."; exit 1; }

# Login check
az account show >/dev/null 2>&1 || { echo "Please login with 'az login'"; exit 1; }

# Environment variables
AZURE_ENV_NAME="${AZURE_ENV_NAME:-camp2}"
AZURE_LOCATION="${AZURE_LOCATION:-eastus}"

echo "Environment: $AZURE_ENV_NAME"
echo "Location: $AZURE_LOCATION"

# Step 1: Set up Entra ID app registrations
echo ""
echo "Step 1: Setting up Entra ID app registrations..."
source "$SCRIPT_DIR/setup-entra-apps.sh"

# Step 2: Deploy infrastructure
echo ""
echo "Step 2: Deploying infrastructure..."
az deployment sub create \
    --name "camp2-${AZURE_ENV_NAME}-$(date +%s)" \
    --location "$AZURE_LOCATION" \
    --template-file "$CAMP_DIR/infra/main.bicep" \
    --parameters environmentName="$AZURE_ENV_NAME" \
    --parameters location="$AZURE_LOCATION" \
    --parameters mcpAppClientId="$MCP_APP_CLIENT_ID" \
    --parameters apimClientAppId="$APIM_CLIENT_APP_ID"

# Get outputs
DEPLOYMENT_NAME=$(az deployment sub list --query "[?starts_with(name, 'camp2-${AZURE_ENV_NAME}')].name" -o tsv | head -n 1)
RG_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.AZURE_RESOURCE_GROUP.value' -o tsv)
ACR_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.AZURE_CONTAINER_REGISTRY_NAME.value' -o tsv)
APIM_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.APIM_NAME.value' -o tsv)
APIM_GATEWAY_URL=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.APIM_GATEWAY_URL.value' -o tsv)
API_CENTER_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.API_CENTER_NAME.value' -o tsv)

export RG_NAME ACR_NAME APIM_NAME APIM_GATEWAY_URL API_CENTER_NAME

# Update Entra ID redirect URI with actual APIM gateway URL
echo ""
echo "Updating Entra ID redirect URI..."
az ad app update --id "$MCP_APP_CLIENT_ID" \
    --web-redirect-uris "$APIM_GATEWAY_URL/auth/callback"

# Step 3: Build and push container images
echo ""
echo "Step 3: Building and pushing container images..."
source "$SCRIPT_DIR/build-and-push.sh"

# Wait for container apps to update
echo ""
echo "Waiting for container apps to update with new images (60s)..."
sleep 60

# Step 4: Import MCP servers to APIM
echo ""
echo "Step 4: Configuring MCP servers in APIM..."
source "$SCRIPT_DIR/import-mcp-to-apim.sh"

# Step 5: Set up API Center
echo ""
echo "Step 5: Setting up API Center..."
source "$SCRIPT_DIR/setup-api-center.sh"

# Step 6: Configure Credential Manager
echo ""
echo "Step 6: Configuring Credential Manager..."
source "$SCRIPT_DIR/configure-credential-manager.sh"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "APIM Gateway URL: $APIM_GATEWAY_URL"
echo "Sherpa MCP Server: $APIM_GATEWAY_URL/sherpa-mcp/mcp"
echo "Trail MCP Server: $APIM_GATEWAY_URL/trail-mcp/mcp"
echo ""
echo "MCP App Client ID: $MCP_APP_CLIENT_ID"
echo ""
echo "Next steps:"
echo "1. Configure VS Code MCP settings:"
echo "   - Add MCP server URL: $APIM_GATEWAY_URL/sherpa-mcp/mcp"
echo "   - OAuth will be discovered automatically via PRM"
echo "2. Test OAuth flow: cd tests && ./test-oauth-flow.sh"
echo "3. Test MCP tools: Get token and run ./tests/test-mcp-tools.sh"
echo "4. Test content safety: ./tests/test-content-safety.sh"
echo ""
echo "For full workshop instructions, see: docs/camps/camp2-gateway.md"
