#!/bin/bash
# Configure MCP servers in APIM after infrastructure deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="$SCRIPT_DIR/../infra/policies"

echo "=========================================="
echo "Importing MCP Servers to APIM"
echo "=========================================="

# Check required variables
if [ -z "$APIM_NAME" ] || [ -z "$RG_NAME" ]; then
    echo "Error: APIM_NAME and RG_NAME must be set"
    exit 1
fi

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Note: APIM policies are applied using Azure REST API
# The Azure CLI doesn't have direct policy commands

echo "Applying OAuth validation policy to Sherpa MCP Server..."
OAUTH_POLICY_JSON=$(jq -n --arg value "$(cat "$POLICIES_DIR/oauth-validation-policy.xml")" '{properties: {value: $value, format: "xml"}}')
az rest --method put \
    --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME/apis/sherpa-mcp-api/policies/policy?api-version=2023-09-01-preview" \
    --body "$OAUTH_POLICY_JSON"

echo "Applying OAuth validation policy to Trail MCP Server..."
az rest --method put \
    --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME/apis/trail-mcp-api/policies/policy?api-version=2023-09-01-preview" \
    --body "$OAUTH_POLICY_JSON"

# Apply credential manager policy to the permits operation
echo "Applying Credential Manager policy to Trail permits operation..."
CRED_POLICY_JSON=$(jq -n --arg value "$(cat "$POLICIES_DIR/credential-manager-policy.xml")" '{properties: {value: $value, format: "xml"}}')
az rest --method put \
    --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME/apis/trail-mcp-api/operations/get-trail-permits/policies/policy?api-version=2023-09-01-preview" \
    --body "$CRED_POLICY_JSON" 2>&1 | grep -v "Not a json response" || echo "  Note: Apply policy via Azure Portal if operation doesn't exist yet"

echo ""
echo "✓ MCP servers configured successfully"
echo "  • OAuth validation: Sherpa MCP, Trail MCP"
echo "  • Credential Manager: Trail permits endpoint"
echo "Note: Rate limiting can be configured per-operation in the Azure Portal if needed"

echo ""
echo "MCP servers configured successfully"
