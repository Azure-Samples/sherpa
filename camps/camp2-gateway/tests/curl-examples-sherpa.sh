#!/bin/bash
# ==============================================================================
# Sherpa MCP Server - curl Request Examples (via APIM)
# ==============================================================================
# This file demonstrates how to make HTTP requests to the Sherpa MCP server
# through Azure API Management using curl. MCP servers use JSON-RPC 2.0 over 
# Streamable HTTP transport.
#
# IMPORTANT: MCP's Streamable HTTP transport requires:
#   1. Initialize a session first (get mcp-session-id header)
#   2. Include mcp-session-id in all subsequent requests
#   3. Include Accept header for both application/json and text/event-stream
#   4. Include Authorization header with OAuth token (for APIM)
#
# Available Tools:
#   - get_weather(location)         - Get weather conditions
#   - check_trail_conditions(trail_id) - Check trail status
#   - get_gear_recommendations(condition_type) - Get gear list
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Load from azd environment
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL 2>/dev/null || echo "")
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null || echo "")

# Validate that we have APIM URL
if [ -z "$APIM_GATEWAY_URL" ]; then
    echo "ERROR: APIM_GATEWAY_URL not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

MCP_ENDPOINT="$APIM_GATEWAY_URL/sherpa/mcp"

# Acquire OAuth token
if [ -z "$MCP_TOKEN" ]; then
    if [ -n "$MCP_APP_CLIENT_ID" ]; then
        echo "🔐 Acquiring OAuth token via Azure CLI..."
        TOKEN_RESULT=$(az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>&1) || true
        
        # JWT tokens start with "ey", check if we got one
        if [[ ! "$TOKEN_RESULT" == ey* ]]; then
            TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null)
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
AUTH_HEADER="Authorization: Bearer $MCP_TOKEN"

echo "=========================================="
echo "Sherpa MCP Server - curl Examples (via APIM)"
echo "=========================================="
echo "Endpoint: $MCP_ENDPOINT"
echo ""

# Helper function to parse SSE response and extract JSON result
parse_response() {
    # Extract the data line (excluding [DONE]), parse JSON, and pretty print the result
    grep "^data:" | grep -v "\[DONE\]" | sed 's/^data: //' | jq -r '.result.content[0].text // .result // .' 2>/dev/null || cat
}

# ------------------------------------------------------------------------------
# STEP 1: Initialize Session (REQUIRED)
# ------------------------------------------------------------------------------
# The MCP Streamable HTTP transport requires session initialization.
# The server returns a mcp-session-id header that must be used in all
# subsequent requests.

echo "=== Step 1: Initialize MCP Session ==="
echo "Sending initialize request..."

# Initialize and capture the session ID from response headers
INIT_RESPONSE=$(curl -s -D - -X POST "$MCP_ENDPOINT" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
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
    }')

# Extract session ID from headers
SESSION_ID=$(echo "$INIT_RESPONSE" | grep -i "mcp-session-id:" | tr -d '\r' | awk '{print $2}')

if [ -z "$SESSION_ID" ]; then
    echo "ERROR: Failed to get session ID from server"
    echo "Response:"
    echo "$INIT_RESPONSE"
    exit 1
fi

echo "Session initialized!"
echo "Session ID: $SESSION_ID"
echo ""

# ------------------------------------------------------------------------------
# STEP 2: List Available Tools
# ------------------------------------------------------------------------------
# Discover what tools the MCP server provides

echo "=== Step 2: List Available Tools ==="
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$AUTH_HEADER" \
    -H "mcp-session-id: $SESSION_ID" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": 2
    }')
echo "$RESPONSE" | grep "^data:" | grep -v "\[DONE\]" | sed 's/^data: //' | jq -r '.result.tools[] | "  - \(.name): \(.description | split("\n")[0])"' 2>/dev/null || echo "$RESPONSE"
echo ""

# ------------------------------------------------------------------------------
# STEP 3: Call get_weather Tool
# ------------------------------------------------------------------------------
# Get weather conditions for a specific location
# Valid locations: summit, base, camp1

echo "=== Step 3: Call get_weather Tool ==="
echo "Request: get_weather(location=\"summit\")"
echo "Response:"
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$AUTH_HEADER" \
    -H "mcp-session-id: $SESSION_ID" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "get_weather",
            "arguments": {
                "location": "summit"
            }
        },
        "id": 3
    }')
echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# STEP 4: Call check_trail_conditions Tool
# ------------------------------------------------------------------------------
# Check the status and hazards for a specific trail
# Valid trail_ids: summit-trail, base-trail, ridge-walk

echo "=== Step 4: Call check_trail_conditions Tool ==="
echo "Request: check_trail_conditions(trail_id=\"summit-trail\")"
echo "Response:"
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$AUTH_HEADER" \
    -H "mcp-session-id: $SESSION_ID" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "check_trail_conditions",
            "arguments": {
                "trail_id": "summit-trail"
            }
        },
        "id": 4
    }')
echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# STEP 5: Call get_gear_recommendations Tool
# ------------------------------------------------------------------------------
# Get recommended gear for specific conditions
# Valid condition_types: winter, summer, technical

echo "=== Step 5: Call get_gear_recommendations Tool ==="
echo "Request: get_gear_recommendations(condition_type=\"winter\")"
echo "Response:"
RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "$AUTH_HEADER" \
    -H "mcp-session-id: $SESSION_ID" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "get_gear_recommendations",
            "arguments": {
                "condition_type": "winter"
            }
        },
        "id": 5
    }')
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
# Get a token first: MCP_TOKEN=\$(az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv)

# Step 1: Initialize session and get session ID
curl -s -D - -X POST "$MCP_ENDPOINT" \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}},"id":1}' \\
  | grep -i mcp-session-id

# Step 2: Use the session ID in subsequent requests (replace SESSION_ID and \$MCP_TOKEN)

# Get weather:
curl -s -X POST "$MCP_ENDPOINT" \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -H "mcp-session-id: SESSION_ID" \\
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_weather","arguments":{"location":"summit"}},"id":2}'

# Check trail:
curl -s -X POST "$MCP_ENDPOINT" \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -H "mcp-session-id: SESSION_ID" \\
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"check_trail_conditions","arguments":{"trail_id":"summit-trail"}},"id":3}'

# Get gear:
curl -s -X POST "$MCP_ENDPOINT" \\
  -H "Content-Type: application/json" \\
  -H "Accept: application/json, text/event-stream" \\
  -H "Authorization: Bearer \$MCP_TOKEN" \\
  -H "mcp-session-id: SESSION_ID" \\
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_gear_recommendations","arguments":{"condition_type":"winter"}},"id":4}'

EOF
