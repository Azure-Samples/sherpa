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

if [ -z "${APP_ID}" ]; then
    echo "❌ Failed to create app registration"
    exit 1
fi

echo "✅ App ID: ${APP_ID}"

# Set identifier URI
echo "Setting identifier URI..."
az ad app update \
    --id "${APP_ID}" \
    --identifier-uris "api://${APP_ID}"

# Expose an API with a default scope
echo "Exposing API scope..."
SCOPE_ID=$(uuidgen)
AZURE_CLI_APP_ID="04b07795-8ddb-461a-bbee-02f9e1bf7b46"
VSCODE_CLIENT_ID="aebc6443-996d-45c2-90f0-388ff96faa56"

# Step 1: Create the API scope first (without pre-authorized apps)
cat > /tmp/api-scope.json <<EOF
{
  "oauth2PermissionScopes": [
    {
      "adminConsentDescription": "Allow the application to access the MCP server on behalf of the signed-in user",
      "adminConsentDisplayName": "Access MCP server",
      "id": "${SCOPE_ID}",
      "isEnabled": true,
      "type": "User",
      "userConsentDescription": "Allow the application to access the MCP server on your behalf",
      "userConsentDisplayName": "Access MCP server",
      "value": "access_as_user"
    }
  ]
}
EOF

az ad app update \
    --id "${APP_ID}" \
    --set api=@/tmp/api-scope.json

if [ $? -ne 0 ]; then
    echo "❌ Failed to configure API scope"
    rm -f /tmp/api-scope.json
    exit 1
fi

rm -f /tmp/api-scope.json
echo "✅ API scope created"

# Wait a moment for the API update to propagate
sleep 2

# Step 2: Now add pre-authorized applications by fetching current api and updating it
echo "Pre-authorizing clients (Azure CLI + VS Code)..."

# Fetch current API configuration and add pre-authorized apps
az ad app show --id "${APP_ID}" --query "api" > /tmp/current-api.json

# Create updated API config with pre-authorized apps
cat > /tmp/updated-api.json <<EOF
{
  "acceptMappedClaims": null,
  "knownClientApplications": [],
  "oauth2PermissionScopes": [
    {
      "adminConsentDescription": "Allow the application to access the MCP server on behalf of the signed-in user",
      "adminConsentDisplayName": "Access MCP server",
      "id": "${SCOPE_ID}",
      "isEnabled": true,
      "type": "User",
      "userConsentDescription": "Allow the application to access the MCP server on your behalf",
      "userConsentDisplayName": "Access MCP server",
      "value": "access_as_user"
    }
  ],
  "preAuthorizedApplications": [
    {
      "appId": "${AZURE_CLI_APP_ID}",
      "delegatedPermissionIds": ["${SCOPE_ID}"]
    },
    {
      "appId": "${VSCODE_CLIENT_ID}",
      "delegatedPermissionIds": ["${SCOPE_ID}"]
    }
  ],
  "requestedAccessTokenVersion": 2
}
EOF

az ad app update \
    --id "${APP_ID}" \
    --set api=@/tmp/updated-api.json

if [ $? -ne 0 ]; then
    echo "❌ Failed to pre-authorize clients"
    rm -f /tmp/current-api.json /tmp/updated-api.json
    exit 1
fi

rm -f /tmp/current-api.json /tmp/updated-api.json
echo "✅ Clients pre-authorized"

# Add redirect URI for device code flow
az ad app update \
    --id "${APP_ID}" \
    --public-client-redirect-uris "${REDIRECT_URI}"

if [ $? -ne 0 ]; then
    echo "❌ Failed to configure public client redirect URIs"
    exit 1
fi

echo "✅ Public client configured"

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

if [ -z "${TENANT_ID}" ]; then
    echo "❌ Failed to get tenant ID"
    exit 1
fi

echo ""
echo "✅ Entra ID Application Registered!"
echo "===================================="
echo "App Name: ${APP_NAME}"
echo "Client ID: ${APP_ID}"
echo "Tenant ID: ${TENANT_ID}"
echo "Identifier URI: api://${APP_ID}"
echo ""
echo "✅ Pre-authorized clients:"
echo "   - Azure CLI (for Device Code Flow)"
echo "   - VS Code (for PRM-based authentication)"
echo ""
echo "📝 Save these values - you'll need them for deployment!"
echo ""
echo "Add to your .env file:"
echo "AZURE_TENANT_ID=${TENANT_ID}"
echo "AZURE_CLIENT_ID=${APP_ID}"
