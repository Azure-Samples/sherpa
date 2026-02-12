#!/bin/bash
# ==============================================================================
# Trails MCP Server - curl Request Examples
# ==============================================================================
# This file demonstrates how to make HTTP requests to the Trails MCP server
# through APIM gateway using curl. MCP servers use JSON-RPC 2.0 over 
# Streamable HTTP transport.
#
# IMPORTANT: MCP's Streamable HTTP transport requires:
#   1. Initialize a session first (get mcp-session-id header)
#   2. Include mcp-session-id in all subsequent requests
#   3. Include Accept header for both application/json and text/event-stream
#   4. Include OAuth Bearer token for authentication
#
# Available Tools:
#   - list-trails                   - List all available trails
#   - get-trail(trail_id)           - Get details for a specific trail
#   - check-conditions(trail_id)    - Check trail conditions and hazards
#   - get-permit(permit_id)         - Get permit details by ID
#   - request-permit(...)           - Request a new trail permit
# ==============================================================================

# Note: We don't use 'set -e' because curl with SSE may timeout while the
# response data is actually received (APIM keeps connections open).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  Trails MCP Server - curl Examples${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Load from azd environment (matches other camp3 scripts)
APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL)
MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID)

if [ -z "$APIM_GATEWAY_URL" ]; then
    echo -e "${RED}ERROR: APIM_GATEWAY_URL not found.${NC}"
    echo "Run 'azd up' first to deploy the infrastructure."
    exit 1
fi

if [ -z "$MCP_APP_CLIENT_ID" ]; then
    echo -e "${RED}ERROR: MCP_APP_CLIENT_ID not found.${NC}"
    echo "Run 'azd up' first to deploy the infrastructure."
    exit 1
fi

# The trails MCP endpoint through APIM
MCP_ENDPOINT="${APIM_GATEWAY_URL}/trails/mcp"

# Required headers for MCP Streamable HTTP transport
ACCEPT_HEADER="Accept: application/json, text/event-stream"
CONTENT_TYPE="Content-Type: application/json"

echo "APIM Gateway: $APIM_GATEWAY_URL"
echo "MCP Endpoint: $MCP_ENDPOINT"
echo ""

# ------------------------------------------------------------------------------
# Get OAuth Token
# ------------------------------------------------------------------------------
echo -e "${BLUE}Getting OAuth token...${NC}"
TOKEN=$(az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}ERROR: Could not get access token.${NC}"
    echo "Make sure you're logged in: az login"
    exit 1
fi
echo -e "${GREEN}✓ OAuth token acquired${NC}"
echo ""

# Helper function to parse SSE response and extract JSON result
parse_response() {
    grep "^data:" | sed 's/^data: //' | jq -r '.result.content[0].text // .result // .' 2>/dev/null || cat
}

# ------------------------------------------------------------------------------
# STEP 1: Create Session ID
# ------------------------------------------------------------------------------
# Trail MCP is APIM-synthesized (REST API exposed as MCP).
# APIM accepts client-provided Mcp-Session-Id for rate limiting/tracking.
# We don't need to call initialize - just generate a session ID.

echo -e "${CYAN}=== Step 1: Create Session ID ===${NC}"
SESSION_ID="session-$(date +%s)"
echo "Trail MCP uses client-generated session IDs"
echo "  Session ID: $SESSION_ID"
echo ""

# ------------------------------------------------------------------------------
# STEP 2: List Available Tools
# ------------------------------------------------------------------------------
echo -e "${CYAN}=== Step 2: List Available Tools ===${NC}"

RESPONSE=$(curl -s --max-time 5 -X POST "$MCP_ENDPOINT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": 1
    }')

echo "Available tools:"
echo "$RESPONSE" | grep "^data:" | sed 's/^data: //' | jq -r '.result.tools[] | "  - \(.name): \(.description | split("\n")[0])"' 2>/dev/null || echo "$RESPONSE"
echo ""

# ------------------------------------------------------------------------------
# STEP 3: Call list-trails Tool
# ------------------------------------------------------------------------------
echo -e "${CYAN}=== Step 3: Call list-trails Tool ===${NC}"
echo "Request: list-trails"
echo "Response:"

RESPONSE=$(curl -s --max-time 5 -X POST "$MCP_ENDPOINT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "list-trails",
            "arguments": {}
        },
        "id": 3
    }')

echo "$RESPONSE" | parse_response | jq '.' 2>/dev/null || echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# STEP 4: Call get-trail Tool
# ------------------------------------------------------------------------------
echo -e "${CYAN}=== Step 4: Call get-trail Tool ===${NC}"
echo "Request: get-trail(trailId=\"summit-trail\")"
echo "Response:"

RESPONSE=$(curl -s --max-time 5 -X POST "$MCP_ENDPOINT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "Mcp-Session-Id: $SESSION_ID" \
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
    }')

echo "$RESPONSE" | parse_response | jq '.' 2>/dev/null || echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# STEP 5: Call check-conditions Tool
# ------------------------------------------------------------------------------
echo -e "${CYAN}=== Step 5: Call check-conditions Tool ===${NC}"
echo "Request: check-conditions(trailId=\"summit-trail\")"
echo "Response:"

RESPONSE=$(curl -s --max-time 5 -X POST "$MCP_ENDPOINT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "Mcp-Session-Id: $SESSION_ID" \
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
    }')

echo "$RESPONSE" | parse_response | jq '.' 2>/dev/null || echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# STEP 6: Call get-permit Tool
# ------------------------------------------------------------------------------
echo -e "${CYAN}=== Step 6: Call get-permit Tool ===${NC}"
echo "Request: get-permit(permitId=\"TRAIL-2024-001\")"
echo "Response:"

RESPONSE=$(curl -s --max-time 5 -X POST "$MCP_ENDPOINT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "$CONTENT_TYPE" \
    -H "$ACCEPT_HEADER" \
    -H "Mcp-Session-Id: $SESSION_ID" \
    -d '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "get-permit",
            "arguments": {
                "permitId": "TRAIL-2024-001"
            }
        },
        "id": 6
    }')

echo "$RESPONSE" | parse_response | jq '.' 2>/dev/null || echo "$RESPONSE" | parse_response
echo ""

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  All examples completed!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
