#!/bin/bash
# Preprovision hook for Camp 2
# Creates Entra ID app registrations before infrastructure deployment

set -e

echo ""
echo "=========================================="
echo "Camp 2: Entra ID App Registration"
echo "=========================================="
echo ""

# Sync AZURE_LOCATION with resource group location if RG already exists
# This ensures Bicep uses the same location as the resource group
if [ -n "$AZURE_RESOURCE_GROUP" ]; then
    RG_LOCATION=$(az group show -n "$AZURE_RESOURCE_GROUP" --query location -o tsv 2>/dev/null || echo "")
    if [ -n "$RG_LOCATION" ] && [ "$RG_LOCATION" != "$AZURE_LOCATION" ]; then
        echo "Syncing AZURE_LOCATION to resource group location: $RG_LOCATION"
        azd env set AZURE_LOCATION "$RG_LOCATION"
        export AZURE_LOCATION="$RG_LOCATION"
    fi
fi

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"

# Unique name for apps
APP_SUFFIX="${AZURE_ENV_NAME:-camp2}-$(date +%s | tail -c 5)"

# Generate UUIDs upfront
SCOPE_ID=$(uuidgen)
VS_CODE_APP_ID="aebc6443-996d-45c2-90f0-388ff96faa56"
AZURE_CLI_APP_ID="04b07795-8ddb-461a-bbee-02f9e1bf7b46"

# Create MCP Resource App
echo ""
echo "Creating MCP Resource App: sherpa-mcp-client-camp2-$APP_SUFFIX"
MCP_APP_CLIENT_ID=$(az ad app create \
    --display-name "sherpa-mcp-client-camp2-$APP_SUFFIX" \
    --sign-in-audience "AzureADMyOrg" \
    --query appId -o tsv)

if [ -z "$MCP_APP_CLIENT_ID" ]; then
    echo "Failed to create MCP app"
    exit 1
fi

echo "MCP App Client ID: $MCP_APP_CLIENT_ID"

# IMPORTANT: Do NOT set identifier URI!
# When identifierUris is empty, scopes are referenced as {appId}/scope_name
# This is required for VS Code MCP OAuth to work correctly.
# Setting identifier-uris to api://{appId} would change scope format to api://{appId}/scope_name
# which breaks the token audience matching.
echo "Skipping identifier URI (must be empty for VS Code MCP OAuth)..."

# Create API scope
echo "Creating OAuth scope..."
cat > /tmp/mcp-api-scope.json <<EOF
{
  "oauth2PermissionScopes": [
    {
      "adminConsentDescription": "Allow the application to access MCP servers on behalf of the signed-in user",
      "adminConsentDisplayName": "Access MCP servers",
      "id": "$SCOPE_ID",
      "isEnabled": true,
      "type": "User",
      "userConsentDescription": "Allow this application to access MCP servers on your behalf",
      "userConsentDisplayName": "Access MCP servers",
      "value": "user_impersonate"
    }
  ]
}
EOF

az ad app update --id "$MCP_APP_CLIENT_ID" \
    --set api=@/tmp/mcp-api-scope.json

if [ $? -ne 0 ]; then
    echo "Failed to create API scope"
    rm -f /tmp/mcp-api-scope.json
    exit 1
fi

rm -f /tmp/mcp-api-scope.json
echo "API scope created"

# Wait for API update to propagate
sleep 2

# Pre-authorize VS Code and Azure CLI with updated API config
echo "Pre-authorizing VS Code and Azure CLI..."
cat > /tmp/mcp-api-full.json <<EOF
{
  "acceptMappedClaims": null,
  "knownClientApplications": [],
  "oauth2PermissionScopes": [
    {
      "adminConsentDescription": "Allow the application to access MCP servers on behalf of the signed-in user",
      "adminConsentDisplayName": "Access MCP servers",
      "id": "$SCOPE_ID",
      "isEnabled": true,
      "type": "User",
      "userConsentDescription": "Allow this application to access MCP servers on your behalf",
      "userConsentDisplayName": "Access MCP servers",
      "value": "user_impersonate"
    }
  ],
  "preAuthorizedApplications": [
    {
      "appId": "$VS_CODE_APP_ID",
      "delegatedPermissionIds": ["$SCOPE_ID"]
    },
    {
      "appId": "$AZURE_CLI_APP_ID",
      "delegatedPermissionIds": ["$SCOPE_ID"]
    }
  ],
  "requestedAccessTokenVersion": 2
}
EOF

