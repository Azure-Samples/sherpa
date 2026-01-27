#!/bin/bash
# Waypoint 1.3: Validate - Technical Injection Blocked
# Confirms that technical injection patterns are now blocked by Layer 2
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.3: Validate Technical Injection Blocking"
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

echo "Testing Technical Injection Blocking (Layer 2)"
echo "==============================================="
echo ""

# Initialize MCP session first (required by MCP protocol)
echo "Initializing MCP session..."
INIT_RESPONSE=$(curl -s -i --max-time 10 -X POST "$APIM_URL/sherpa/mcp" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":0}')
SESSION_ID=$(echo "$INIT_RESPONSE" | grep -i "mcp-session-id" | sed 's/.*: *//' | tr -d '\r\n')
echo "Session: $SESSION_ID"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

echo "Test 1: Shell Injection (command separator)"
echo "-------------------------------------------"
echo "Payload: 'summit; cat /etc/passwd'"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APIM_URL/sherpa/mcp" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "get_weather",
      "arguments": {
        "location": "summit; cat /etc/passwd"
      }
    }
  }' 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "  Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "400" ]; then
    echo "  Result: BLOCKED - Shell injection detected!"
    echo "  Response: $BODY"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  Result: NOT BLOCKED - Test failed"
    echo "  Response: $BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo "Test 2: Path Traversal"
echo "----------------------"
echo "Payload: '../../etc/passwd'"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APIM_URL/sherpa/mcp" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "check_trail_conditions",
      "arguments": {
        "trail_id": "../../etc/passwd"
      }
    }
  }' 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "  Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "400" ]; then
    echo "  Result: BLOCKED - Path traversal detected!"
    echo "  Response: $BODY"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  Result: NOT BLOCKED - Test failed"
    echo "  Response: $BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo "Test 3: SQL Injection"
echo "---------------------"
echo "Payload: \"' OR '1'='1\""
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APIM_URL/sherpa/mcp" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "get_weather",
      "arguments": {
        "location": "Denver'"'"' OR '"'"'1'"'"'='"'"'1"
      }
    }
  }' 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "  Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "400" ]; then
    echo "  Result: BLOCKED - SQL injection detected!"
    echo "  Response: $BODY"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  Result: NOT BLOCKED - Test failed"
    echo "  Response: $BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo "Test 4: Safe Request (should pass)"
echo "-----------------------------------"
echo "Payload: 'Denver, Colorado'"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APIM_URL/sherpa/mcp" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{
    "jsonrpc": "2.0",
    "id": 4,
    "method": "tools/call",
    "params": {
      "name": "get_weather",
      "arguments": {
        "location": "Denver, Colorado"
      }
    }
  }' 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "  Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
    echo "  Result: PASSED - Safe request allowed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  Result: BLOCKED - Test failed (false positive)"
    echo "  Response: $BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo "=========================================="
echo "Test Results"
echo "=========================================="
echo ""
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "All technical injection tests passed!"
    echo ""
    echo "Layer 2 (input_check function) is successfully:"
    echo "  - Detecting shell injection patterns"
    echo "  - Detecting path traversal attempts"
    echo "  - Detecting SQL injection patterns"
    echo "  - Allowing legitimate requests"
else
    echo "Some tests failed. Check the security function logs."
fi

echo ""
echo "Next: Validate PII redaction"
echo "  ./scripts/1.3-validate-pii.sh"
echo ""
