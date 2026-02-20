#!/bin/bash
# ==============================================================================
# Trails MCP Server - curl Request Examples
# ==============================================================================
# This file demonstrates how to make HTTP requests to the Trails MCP server
# using curl. MCP servers use JSON-RPC 2.0 over Streamable HTTP transport.
#
# IMPORTANT: MCP's Streamable HTTP transport requires:
#   1. Initialize a session first (get mcp-session-id header)
#   2. Include mcp-session-id in all subsequent requests
#   3. Include Accept header for both application/json and text/event-stream
#
# AUTHENTICATION:
#   The Trails MCP server behind APIM requires OAuth 2.0 authentication.
#   Set the MCP_TOKEN environment variable before running this script:
#
#   Option 1: Get token via PKCE flow (interactive browser login)
#     eval $(./scripts/get-mcp-token.sh --pkce --export)
#     ./tests/curl-examples-trails.sh
#
#   Option 2: Set token directly
#     export MCP_TOKEN="your-oauth-token"
#     ./tests/curl-examples-trails.sh
#
# Available Tools:
#   - list-trails()                    - List all available trails
#   - get-trail(trailId)               - Get detailed trail information
#   - check-conditions(trailId)        - Check current trail conditions
#   - get-permit(permitId)             - Retrieve an existing permit
#   - request-permit(trailId, hikerName, date) - Request a new trail permit
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Load from azd environment
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL 2>/dev/null || echo "")
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null || echo "")
TRAIL_SUBSCRIPTION_KEY=$(azd env get-value TRAIL_SUBSCRIPTION_KEY 2>/dev/null || echo "")

# Validate that we have required values
if [ -z "$APIM_GATEWAY_URL" ]; then
    echo "ERROR: APIM_GATEWAY_URL not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

if [ -z "$TRAIL_SUBSCRIPTION_KEY" ]; then
    echo "ERROR: TRAIL_SUBSCRIPTION_KEY not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

MCP_ENDPOINT="$APIM_GATEWAY_URL/trails/mcp"

# Acquire OAuth token
if [ -z "$MCP_TOKEN" ]; then
    if [ -n "$MCP_APP_CLIENT_ID" ]; then
        echo "🔐 Acquiring OAuth token via Azure CLI..."
        TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null)
    
        TOKEN_RESULT=$(az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>&1) || true
        
        # JWT tokens start with "ey", check if we got one
        if [[ ! "$TOKEN_RESULT" == ey* ]]; then
            echo ""
            echo "⚠️  Interactive consent required. Run these commands first:"
            echo ""
            echo "  az logout"
            echo "  az login --tenant \"$TENANT_ID\" --scope \"$MCP_APP_CLIENT_ID/.default\""
            echo ""
            echo "Then run this script again."
            exit 1
        fi
        MCP_TOKEN="$TOKEN_RESULT"
        echo "✅ OAuth token acquired"
        echo ""
    else
        echo "ERROR: MCP_APP_CLIENT_ID not found in azd environment."
        exit 1
    fi
fi

# Required headers for MCP Streamable HTTP transport
ACCEPT_HEADER="Accept: application/json, text/event-stream"
CONTENT_TYPE="Content-Type: application/json"
APIM_KEY_HEADER="Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY"
AUTH_HEADER="Authorization: Bearer $MCP_TOKEN"

echo "=========================================="
echo "Trails MCP Server - curl Examples"
echo "=========================================="
echo "Endpoint: $MCP_ENDPOINT"
echo ""

# Helper function to parse SSE response and extract JSON result
parse_response() {
    # Extract the data line (excluding empty data or [DONE]), parse JSON, and pretty print the result
    grep "^data:" | grep -v "^\s*$" | grep -v "\[DONE\]" | head -1 | sed 's/^data: //' | jq -r '.result.content[0].text // .result // .' 2>/dev/null || cat
}

# ------------------------------------------------------------------------------
# STEP 1: Initialize Session (Optional for APIM-native MCP)
# ------------------------------------------------------------------------------
# Note: APIM's native MCP type (wrapping REST APIs) is stateless and doesn't
# require session initialization. We still call initialize for protocol
# compliance, but session ID is not required for subsequent requests.

