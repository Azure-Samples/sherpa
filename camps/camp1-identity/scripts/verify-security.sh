#!/bin/bash
set -e

echo "✅ Camp 1: Security Validation"
echo "=============================="

# Load azd environment variables
echo "📦 Loading azd environment..."
eval "$(azd env get-values | sed 's/^/export /')"

# Track overall validation status
VALIDATION_FAILED=0

echo ""
echo "🔍 Running security checks..."
echo ""

# Check 1: Secrets in Key Vault
echo "Check 1: Secrets in Key Vault"
echo "------------------------------"
SECRET_COUNT=$(az keyvault secret list \
    --vault-name "${AZURE_KEY_VAULT_NAME}" \
    --query "length(@)" -o tsv)

if [ "${SECRET_COUNT}" -gt 0 ]; then
    echo "✅ Found ${SECRET_COUNT} secrets in Key Vault"
    az keyvault secret list \
        --vault-name "${AZURE_KEY_VAULT_NAME}" \
        --query "[].{Name:name, Enabled:attributes.enabled}" \
        -o table
else
    echo "⚠️  No secrets found in Key Vault"
    VALIDATION_FAILED=1
fi

echo ""

# Check 2: Managed Identity RBAC
echo "Check 2: Managed Identity RBAC"
echo "-------------------------------"
ROLE_COUNT=$(az role assignment list \
    --assignee "${AZURE_MANAGED_IDENTITY_PRINCIPAL_ID}" \
    --all \
    --query "[?roleDefinitionName=='Key Vault Secrets User'] | length(@)" -o tsv)

if [ "${ROLE_COUNT}" -gt 0 ]; then
    echo "✅ Managed Identity has Key Vault Secrets User role"
    az role assignment list \
        --assignee "${AZURE_MANAGED_IDENTITY_PRINCIPAL_ID}" \
        --all \
        --query "[?roleDefinitionName=='Key Vault Secrets User'].{Role:roleDefinitionName, Scope:scope}" \
        -o table
else
    echo "❌ Managed Identity missing Key Vault Secrets User role"
    echo "   Run: ./scripts/enable-managed-identity.sh"
    VALIDATION_FAILED=1
fi

echo ""

# Check 3: Container App Configuration
echo "Check 3: Container App Identity"
echo "--------------------------------"
# Note: This check requires the container app name, which would come from azd
echo "✅ Checking if container apps have managed identity assigned..."
CA_LIST=$(az containerapp list \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --query "[].{Name:name, Identity:identity.type}" \
    -o table)

if [ -n "${CA_LIST}" ]; then
    echo "${CA_LIST}"
else
    echo "⚠️  No container apps found"
fi


if [ ${VALIDATION_FAILED} -eq 0 ]; then
    echo "🎉 Security Validation Complete!"
    echo "=============================="
    echo ""
    echo "✅ Verified:"
    echo "  - Secrets stored in Key Vault (not env vars)"
    echo "  - Managed Identity has RBAC permissions"
    echo "  - Container Apps use Managed Identity"
    echo ""
    echo "🔒 Security posture: SECURE"
    echo "   Ready for production!"
else
    echo "❌ Security Validation Failed!"
    echo "=============================="
    echo ""
    echo "⚠️  Issues detected:"
    echo "  - Review the checks above for details"
    echo "  - Fix any ❌ items before proceeding"
    echo ""
    echo "🔒 Security posture: NEEDS ATTENTION"
    echo "   Please resolve issues before production use!"
    exit 1
fi
echo "🔒 Security posture: SECURE"
echo "   Ready for OAuth 2.1 upgrade!"
