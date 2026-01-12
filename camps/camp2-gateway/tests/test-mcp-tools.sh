#!/bin/bash
# Test MCP server tools through APIM gateway

set -e

echo "=========================================="
echo "Testing MCP Server Tools"
echo "=========================================="

# Check required variables
if [ -z "$APIM_GATEWAY_URL" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: APIM_GATEWAY_URL and ACCESS_TOKEN must be set"
    echo "Get your access token from: az account get-access-token --resource api://<MCP_APP_CLIENT_ID> --query accessToken -o tsv"
    exit 1
fi

echo "Testing Sherpa MCP Server..."
echo "Calling get_weather tool..."

curl -X POST "$APIM_GATEWAY_URL/sherpa-mcp/mcp" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "method": "tools/call",
        "params": {
            "name": "get_weather",
            "arguments": {
                "location": "summit"
            }
        }
    }'

echo ""
echo ""
echo "Testing Trail MCP Server..."
echo "Calling list_trails tool..."

curl -X POST "$APIM_GATEWAY_URL/trail-mcp/mcp" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "method": "tools/call",
        "params": {
            "name": "list_trails",
            "arguments": {}
        }
    }'

echo ""
echo ""
echo "=========================================="
echo "MCP Tool Testing Complete"
echo "=========================================="
