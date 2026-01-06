#!/bin/bash
set -e

# Generate Client Secret for Local Testing
# This script creates a client secret for the Entra ID app registration
# and saves it to .env for local demo client testing.

echo "============================================"
echo "Generate Client Secret for Demo Testing"
echo "============================================"
echo ""

# Get client ID from azd environment
CLIENT_ID=$(azd env get-value AZURE_CLIENT_ID 2>/dev/null || echo "")

if [ -z "${CLIENT_ID}" ]; then
    echo "❌ AZURE_CLIENT_ID not found in azd environment"
    echo "   Run this from camps/camp1-identity after deploying with azd"
    exit 1
fi

echo "Client ID: ${CLIENT_ID}"
echo ""

# Check if secret already exists in .env
if [ -f "demo-client/.env" ]; then
    echo "⚠️  Found existing demo-client/.env file"
    read -p "   Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Generate a new client secret (30 days to comply with org policies)
echo "Generating client secret (30 day expiration)..."
SECRET_JSON=$(az ad app credential reset \
    --id "${CLIENT_ID}" \
    --append \
    --display-name "Demo Client Local Testing $(date +%Y%m%d-%H%M%S)" \
    --end-date $(date -u -v+30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+30 days' +%Y-%m-%dT%H:%M:%SZ) \
    --only-show-errors \
    -o json)

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate client secret"
    echo "${SECRET_JSON}"
    exit 1
fi

CLIENT_SECRET=$(echo "${SECRET_JSON}" | jq -r '.password')
EXPIRY=$(echo "${SECRET_JSON}" | jq -r '.endDateTime')

if [ -z "${CLIENT_SECRET}" ] || [ "${CLIENT_SECRET}" = "null" ]; then
    echo "❌ Failed to extract client secret from response"
    echo "${SECRET_JSON}"
    exit 1
fi

# Create .env file
mkdir -p demo-client
cat > demo-client/.env << EOF
# Client Secret for Demo Testing
# Generated: $(date)
# Expires: ${EXPIRY}
# 
# ⚠️  WARNING: Keep this file secure and DO NOT commit to git!
# This is for LOCAL TESTING ONLY.

CLIENT_SECRET=${CLIENT_SECRET}
EOF

# Ensure .env is in .gitignore
if [ ! -f "demo-client/.gitignore" ]; then
    echo ".env" > demo-client/.gitignore
    echo "*.pyc" >> demo-client/.gitignore
    echo "__pycache__/" >> demo-client/.gitignore
elif ! grep -q "^\.env$" demo-client/.gitignore; then
    echo ".env" >> demo-client/.gitignore
fi

echo ""
echo "✅ Client secret generated and saved to demo-client/.env"
echo ""
echo "Security Notes:"
echo "  • Secret expires: ${EXPIRY}"
echo "  • For LOCAL TESTING ONLY"
echo "  • .env file is git-ignored"
echo "  • Never use client secrets in production public clients"
echo ""
echo "You can now run the demo client:"
echo "  cd demo-client"
echo "  uv run --project .. python mcp_prm_client.py \\"
echo "    \"\${SECURE_SERVER_URL}\" \\"
echo "    \"\${AZURE_CLIENT_ID}\""
echo ""
echo "Note: Demo uses port 8090 for OAuth callback to avoid conflicts"
echo ""
