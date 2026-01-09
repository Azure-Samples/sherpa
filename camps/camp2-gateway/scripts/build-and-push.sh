#!/bin/bash
# Build and push Docker images to Azure Container Registry

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAMP_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Building and pushing container images"
echo "=========================================="

# Check if ACR_NAME is set
if [ -z "$ACR_NAME" ]; then
    echo "Error: ACR_NAME environment variable not set"
    exit 1
fi

# Log in to ACR
echo "Logging in to Azure Container Registry..."
az acr login --name "$ACR_NAME"

# Build and push Sherpa MCP Server
echo ""
echo "Building Sherpa MCP Server..."
cd "$CAMP_DIR/servers/sherpa-mcp-server"
docker build -t "$ACR_NAME.azurecr.io/sherpa-mcp-server:latest" .

echo "Pushing Sherpa MCP Server..."
docker push "$ACR_NAME.azurecr.io/sherpa-mcp-server:latest"

# Build and push Trail API
echo ""
echo "Building Trail API..."
cd "$CAMP_DIR/servers/trail-api"
docker build -t "$ACR_NAME.azurecr.io/trail-api:latest" .

echo "Pushing Trail API..."
docker push "$ACR_NAME.azurecr.io/trail-api:latest"

echo ""
echo "=========================================="
echo "Images successfully pushed to ACR"
echo "=========================================="
