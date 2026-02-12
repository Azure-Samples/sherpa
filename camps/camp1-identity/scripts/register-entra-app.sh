#!/bin/bash
set -e

echo "🔐 Camp 1: Register Entra ID Application"
echo "========================================"

APP_NAME="sherpa-mcp-camp1-$(date +%s)"
DEVICE_CODE_REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"

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

# Add redirect URIs for device code flow, VS Code OAuth, and demo client
echo "Configuring redirect URIs..."
az ad app update \
    --id "${APP_ID}" \
    --public-client-redirect-uris "${DEVICE_CODE_REDIRECT_URI}" \
    --web-redirect-uris "http://127.0.0.1:33418" "https://vscode.dev/redirect" "http://localhost:8090/callback"

if [ $? -ne 0 ]; then
    echo "❌ Failed to configure redirect URIs"
    exit 1
fi

echo "✅ Redirect URIs configured"
echo "   Public client: device code flow"
echo "   Web: VS Code OAuth, demo client (port 8090)"

# Set as confidential client (allows client secrets for demo)
# Note: isFallbackPublicClient=false means the app uses client secrets
# This is needed for the demo client with authorization code flow
echo "Configuring client type (confidential for demo with secrets)..."
az ad app update \
    --id "${APP_ID}" \
    --set isFallbackPublicClient=false

if [ $? -ne 0 ]; then
    echo "❌ Failed to configure client type"
    exit 1
fi

echo "✅ Client type configured (confidential - supports client secrets)"

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

if [ -z "${TENANT_ID}" ]; then
    echo "❌ Failed to get tenant ID"
    exit 1
fi

# Save to azd environment
echo "Saving to azd environment..."
azd env set AZURE_CLIENT_ID "${APP_ID}"
azd env set AZURE_TENANT_ID "${TENANT_ID}"
echo "✅ Environment variables saved"

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
echo "✅ Redirect URIs configured:"
echo "   - urn:ietf:wg:oauth:2.0:oob (device code flow)"
echo "   - http://127.0.0.1:33418 (VS Code)"
echo "   - https://vscode.dev/redirect (VS Code)"
echo "   - http://localhost:8090/callback (demo client)"
echo ""
echo "✅ Environment variables set:"
echo "   AZURE_CLIENT_ID=${APP_ID}"
echo "   AZURE_TENANT_ID=${TENANT_ID}"
echo ""
echo "💡 To enable the demo client with full OAuth flow:"
echo "   Run: ./scripts/generate-client-secret.sh"
