// Waypoint 1.1: Deploy Sherpa MCP Server to APIM
// Creates backend and API with subscription key only (vulnerable)

param apimName string
param backendUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Backend pointing to Sherpa Container App
resource sherpaBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'sherpa-mcp-backend'
  properties: {
    title: 'Sherpa MCP Server'
    description: 'Backend for Sherpa MCP Server running in Container Apps'
    protocol: 'http'
    url: backendUrl
  }
}

// Sherpa MCP API - registered as native MCP type
resource sherpaApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'sherpa-mcp'
  properties: {
    displayName: 'Sherpa MCP Server'
    description: 'MCP Server for weather, trails, and gear recommendations'
    path: 'sherpa/mcp'
    protocols: ['https']
    subscriptionRequired: false  // No authentication (vulnerable)
    type: 'mcp'
    #disable-next-line BCP037 // backendId is a preview feature not yet in type definitions
    backendId: sherpaBackend.name
    #disable-next-line BCP037 // mcpProperties is a preview feature not yet in type definitions
    mcpProperties: {
      transportType: 'streamable'
    }
  }
}

// MCP endpoint operation
resource mcpOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: sherpaApi
  name: 'mcp-endpoint'
  properties: {
    displayName: 'MCP Endpoint'
    method: '*'
    urlTemplate: '/'
    description: 'MCP protocol endpoint'
  }
}

output sherpaApiId string = sherpaApi.id
output sherpaBackendId string = sherpaBackend.id