echo "=== Step 1: Initialize MCP Session ==="
echo "Sending initialize request..."

# Initialize - APIM native MCP may not return a session ID
# Note: curl may timeout (exit 28) due to SSE keeping connection open - this is expected
INIT_RESPONSE=$(curl -s -D - -X POST "$MCP_ENDPOINT" \
    --max-time 5 \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$APIM_KEY_HEADER" \
    -H "$AUTH_HEADER" \
    -d '{
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "curl-example",
                "version": "1.0"
            }
        },
        "id": 1
    }' 2>/dev/null || true)

# Extract session ID from headers (may be empty for APIM native MCP)
SESSION_ID=$(echo "$INIT_RESPONSE" | grep -i "mcp-session-id:" | tr -d '\r' | awk '{print $2}')

if [ -n "$SESSION_ID" ]; then
    echo "Session initialized!"
    echo "Session ID: $SESSION_ID"
    SESSION_HEADER="-H mcp-session-id: $SESSION_ID"
else
    echo "Initialized (stateless mode - no session ID required)"
    SESSION_HEADER=""
fi

# Check if initialization succeeded by looking for the result
if echo "$INIT_RESPONSE" | grep -q '"protocolVersion"'; then
    echo "Server: Azure API Management MCP"
else
    echo "WARNING: Unexpected initialize response"
    echo "$INIT_RESPONSE" | tail -5
fi
echo ""

# ------------------------------------------------------------------------------
# STEP 2: List Available Tools
# ------------------------------------------------------------------------------
# Discover what tools the MCP server provides

echo "=== Step 2: List Available Tools ==="
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    --max-time 5 \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$APIM_KEY_HEADER" \
    -H "$AUTH_HEADER" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": 2
    }' 2>/dev/null || true)
echo "$RESPONSE" | grep "^data:" | sed 's/^data: //' | jq -r '.result.tools[] | "  - \(.name): \(.description | split("\n")[0])"'
echo ""

# ------------------------------------------------------------------------------
# STEP 3: Call list-trails Tool
# ------------------------------------------------------------------------------
# List all available trails with their details

echo "=== Step 3: Call list-trails Tool ==="
echo "Request: list-trails()"
echo "Response:"
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    --max-time 5 \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$APIM_KEY_HEADER" \
    -H "$AUTH_HEADER" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "list-trails",
            "arguments": {}
        },
        "id": 3
    }' 2>/dev/null || true)
echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# STEP 4: Call get-trail Tool
# ------------------------------------------------------------------------------
# Get detailed information about a specific trail
# Valid trailIds: summit-trail, base-trail, ridge-walk

echo "=== Step 4: Call get-trail Tool ==="
echo "Request: get-trail(trailId=\"summit-trail\")"
echo "Response:"
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    --max-time 5 \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$APIM_KEY_HEADER" \
    -H "$AUTH_HEADER" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "get-trail",
            "arguments": {
                "trailId": "summit-trail"
            }
        },
        "id": 4
    }' 2>/dev/null || true)
echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# STEP 5: Call check-conditions Tool
# ------------------------------------------------------------------------------
# Check current conditions and hazards for a specific trail
# Valid trailIds: summit-trail, base-trail, ridge-walk

echo "=== Step 5: Call check-conditions Tool ==="
echo "Request: check-conditions(trailId=\"summit-trail\")"
echo "Response:"
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    --max-time 5 \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$APIM_KEY_HEADER" \
    -H "$AUTH_HEADER" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "check-conditions",
            "arguments": {
                "trailId": "summit-trail"
            }
        },
        "id": 5
    }' 2>/dev/null || true)
echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# STEP 6: Call request-permit Tool
# ------------------------------------------------------------------------------
# Request a new permit for a trail that requires one
# Valid trailIds that require permits: summit-trail, ridge-walk
#
# NOTE: APIM's native MCP type has a limitation with POST body parameters.
# The "body" argument is passed as a string but the backend expects parsed JSON.
# This is a known limitation - use the REST API directly for permit creation.
# We'll demonstrate the call but expect an error.

