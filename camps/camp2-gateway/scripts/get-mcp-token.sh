#!/bin/bash
set -e

echo "🎫 Camp 2: Get MCP Token for APIM"
echo "================================="
echo ""

# Load azd environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAMP_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "${CAMP_DIR}/.azure/camp2-barks/.env" ]; then
    echo "📦 Loading environment from .azure/camp2-barks/.env..."
    source "${CAMP_DIR}/.azure/camp2-barks/.env"
else
    echo "📦 Loading azd environment..."
    cd "$CAMP_DIR"
    eval "$(azd env get-values | sed 's/^/export /')"
fi

# Check for required environment variables
if [ -z "${MCP_APP_CLIENT_ID}" ]; then
    echo "❌ Error: MCP_APP_CLIENT_ID not found in environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

if [ -z "${APIM_CLIENT_APP_ID}" ]; then
    echo "❌ Error: APIM_CLIENT_APP_ID not found in environment."
    exit 1
fi

if [ -z "${APIM_CLIENT_SECRET}" ]; then
    echo "❌ Error: APIM_CLIENT_SECRET not found in environment."
    exit 1
fi

TENANT_ID=$(az account show --query tenantId -o tsv)

echo "MCP App Client ID:  ${MCP_APP_CLIENT_ID}"
echo "APIM Client App ID: ${APIM_CLIENT_APP_ID}"
echo "Tenant ID:          ${TENANT_ID}"
echo ""

# Parse command line arguments
FLOW="client_credentials"
OUTPUT="token"

while [[ $# -gt 0 ]]; do
    case $1 in
        --pkce)
            FLOW="pkce"
            shift
            ;;
        --json)
            OUTPUT="json"
            shift
            ;;
        --export)
            OUTPUT="export"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --pkce    Use PKCE flow (interactive browser login)"
            echo "  --json    Output full token response as JSON"
            echo "  --export  Output as export command for shell"
            echo "  --help    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Get token using client credentials"
            echo "  $0 --pkce             # Get token using PKCE (user login)"
            echo "  $0 --export           # Output: export TOKEN=..."
            echo "  eval \$($0 --export)  # Set TOKEN in current shell"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$FLOW" = "client_credentials" ]; then
    echo "🔐 Acquiring token using client credentials flow..."
    echo ""
    
    RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=${APIM_CLIENT_APP_ID}" \
        -d "client_secret=${APIM_CLIENT_SECRET}" \
        -d "scope=${MCP_APP_CLIENT_ID}/.default" \
        -d "grant_type=client_credentials")
    
    TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
    
    if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
        echo "❌ Failed to acquire token"
        echo "$RESPONSE" | jq .
        exit 1
    fi

elif [ "$FLOW" = "pkce" ]; then
    echo "🔐 Acquiring token using PKCE flow (interactive)..."
    echo "You will be prompted to authenticate in your browser."
    echo ""
    
    # Try using az login with the scope
    TOKEN=$(az account get-access-token \
        --resource "${MCP_APP_CLIENT_ID}" \
        --query accessToken -o tsv 2>&1)
    
    if [ $? -ne 0 ] || [ -z "$TOKEN" ]; then
        echo ""
        echo "⚠️  Interactive login required. Run:"
        echo ""
        echo "  az login --scope ${MCP_APP_CLIENT_ID}/.default"
        echo ""
        echo "Then run this script again."
        exit 1
    fi
fi

# Output based on format
case $OUTPUT in
    json)
        echo "$RESPONSE"
        ;;
    export)
        echo "export MCP_TOKEN=\"${TOKEN}\""
        ;;
    token)
        echo "✅ Token acquired successfully!"
        echo ""
        echo "Your access token:"
        echo ""
        echo "${TOKEN}"
        echo ""
        echo "💡 Usage with MCP Inspector:"
        echo ""
        echo "  npx @modelcontextprotocol/inspector --transport http \\"
        echo "    --server-url \"https://\${APIM_NAME}.azure-api.net/sherpa/mcp\" \\"
        echo "    --header \"Authorization: Bearer \${TOKEN}\""
        echo ""
        echo "💡 Usage with curl:"
        echo ""
        echo "  curl -X POST \"https://\${APIM_NAME}.azure-api.net/sherpa/mcp\" \\"
        echo "    -H \"Authorization: Bearer \${TOKEN}\" \\"
        echo "    -H \"Content-Type: application/json\" \\"
        echo "    -H \"Accept: application/json, text/event-stream\" \\"
        echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",...}'"
        echo ""
        echo "💡 Decode token at: https://jwt.ms"
        echo ""
        echo "⚠️  Tokens expire after ~1 hour. Run this script again to get a fresh token."
        ;;
esac
