#!/bin/bash
# Waypoint 1.2: Enable I/O Security in APIM
# 
# Applies Layer 2 security (Azure Functions) while preserving Layer 1
#
# Policy Architecture:
#   sherpa-mcp: Full I/O security (input + output in MCP policy)
#   trail-mcp:  Input security only (output sanitization on trail-api)
#   trail-api:  Output sanitization (catches responses before SSE wrapping)
#
# This split is needed because synthesized MCP servers (trail-mcp) have
# SSE streams controlled by APIM that block outbound Body.As<string>() calls.
# Real MCP servers (sherpa-mcp) work fine with outbound policies.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.2: Enable I/O Security"
echo "=========================================="
echo ""

APIM_NAME=$(azd env get-value APIM_NAME)
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP)
FUNCTION_APP_URL=$(azd env get-value FUNCTION_APP_URL)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "APIM: $APIM_NAME"
echo "Resource Group: $RG_NAME"
echo "Function URL: $FUNCTION_APP_URL"
echo ""

# ============================================
# Step 1: Add Function URL as Named Value
# ============================================
echo "Step 1: Add Function URL as Named Value"
echo "----------------------------------------"

az apim nv create \
    --resource-group "$RG_NAME" \
    --service-name "$APIM_NAME" \
    --named-value-id "function-app-url" \
    --display-name "function-app-url" \
    --value "$FUNCTION_APP_URL" \
    2>/dev/null || \
az apim nv update \
    --resource-group "$RG_NAME" \
    --service-name "$APIM_NAME" \
    --named-value-id "function-app-url" \
    --value "$FUNCTION_APP_URL" \
    --output none

echo "✓ Named value 'function-app-url' configured"
echo ""

# ============================================
# Step 2: Get OAuth Configuration
# ============================================
echo "Step 2: Get OAuth Configuration"
echo "--------------------------------"

TENANT_ID=$(azd env get-value AZURE_TENANT_ID 2>/dev/null || az account show --query tenantId -o tsv)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null || echo "")

if [ -z "$MCP_APP_CLIENT_ID" ]; then
    echo "Warning: MCP_APP_CLIENT_ID not set."
    echo "OAuth validation will use placeholder. Run register-entra-app.sh to configure."
    MCP_APP_CLIENT_ID="00000000-0000-0000-0000-000000000000"
fi

echo "Tenant ID: $TENANT_ID"
echo "MCP App Client ID: $MCP_APP_CLIENT_ID"
echo ""

# ============================================
# Step 3: Update Sherpa MCP Server Policy
# ============================================
echo "Step 3: Update Sherpa MCP Server Policy"
echo "----------------------------------------"
echo "Policy: Full I/O Security (OAuth + Content Safety + Input Check + Output Sanitization)"
echo ""

# Prepare Sherpa MCP policy (full I/O security - works because backend controls stream)
SHERPA_POLICY_XML=$(cat infra/policies/sherpa-mcp-full-io-security.xml | \
    sed "s/{{tenant-id}}/$TENANT_ID/g" | \
    sed "s/{{mcp-app-client-id}}/$MCP_APP_CLIENT_ID/g")

echo "$SHERPA_POLICY_XML" | jq -Rs '{properties: {format: "rawxml", value: .}}' > /tmp/sherpa-mcp-policy.json

echo "Applying full I/O security policy to Sherpa MCP Server..."
if az rest --method PUT \
    --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME/apis/sherpa-mcp/policies/policy?api-version=2024-06-01-preview" \
    --body @/tmp/sherpa-mcp-policy.json \
    --output-file /dev/null 2>/dev/null; then
    echo "✓ Sherpa MCP policy updated!"
else
    echo "✗ Failed to update Sherpa MCP policy"
    echo "  Make sure sherpa-mcp API exists (run azd provision first)"
fi
echo ""

# ============================================
# Step 4: Update Trail MCP Server Policy
# ============================================
echo "Step 4: Update Trail MCP Server Policy"
echo "---------------------------------------"
echo "Policy: Input Security Only (OAuth + Content Safety + Input Check)"
echo "Note: Output sanitization applied to trail-api instead (see Step 5)"
echo ""

# Prepare Trail MCP policy (input only - outbound blocks on synthesized MCP)
TRAIL_MCP_POLICY_XML=$(cat infra/policies/trail-mcp-input-security.xml | \
    sed "s/{{tenant-id}}/$TENANT_ID/g" | \
    sed "s/{{mcp-app-client-id}}/$MCP_APP_CLIENT_ID/g")

echo "$TRAIL_MCP_POLICY_XML" | jq -Rs '{properties: {format: "rawxml", value: .}}' > /tmp/trail-mcp-policy.json

