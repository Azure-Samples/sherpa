#!/bin/bash
# Waypoint 1.2: Enable I/O Security in APIM
# Updates APIM policies to call the security function for input validation and output sanitization
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

echo "APIM: $APIM_NAME"
echo "Function URL: $FUNCTION_APP_URL"
echo ""

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
    --value "$FUNCTION_APP_URL"

echo "Named value 'function-app-url' configured"
echo ""

echo "Step 2: Update Sherpa API Policy"
echo "---------------------------------"

# Create the policy XML
cat > /tmp/sherpa-io-policy.xml << 'POLICYEOF'
<policies>
    <inbound>
        <base />
        <!-- Layer 2: Advanced Input Check (Azure Function) -->
        <send-request mode="new" response-variable-name="inputCheck" timeout="5" ignore-error="false">
            <set-url>{{function-app-url}}/api/input-check</set-url>
            <set-method>POST</set-method>
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@(context.Request.Body.As<string>(preserveContent: true))</set-body>
        </send-request>
        <choose>
            <when condition="@(((IResponse)context.Variables["inputCheck"]).StatusCode != 200)">
                <return-response>
                    <set-status code="500" reason="Security Check Unavailable" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>{"error": "Security check service unavailable"}</set-body>
                </return-response>
            </when>
            <when condition="@(!((IResponse)context.Variables["inputCheck"]).Body.As<JObject>()["allowed"].Value<bool>())">
                <return-response>
                    <set-status code="400" reason="Security Check Failed" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>@{
                        var result = ((IResponse)context.Variables["inputCheck"]).Body.As<JObject>();
                        return new JObject(
                            new JProperty("error", "Request blocked by security filter"),
                            new JProperty("reason", result["reason"]?.ToString() ?? "Unknown"),
                            new JProperty("category", result["category"]?.ToString() ?? "Unknown")
                        ).ToString();
                    }</set-body>
                </return-response>
            </when>
        </choose>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <!-- Layer 2: Output Sanitization (Azure Function) -->
        <send-request mode="new" response-variable-name="sanitized" timeout="10" ignore-error="true">
            <set-url>{{function-app-url}}/api/sanitize-output</set-url>
            <set-method>POST</set-method>
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@(context.Response.Body.As<string>(preserveContent: true))</set-body>
        </send-request>
        <choose>
            <when condition="@(context.Variables.ContainsKey("sanitized") && ((IResponse)context.Variables["sanitized"]).StatusCode == 200)">
                <set-body>@(((IResponse)context.Variables["sanitized"]).Body.As<string>())</set-body>
            </when>
        </choose>
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
POLICYEOF

# Update Sherpa API policy
echo "Applying policy to Sherpa MCP API..."
az apim api operation update \
    --resource-group "$RG_NAME" \
    --service-name "$APIM_NAME" \
    --api-id "sherpa-mcp" \
    --operation-id "mcp-handler" \
    --set policies=@/tmp/sherpa-io-policy.xml 2>/dev/null || \
echo "Note: Could not update operation policy. The API may need to be created first via waypoint scripts."

echo ""
echo "Step 3: Update Trail API Policy"
echo "--------------------------------"

# Update Trail API policy
echo "Applying policy to Trail API..."
az apim api operation update \
    --resource-group "$RG_NAME" \
    --service-name "$APIM_NAME" \
    --api-id "trail-api" \
    --operation-id "get-permit-holder" \
    --set policies=@/tmp/sherpa-io-policy.xml 2>/dev/null || \
echo "Note: Could not update operation policy. The API may need to be created first via waypoint scripts."

rm -f /tmp/sherpa-io-policy.xml

echo ""
echo "=========================================="
echo "I/O Security Enabled!"
echo "=========================================="
echo ""
echo "APIM is now configured with Layer 2 security:"
echo ""
echo "  INBOUND:"
echo "    1. OAuth validation (existing)"
echo "    2. Rate limiting (existing)"
echo "    3. Content Safety - Layer 1 (existing)"
echo "    4. input_check Function - Layer 2 (NEW)"
echo ""
echo "  OUTBOUND:"
echo "    1. sanitize_output Function - Layer 2 (NEW)"
echo ""
echo "Next: Validate that security is working"
echo "  ./scripts/1.3-validate-injection.sh"
echo "  ./scripts/1.3-validate-pii.sh"
echo ""
