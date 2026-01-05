#!/bin/bash
set -e

echo "🔐 Camp 1: Register Entra ID Application"
echo "========================================"

APP_NAME="sherpa-mcp-camp1-$(date +%s)"
REDIRECT_URI="http://localhost:8080/callback"

echo "Creating Entra ID app registration: ${APP_NAME}"
echo ""

# Create app registration
APP_ID=$(az ad app create \
    --display-name "${APP_NAME}" \
    --sign-in-audience "AzureADMyOrg" \
    --query appId -o tsv)

echo "✅ App ID: ${APP_ID}"

# Set identifier URI
echo "Setting identifier URI..."
az ad app update \
    --id "${APP_ID}" \
    --identifier-uris "api://${APP_ID}"

# Expose an API with a default scope and pre-authorize Azure CLI
echo "Exposing API scope and pre-authorizing Azure CLI..."
SCOPE_ID=$(uuidgen)
AZURE_CLI_APP_ID="04b07795-8ddb-461a-bbee-02f9e1bf7b46"
az ad app update \
    --id "${APP_ID}" \
    --set api="{\"oauth2PermissionScopes\": [{\"adminConsentDescription\": \"Allow the application to access the MCP server on behalf of the signed-in user\", \"adminConsentDisplayName\": \"Access MCP server\", \"id\": \"${SCOPE_ID}\", \"isEnabled\": true, \"type\": \"User\", \"userConsentDescription\": \"Allow the application to access the MCP server on your behalf\", \"userConsentDisplayName\": \"Access MCP server\", \"value\": \"access_as_user\"}], \"preAuthorizedApplications\": [{\"appId\": \"${AZURE_CLI_APP_ID}\", \"delegatedPermissionIds\": [\"${SCOPE_ID}\"]}]}"

# Add redirect URI for device code flow
echo "Configuring public client (device code flow)..."
az ad app update \
    --id "${APP_ID}" \
    --public-client-redirect-uris "${REDIRECT_URI}"

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

echo ""
echo "✅ Entra ID Application Registered!"
echo "===================================="
echo "App Name: ${APP_NAME}"
echo "Client ID: ${APP_ID}"
echo "Tenant ID: ${TENANT_ID}"
echo "Identifier URI: api://${APP_ID}"
echo ""
echo "📝 Save these values - you'll need them for deployment!"
echo ""
echo "Add to your .env file:"
echo "AZURE_TENANT_ID=${TENANT_ID}"
echo "AZURE_CLIENT_ID=${APP_ID}"
