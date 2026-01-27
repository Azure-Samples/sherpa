#!/bin/bash
set -e

echo "Camp 1: Migrate Secrets to Key Vault"
echo "======================================="

# Load azd environment variables
echo "Loading azd environment..."
eval "$(azd env get-values | sed 's/^/export /')"

# Verify we have the necessary variables
if [ -z "${AZURE_KEY_VAULT_NAME}" ]; then
    echo "Error: AZURE_KEY_VAULT_NAME not found in azd environment."
    echo "Make sure you've run 'azd provision' first."
    exit 1
fi

echo "Creating demo secrets in Key Vault: ${AZURE_KEY_VAULT_NAME}"
echo ""

# Get current user's object ID
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Grant current user Key Vault Secrets Officer role to create secrets
echo "Granting you Key Vault Secrets Officer role..."
az role assignment create \
    --role "Key Vault Secrets Officer" \
    --assignee "${USER_OBJECT_ID}" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${AZURE_KEY_VAULT_NAME}" \
    --output none 2>/dev/null || echo "   (Role assignment already exists)"

echo "   Waiting for RBAC propagation (10 seconds)..."
sleep 10

# Create sample secrets
echo ""
echo "Creating demo-api-key..."
az keyvault secret set \
    --vault-name "${AZURE_KEY_VAULT_NAME}" \
    --name "demo-api-key" \
    --value "sk-secure-$(openssl rand -hex 8)" \
    --output none

echo "Creating external-service-secret..."
az keyvault secret set \
    --vault-name "${AZURE_KEY_VAULT_NAME}" \
    --name "external-service-secret" \
    --value "secret-$(openssl rand -hex 8)" \
    --output none

echo ""
echo "Secrets created in Key Vault!"
echo ""
echo "Current secrets:"
az keyvault secret list \
    --vault-name "${AZURE_KEY_VAULT_NAME}" \
    --query "[].{Name:name, Enabled:attributes.enabled}" \
    -o table

echo ""
echo "These secrets are now accessible by the secure server via Managed Identity!"
