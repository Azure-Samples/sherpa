#!/bin/bash
# Waypoint 1.3: Validate - PII Redacted
# Confirms that PII is now redacted in responses by Layer 2
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.3: Validate PII Redaction"
echo "=========================================="
echo ""

APIM_URL=$(azd env get-value APIM_GATEWAY_URL)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)

echo "Getting OAuth token..."
TOKEN=$(az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "Failed to get OAuth token. Make sure you're logged in with: az login"
    exit 1
fi

echo "Token acquired successfully"
echo ""

echo "Testing PII Redaction (Layer 2)"
echo "================================"
echo ""

echo "Calling /permits/TRAIL-2024-001/holder..."
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$APIM_URL/trail/permits/TRAIL-2024-001/holder" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "Status: $HTTP_CODE"
echo ""
echo "Response:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""

# Check for redaction
TESTS_PASSED=0
TESTS_FAILED=0

echo "Checking for PII redaction..."
echo ""

# Check SSN
if echo "$BODY" | grep -q "123-45-6789"; then
    echo "  SSN: NOT REDACTED (FAIL)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
elif echo "$BODY" | grep -qi "REDACTED"; then
    echo "  SSN: REDACTED (PASS)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  SSN: Status unclear"
fi

# Check Email
if echo "$BODY" | grep -q "john.smith@example.com"; then
    echo "  Email: NOT REDACTED (FAIL)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
elif echo "$BODY" | grep -qi "REDACTED"; then
    echo "  Email: REDACTED (PASS)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  Email: Status unclear"
fi

# Check Phone
if echo "$BODY" | grep -q "555-123-4567"; then
    echo "  Phone: NOT REDACTED (FAIL)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
elif echo "$BODY" | grep -qi "REDACTED"; then
    echo "  Phone: REDACTED (PASS)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  Phone: Status unclear"
fi

# Check Address
if echo "$BODY" | grep -q "123 Mountain View Dr"; then
    echo "  Address: NOT REDACTED (FAIL)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
elif echo "$BODY" | grep -qi "REDACTED"; then
    echo "  Address: REDACTED (PASS)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  Address: Status unclear"
fi

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo ""

if [ $TESTS_FAILED -eq 0 ] && [ $TESTS_PASSED -gt 0 ]; then
    echo "PII redaction working!"
    echo ""
    echo "Layer 2 (sanitize_output function) is successfully:"
    echo "  - Detecting SSN patterns"
    echo "  - Detecting email addresses"
    echo "  - Detecting phone numbers"
    echo "  - Detecting physical addresses"
    echo ""
    echo "OWASP MCP-03 (Tool Poisoning) MITIGATED"
    echo ""
    echo "=========================================="
    echo "Camp 3 Complete!"
    echo "=========================================="
    echo ""
    echo "You've successfully implemented defense-in-depth I/O security:"
    echo ""
    echo "  Layer 1: Azure AI Content Safety"
    echo "    - Fast broad filtering for harmful content"
    echo ""
    echo "  Layer 2: Azure Functions"
    echo "    - input_check: Advanced injection detection"
    echo "    - sanitize_output: PII and credential redaction"
    echo ""
    echo "  Layer 3: Server-side validation (documented)"
    echo "    - Pydantic models with regex patterns"
    echo "    - Last line of defense"
    echo ""
elif [ $TESTS_FAILED -gt 0 ]; then
    echo "Some PII was not redacted."
    echo "Check the sanitize_output function and Azure AI Services configuration."
    echo ""
    echo "Common issues:"
    echo "  - AI Services endpoint not configured"
    echo "  - Managed identity permissions missing"
    echo "  - Function not receiving response body"
else
    echo "Could not determine redaction status."
    echo "Check the response format and function logs."
fi

echo ""
