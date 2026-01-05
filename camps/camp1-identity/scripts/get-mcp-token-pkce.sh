#!/bin/bash
set -e

echo "🎫 Camp 1: Get MCP Token (Authorization Code + PKCE)"
echo "===================================================="

# Load azd environment variables
echo "📦 Loading azd environment..."
eval "$(azd env get-values | sed 's/^/export /')"

# Check for required environment variables
if [ -z "${AZURE_CLIENT_ID}" ]; then
    echo "❌ Error: AZURE_CLIENT_ID not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

if [ -z "${AZURE_TENANT_ID}" ]; then
    echo "❌ Error: AZURE_TENANT_ID not found in azd environment."
    echo "Make sure you've run 'azd up' first."
    exit 1
fi

echo ""

echo "Client ID: ${AZURE_CLIENT_ID}"
echo "Tenant ID: ${AZURE_TENANT_ID}"
echo ""

# Generate PKCE code verifier (43-128 characters)
# Use 32 random bytes, base64 encode, then convert to base64url format
CODE_VERIFIER=$(openssl rand -base64 32 | tr '/+' '_-' | tr -d '=' | tr -d '\n')

# Save code verifier for token exchange later
echo "${CODE_VERIFIER}" > /tmp/pkce_code_verifier

# Generate PKCE code challenge (base64url encoded SHA256 hash of verifier)
# SHA256 produces 32 bytes, base64url encoded = exactly 43 characters
CODE_CHALLENGE=$(echo -n "${CODE_VERIFIER}" | openssl sha256 -binary | base64 | tr '/+' '_-' | tr -d '=' | tr -d '\n')

echo "Code verifier length: ${#CODE_VERIFIER}"
echo "Code challenge length: ${#CODE_CHALLENGE}"
echo "Code verifier saved to: /tmp/pkce_code_verifier"
echo ""

REDIRECT_URI="http://localhost:8080/callback"
SCOPE="api://${AZURE_CLIENT_ID}/access_as_user"
AUTH_URL="https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/authorize"

# Build authorization URL
AUTH_REQUEST="${AUTH_URL}?client_id=${AZURE_CLIENT_ID}&response_type=code&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

echo "🌐 Opening browser for authentication..."
echo ""
echo "Authorization URL:"
echo "${AUTH_REQUEST}"
echo ""
echo "📋 Steps to get your token:"
echo "=========================================="
echo ""
echo "1. Browser will open for authentication"
echo "2. After login, you'll be redirected to: http://localhost:8080/callback?code=..."
echo "3. You'll see a '404 Not Found' - this is EXPECTED! (no callback server running)"
echo "4. Copy the ENTIRE redirect URL from your browser's address bar"
echo "5. Extract the 'code' parameter (the long string after 'code=' and before '&')"
echo "6. Run the following commands to exchange code for token:"
echo ""
echo "-----------------------------------------------------------"
echo "export AUTH_CODE='PASTE_YOUR_CODE_HERE'"
echo ""
echo "TOKEN=\$(curl -X POST https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token \\"
echo "  -d 'client_id=${AZURE_CLIENT_ID}' \\"
echo "  -d 'grant_type=authorization_code' \\"
echo "  -d \"code=\${AUTH_CODE}\" \\"
echo "  -d 'redirect_uri=${REDIRECT_URI}' \\"
echo "  -d \"code_verifier=\$(cat /tmp/pkce_code_verifier)\" \\"
echo "  | jq -r '.access_token')"
echo ""
echo "echo \"Token: \${TOKEN}\""
echo "-----------------------------------------------------------"
echo ""
echo "7. The TOKEN variable is now set and ready to use in Step 5d!"
echo ""
echo "💡 TIP: The code is valid for only a few minutes - exchange it quickly!"
echo ""

# Open browser (macOS/Linux)
if command -v open &> /dev/null; then
    open "${AUTH_REQUEST}"
elif command -v xdg-open &> /dev/null; then
    xdg-open "${AUTH_REQUEST}"
else
    echo ""
    echo "⚠️  Could not open browser automatically. Copy the URL above."
fi
