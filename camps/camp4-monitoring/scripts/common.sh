#!/bin/bash
# =============================================================================
# Camp 4 - Common Functions and Environment Setup
# =============================================================================
# Source this file in other scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load environment variables from azd
load_env() {
    APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL 2>/dev/null)
    WORKSPACE_ID=$(azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>/dev/null)
    RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null)
    APIM_NAME=$(azd env get-value APIM_NAME 2>/dev/null)
    FUNCTION_APP_NAME=$(azd env get-value FUNCTION_APP_NAME 2>/dev/null)
    MCP_APP_CLIENT_ID=$(azd env get-value MCP_APP_CLIENT_ID 2>/dev/null)
    
    if [ -z "$APIM_GATEWAY_URL" ]; then
        echo -e "${RED}Error: APIM_GATEWAY_URL not found. Run 'azd up' first.${NC}"
        return 1
    fi
}

# Get OAuth token for MCP API calls
get_token() {
    if [ -z "$MCP_APP_CLIENT_ID" ]; then
        echo -e "${RED}Error: MCP_APP_CLIENT_ID not found. Run 'azd up' first.${NC}"
        return 1
    fi
    
    TOKEN=$(az account get-access-token --resource "$MCP_APP_CLIENT_ID" --query accessToken -o tsv 2>/dev/null)
    if [ -z "$TOKEN" ]; then
        echo -e "${RED}Error: Could not get access token. Check Azure CLI login.${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ OAuth token acquired${NC}"
}

# Initialize MCP session and get session ID
init_mcp_session() {
    curl -s -D /tmp/mcp-headers.txt --max-time 10 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"camp4-test","version":"1.0"}},"id":1}' > /dev/null 2>&1 || true

    SESSION_ID=$(grep -i "mcp-session-id" /tmp/mcp-headers.txt 2>/dev/null | sed 's/.*: *//' | tr -d '\r\n') || true
    [ -z "$SESSION_ID" ] && SESSION_ID="session-$(date +%s)"
}

# Send MCP tool call through APIM
# Usage: send_mcp_call <tool_name> <arguments_json> [request_id]
send_mcp_call() {
    local tool_name="$1"
    local arguments="$2"
    local request_id="${3:-1}"
    
    curl -s -w "\n%{http_code}" --max-time 15 -X POST "${APIM_GATEWAY_URL}/sherpa/mcp" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -H "Mcp-Session-Id: $SESSION_ID" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"$tool_name\",\"arguments\":$arguments},\"id\":$request_id}" | tail -1
}

# Send attack payload (simplified for testing)
# Usage: send_attack <tool_name> <argument_name> <payload>
send_attack() {
    local tool_name="$1"
    local arg_name="$2"
    local payload="$3"
    
    # Escape the payload for JSON
    local escaped_payload=$(echo "$payload" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    send_mcp_call "$tool_name" "{\"$arg_name\":\"$escaped_payload\"}"
}