echo "Applying input security policy to Trail MCP Server..."
if az rest --method PUT \
    --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME/apis/trail-mcp/policies/policy?api-version=2024-06-01-preview" \
    --body @/tmp/trail-mcp-policy.json \
    --output-file /dev/null 2>/dev/null; then
    echo "✓ Trail MCP policy updated!"
else
    echo "✗ Failed to update Trail MCP policy"
    echo "  Make sure trail-mcp API exists (run azd provision first)"
fi
echo ""

# ============================================
# Step 5: Update Trail REST API Policy
# ============================================
echo "Step 5: Update Trail REST API Policy"
echo "-------------------------------------"
echo "Policy: Output Sanitization (PII redaction before SSE wrapping)"
echo ""

# Prepare Trail API policy (output sanitization - runs before APIM wraps response in SSE)
TRAIL_API_POLICY_XML=$(cat infra/policies/trail-api-output-sanitization.xml)

echo "$TRAIL_API_POLICY_XML" | jq -Rs '{properties: {format: "rawxml", value: .}}' > /tmp/trail-api-policy.json

echo "Applying output sanitization policy to Trail REST API..."
if az rest --method PUT \
    --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME/apis/trail-api/policies/policy?api-version=2024-06-01-preview" \
    --body @/tmp/trail-api-policy.json \
    --output-file /dev/null 2>/dev/null; then
    echo "✓ Trail API policy updated!"
else
    echo "✗ Failed to update Trail API policy"
    echo "  Make sure trail-api API exists (run azd provision first)"
fi

# Cleanup
rm -f /tmp/sherpa-mcp-policy.json /tmp/trail-mcp-policy.json /tmp/trail-api-policy.json

echo ""

# ============================================
# Step 6: Enable Server-Side Sanitization
# ============================================
echo "Step 6: Enable Server-Side Sanitization for Sherpa MCP"
echo "-------------------------------------------------------"
echo "Setting SANITIZE_ENABLED=true on sherpa-mcp-server Container App..."
echo ""

az containerapp update \
    --name sherpa-mcp-server \
    --resource-group "$RG_NAME" \
    --set-env-vars "SANITIZE_ENABLED=true" \
    --output none 2>/dev/null

# Wait for new revision to be ready
echo "Waiting for new revision to deploy..."

for i in {1..30}; do
    # Check if the env var is set in the active revision
    SANITIZE_VALUE=$(az containerapp show \
        --name sherpa-mcp-server \
        --resource-group "$RG_NAME" \
        --query "properties.template.containers[0].env[?name=='SANITIZE_ENABLED'].value | [0]" -o tsv 2>/dev/null)
    
    if [ "$SANITIZE_VALUE" == "true" ]; then
        # Verify the revision is actually running (status can be "Running" or "RunningAtMaxScale")
        REVISION_STATUS=$(az containerapp revision list \
            --name sherpa-mcp-server \
            --resource-group "$RG_NAME" \
            --query "[?properties.active].properties.runningState | [0]" -o tsv 2>/dev/null)
        
        if [[ "$REVISION_STATUS" == Running* ]]; then
            echo "✓ Sherpa MCP Server updated with SANITIZE_ENABLED=true"
            break
        fi
    fi
    
    if [ $i -eq 30 ]; then
        echo "⚠ Warning: Timeout waiting for deployment. The revision may still be provisioning."
        echo "  Wait a moment before running validation scripts."
    else
        echo "  Waiting for deployment... ($i/30)"
        sleep 3
    fi
done

echo ""
echo "=========================================="
echo "I/O Security Enabled!"
echo "=========================================="
echo ""
echo "Security Architecture:"
echo ""
echo "  ┌─────────────────┐     ┌─────────────────┐"
echo "  │   sherpa-mcp    │     │   trail-mcp     │"
echo "  │ (real MCP proxy)│     │ (synthesized)   │"
echo "  │                 │     │                 │"
echo "  │  • OAuth        │     │  • OAuth        │"
echo "  │  • ContentSafety│     │  • ContentSafety│"
echo "  │  • Input Check  │     │  • Input Check  │"
echo "  │  • Output Sanit.│     │  (no outbound)  │"
echo "  │   (server-side) │     │                 │"
echo "  └────────┬────────┘     └────────┬────────┘"
echo "           │                       │"
echo "           │              ┌────────┴────────┐"
echo "           │              │   trail-api     │"
echo "           │              │  • Output Sanit.│"
echo "           │              │   (APIM policy) │"
echo "           │              └────────┬────────┘"
echo "           ▼                       ▼"
echo "     Container App          Container App"
echo ""
echo "Next: Validate that security is working"
echo "  ./scripts/1.3-validate-injection.sh"
echo "  ./scripts/1.3-validate-pii.sh"
echo ""
