#!/bin/bash
# Waypoint 1.4: Register remote MCP servers in API Center

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

get_azd_value() {
    local name="$1"
    local value
    value=$(azd env get-value "$name" 2>/dev/null || true)
    if [ -z "$value" ] || [[ "$value" == ERROR:* ]]; then
        echo "Error: $name is not set in the current azd environment." >&2
        exit 1
    fi
    printf '%s' "$value"
}

echo ""
echo "=========================================="
echo "Waypoint 1.4: API Center MCP Registry"
echo "=========================================="
echo ""

RG=$(get_azd_value AZURE_RESOURCE_GROUP)
APIM_URL=$(get_azd_value APIM_GATEWAY_URL)
APIM_NAME=$(get_azd_value APIM_NAME)
API_CENTER_NAME=$(get_azd_value API_CENTER_NAME)

CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)
if [ -z "$CURRENT_USER_OBJECT_ID" ]; then
    echo "Error: Unable to resolve the signed-in user's Entra object ID." >&2
    echo "Run 'az login' with a user account before retrying." >&2
    exit 1
fi

APIM_RESOURCE_ID=$(az apim show \
    --resource-group "$RG" \
    --name "$APIM_NAME" \
    --query id -o tsv)

API_CENTER_RESOURCE_ID=$(az apic show \
    --resource-group "$RG" \
    --name "$API_CENTER_NAME" \
    --query id -o tsv)

echo "Registering remote MCP servers..."
echo "  API Center: $API_CENTER_NAME"
echo "  Lifecycle: Preview"
echo "  Environment: Camp 2 APIM Gateway"
echo ""

DEPLOYMENT_OUTPUTS=$(az deployment group create \
    --name camp2-waypoint-1-4 \
    --resource-group "$RG" \
    --template-file infra/waypoints/1.4-apicenter.bicep \
    --parameters apiCenterName="$API_CENTER_NAME" \
                 apimGatewayUrl="$APIM_URL" \
                 apimResourceId="$APIM_RESOURCE_ID" \
                 currentUserObjectId="$CURRENT_USER_OBJECT_ID" \
    --query properties.outputs \
    --output json)

REGISTRY_ENDPOINT=$(printf '%s' "$DEPLOYMENT_OUTPUTS" | jq -r '.mcpRegistryEndpoint.value')

echo "Validating API Center records..."
for API_NAME in sherpa-mcp trails-mcp; do
    API_KIND=$(az rest \
        --method get \
        --uri "https://management.azure.com${API_CENTER_RESOURCE_ID}/workspaces/default/apis/${API_NAME}?api-version=2024-06-01-preview" \
        --query properties.kind -o tsv)
    VERSION_STAGE=$(az rest \
        --method get \
        --uri "https://management.azure.com${API_CENTER_RESOURCE_ID}/workspaces/default/apis/${API_NAME}/versions/v1-0-0?api-version=2024-06-01-preview" \
        --query properties.lifecycleStage -o tsv)
    RUNTIME_URL=$(az rest \
        --method get \
        --uri "https://management.azure.com${API_CENTER_RESOURCE_ID}/workspaces/default/apis/${API_NAME}/deployments/camp2-apim?api-version=2024-06-01-preview" \
        --query "properties.server.runtimeUri[0]" -o tsv)

    EXPECTED_PATH="$API_NAME"
    if [ "$API_NAME" = "sherpa-mcp" ]; then
        EXPECTED_PATH="sherpa/mcp"
    else
        EXPECTED_PATH="trails/mcp"
    fi

    if [ "$API_KIND" != "mcp" ] || [ "$VERSION_STAGE" != "preview" ] || [ "$RUNTIME_URL" != "$APIM_URL/$EXPECTED_PATH" ]; then
        echo "Error: API Center validation failed for $API_NAME." >&2
        exit 1
    fi
done

ROLE_COUNT=$(az role assignment list \
    --assignee "$CURRENT_USER_OBJECT_ID" \
    --scope "$API_CENTER_RESOURCE_ID" \
    --query "[?roleDefinitionName=='Azure API Center Data Reader'] | length(@)" \
    -o tsv)
if [ "$ROLE_COUNT" -lt 1 ]; then
    echo "Error: Azure API Center Data Reader assignment was not found." >&2
    exit 1
fi

REGISTRY_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" "$REGISTRY_ENDPOINT")
if [ "$REGISTRY_STATUS" != "401" ]; then
    echo "Error: Expected the protected MCP Registry endpoint to return HTTP 401 without a token; received $REGISTRY_STATUS." >&2
    exit 1
fi

echo ""
echo "=========================================="
echo "API Center Registration Complete"
echo "=========================================="
echo ""
echo "Registered remote MCP servers:"
echo "  - Sherpa MCP Server ($APIM_URL/sherpa/mcp)"
echo "  - Trails MCP Server ($APIM_URL/trails/mcp)"
echo ""
echo "Discovery profile:"
echo "  - Version: 1.0.0 (Preview)"
echo "  - Transport: Streamable HTTP"
echo "  - Security: Workshop / non-production"
echo "  - Sherpa auth: Microsoft Entra OAuth"
echo "  - Trails auth: Microsoft Entra OAuth + APIM subscription key"
echo "  - Credentials are not stored in API Center"
echo ""
echo "MCP Registry:"
echo "  $REGISTRY_ENDPOINT"
echo ""
echo "Foundry Tools:"
echo "  1. Open your Foundry project"
echo "  2. Go to Build > Tools"
echo "  3. Find the private catalog named: $API_CENTER_NAME"
echo ""
echo "Azure API Center Data Reader was assigned to the signed-in participant."
echo "Role propagation can take up to 24 hours."
echo ""
echo "View in Azure Portal:"
echo "  https://portal.azure.com/#resource$API_CENTER_RESOURCE_ID"
echo ""