echo "=== Step 6: Call request-permit Tool ==="
echo "(Note: APIM MCP POST body handling has limitations - see REST API for full functionality)"
echo 'Request: request-permit(body={"trail_id":"summit-trail",...})'
echo "Response:"
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    --max-time 5 \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$APIM_KEY_HEADER" \
    -H "$AUTH_HEADER" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "request-permit",
            "arguments": {
                "body": "{\"trail_id\":\"summit-trail\",\"hiker_name\":\"John Doe\",\"hiker_email\":\"john@example.com\",\"planned_date\":\"2026-03-15\"}"
            }
        },
        "id": 6
    }' 2>/dev/null || true)
PERMIT_RESPONSE=$(echo "$RESPONSE" | parse_response)
if echo "$PERMIT_RESPONSE" | grep -q "detail"; then
    echo "(Expected: APIM MCP body parameter limitation)"
else
    echo "$PERMIT_RESPONSE"
fi
echo ""

# Try to extract permit ID for the next step (from nested permit object)
PERMIT_ID=$(echo "$PERMIT_RESPONSE" | jq -r '.permit.id // empty' 2>/dev/null || echo "")

# ------------------------------------------------------------------------------
# STEP 7: Call get-permit Tool
# ------------------------------------------------------------------------------
# Retrieve an existing permit by ID
# Using existing permit PRM-2025-0001 if no new permit was created

echo "=== Step 7: Call get-permit Tool ==="
if [ -z "$PERMIT_ID" ]; then
    # Use existing demo permit
    PERMIT_ID="PRM-2025-0001"
    echo "(Using existing demo permit)"
fi
echo "Request: get-permit(permitId=\"$PERMIT_ID\")"
echo "Response:"
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    --max-time 5 \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$APIM_KEY_HEADER" \
    -H "$AUTH_HEADER" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"tools/call\",
        \"params\": {
            \"name\": \"get-permit\",
            \"arguments\": {
                \"permitId\": \"$PERMIT_ID\"
            }
        },
        \"id\": 7
    }" 2>/dev/null || true)
echo "$RESPONSE" | parse_response
echo ""

echo "=========================================="
echo "All examples completed!"
echo "=========================================="

# ------------------------------------------------------------------------------
# QUICK REFERENCE: One-liner Examples
# ------------------------------------------------------------------------------

echo ""
echo "=== Quick Reference: Copy-Paste Commands ==="
cat << EOF

# NOTE: Replace \$MCP_TOKEN with your actual OAuth token
# Get a token first: eval \$(./scripts/get-mcp-token.sh --pkce --export)
# APIM native MCP is stateless - no session ID required

# Initialize (optional for APIM native MCP):
curl -s -X POST "$MCP_ENDPOINT" --max-time 5 \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}},"id":1}'

# List all trails:
curl -s -X POST "$MCP_ENDPOINT" --max-time 5 \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list-trails","arguments":{}},"id":2}'

# Get trail details:
curl -s -X POST "$MCP_ENDPOINT" --max-time 5 \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get-trail","arguments":{"trailId":"summit-trail"}},"id":3}'

# Check trail conditions:
curl -s -X POST "$MCP_ENDPOINT" --max-time 5 \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check-conditions","arguments":{"trailId":"summit-trail"}},"id":4}'

# Request a permit (body contains JSON string with permit request fields):
curl -s -X POST "$MCP_ENDPOINT" --max-time 5 \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"request-permit","arguments":{"body":"{\"trail_id\":\"summit-trail\",\"hiker_name\":\"John Doe\",\"hiker_email\":\"john@example.com\",\"planned_date\":\"2026-03-15\"}"}},"id":5}'

# Get permit by ID (existing permits: PRM-2025-0001, PRM-2025-0002):
curl -s -X POST "$MCP_ENDPOINT" --max-time 5 \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Ocp-Apim-Subscription-Key: $TRAIL_SUBSCRIPTION_KEY" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get-permit","arguments":{"permitId":"PRM-2025-0001"}},"id":6}'

EOF