az ad app update --id "$MCP_APP_CLIENT_ID" \
    --set api=@/tmp/mcp-api-full.json

if [ $? -ne 0 ]; then
    echo "Failed to pre-authorize clients"
    rm -f /tmp/mcp-api-full.json
    exit 1
fi

rm -f /tmp/mcp-api-full.json
echo "VS Code and Azure CLI pre-authorized"

# NOTE: We do NOT add VS Code redirect URIs to our app!
# VS Code uses its OWN Entra app (managed by Microsoft) with its own redirect URIs.
# The pre-authorization above is what allows VS Code to request tokens for our API.
# This is a cross-app OAuth flow: VS Code (client) -> our API (resource).

# Create Service Principal
echo "Creating service principal for MCP app..."
az ad sp create --id "$MCP_APP_CLIENT_ID" 2>/dev/null || echo "Service principal already exists"

# Create APIM Client App for Credential Manager
echo ""
echo "Creating APIM Client App: sherpa-apim-client-camp2-$APP_SUFFIX"
APIM_CLIENT_APP_ID=$(az ad app create \
    --display-name "sherpa-apim-client-camp2-$APP_SUFFIX" \
    --sign-in-audience "AzureADMyOrg" \
    --query appId -o tsv)

if [ -z "$APIM_CLIENT_APP_ID" ]; then
    echo "Failed to create APIM client app"
    exit 1
fi

echo "APIM Client App ID: $APIM_CLIENT_APP_ID"

# Wait for app creation to propagate
sleep 2

# Set identifier URI
echo "Setting identifier URI for APIM app..."
az ad app update --id "$APIM_CLIENT_APP_ID" \
    --identifier-uris "api://$APIM_CLIENT_APP_ID"

if [ $? -ne 0 ]; then
    echo "Failed to set identifier URI"
    exit 1
fi

# Wait for identifier URI to propagate
sleep 2

# Create client secret for APIM app (30 days expiration for workshop)
echo "Creating client secret for APIM app..."
END_DATE=$(date -u -v+30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+30 days" +%Y-%m-%dT%H:%M:%SZ)
APIM_CLIENT_SECRET=$(az ad app credential reset \
    --id "$APIM_CLIENT_APP_ID" \
    --end-date "$END_DATE" \
    --query password -o tsv)

if [ -z "$APIM_CLIENT_SECRET" ]; then
    echo "Failed to create client secret"
    exit 1
fi

echo "Client secret created (expires in 30 days)"

# Create Service Principal
echo "Creating service principal for APIM app..."
az ad sp create --id $APIM_CLIENT_APP_ID 2>/dev/null || echo "Service principal already exists"

echo ""
echo "=========================================="
echo "Entra ID Setup Complete"
echo "=========================================="
echo ""
echo "MCP Resource App:"
echo "  Client ID: $MCP_APP_CLIENT_ID"
echo "  Identifier URI: api://$MCP_APP_CLIENT_ID"
echo "  Pre-authorized: VS Code/GitHub Copilot"
echo ""
echo "APIM Client App:"
echo "  Client ID: $APIM_CLIENT_APP_ID"
echo "  Has client secret for Credential Manager"
echo ""
echo "Saving to azd environment..."
azd env set MCP_APP_CLIENT_ID "$MCP_APP_CLIENT_ID"
azd env set APIM_CLIENT_APP_ID "$APIM_CLIENT_APP_ID"
azd env set APIM_CLIENT_SECRET -- "$APIM_CLIENT_SECRET"

echo "Values saved to azd environment"
