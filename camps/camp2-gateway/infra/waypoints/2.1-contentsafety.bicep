// Waypoint 2.1: Apply Content Safety
// Adds Content Safety policy for prompt injection and harmful content filtering

param apimName string
param tenantId string
param mcpAppClientId string
param apimGatewayUrl string
param contentSafetyEndpoint string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Reference existing APIs
resource sherpaApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'sherpa-mcp'
}

resource trailMcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'trail-mcp'
}

// Backend for Content Safety
resource contentSafetyBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'content-safety-backend'
  properties: {
    title: 'Azure Content Safety'
    description: 'Backend for Azure Content Safety service'
    protocol: 'http'
    url: contentSafetyEndpoint
  }
}

// Apply OAuth + Rate Limiting + Content Safety policy to Sherpa API
resource sherpaPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: sherpaApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(replace(
      loadTextContent('../policies/oauth-ratelimit-contentsafety.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apimGatewayUrl),
      '{{content-safety-endpoint}}', contentSafetyEndpoint)
  }
}

// Apply OAuth + Rate Limiting + Content Safety policy to Trail MCP Server
resource trailMcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailMcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(replace(
      loadTextContent('../policies/oauth-ratelimit-contentsafety.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apimGatewayUrl),
      '{{content-safety-endpoint}}', contentSafetyEndpoint)
  }
}

output contentSafetyBackendId string = contentSafetyBackend.id
