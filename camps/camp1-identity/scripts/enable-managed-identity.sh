#!/bin/bash
set -e

echo "🔐 Camp 1: Enable Managed Identity"
echo "=================================="

# Load azd environment variables
echo "📦 Loading azd environment..."
eval "$(azd env get-values | sed 's/^/export /')"

# Verify we have the necessary variables
if [ -z "${AZURE_MANAGED_IDENTITY_PRINCIPAL_ID}" ]; then
    echo "❌ Error: AZURE_MANAGED_IDENTITY_PRINCIPAL_ID not found in azd environment."
    echo "Make sure you've run 'azd provision' first."
    exit 1
fi

echo "✅ Managed Identity Principal ID: ${AZURE_MANAGED_IDENTITY_PRINCIPAL_ID}"
echo ""

echo "🔍 Verifying Key Vault role assignment..."
az role assignment list \
    --assignee "${AZURE_MANAGED_IDENTITY_PRINCIPAL_ID}" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${AZURE_KEY_VAULT_NAME}" \
    --query "[?roleDefinitionName=='Key Vault Secrets User'].{Role:roleDefinitionName, Scope:scope}" \
    -o table

echo ""
echo "✅ Managed Identity setup complete!"
echo "The Container App can now access Key Vault secrets without passwords."
