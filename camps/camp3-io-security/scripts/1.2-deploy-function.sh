#!/bin/bash
# Waypoint 1.2: Deploy Security Function
# Deploys the Azure Function with input_check and sanitize_output endpoints
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo ""
echo "=========================================="
echo "Waypoint 1.2: Deploy Security Function"
echo "=========================================="
echo ""

FUNCTION_APP_NAME=$(azd env get-value FUNCTION_APP_NAME)
RG_NAME=$(azd env get-value AZURE_RESOURCE_GROUP)
FUNCTION_APP_URL=$(azd env get-value FUNCTION_APP_URL)

echo "Function App: $FUNCTION_APP_NAME"
echo "Resource Group: $RG_NAME"
echo ""

echo "Deploying security function code..."
echo ""

# Navigate to function directory
cd security-function

# Deploy using Azure Functions Core Tools
echo "Building and deploying function..."
func azure functionapp publish "$FUNCTION_APP_NAME" --python

if [ $? -ne 0 ]; then
    echo ""
    echo "Deployment failed. Trying alternative method..."
    
    # Alternative: use az functionapp deployment
    cd "$SCRIPT_DIR/.."
    
    # Create a zip package
    echo "Creating deployment package..."
    cd security-function
    zip -r ../function-package.zip . -x "*.pyc" -x "__pycache__/*" -x ".venv/*" -x "tests/*"
    cd ..
    
    echo "Deploying via zip deployment..."
    az functionapp deployment source config-zip \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RG_NAME" \
        --src function-package.zip
    
    rm -f function-package.zip
fi

echo ""
echo "Verifying deployment..."

# Wait for function to warm up
sleep 10

# Test health endpoint
echo "Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s "$FUNCTION_APP_URL/api/health" 2>/dev/null || echo '{"error": "unavailable"}')
echo "Health check: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo ""
    echo "=========================================="
    echo "Function Deployed Successfully!"
    echo "=========================================="
    echo ""
    echo "Function URL: $FUNCTION_APP_URL"
    echo ""
    echo "Available endpoints:"
    echo "  - POST /api/input-check     - Validates input for injection patterns"
    echo "  - POST /api/sanitize-output - Redacts PII and credentials"
    echo "  - GET  /api/health          - Health check"
    echo ""
else
    echo ""
    echo "Warning: Health check didn't return expected response."
    echo "The function may still be starting up. Wait a moment and try again."
fi

echo ""
echo "Next: Enable I/O security in APIM"
echo "  ./scripts/1.2-enable-io-security.sh"
echo ""
