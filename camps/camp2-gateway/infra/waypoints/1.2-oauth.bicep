// Waypoint 1.2: Add OAuth to Trail API (keeping subscription keys)
// Demonstrates hybrid authentication: subscription key + OAuth

param apimName string
param tenantId string
param mcpAppClientId string
param apimGatewayUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

resource trailApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'trail-api'
}

// Apply OAuth validation policy to Trail API
// This works TOGETHER with subscription keys (both required)
resource trailPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(
      loadTextContent('../policies/oauth-validation.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apimGatewayUrl)
  }
}

output policyApplied bool = true
