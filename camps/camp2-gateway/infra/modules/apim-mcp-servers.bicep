param apimName string
param sherpaBackendId string
param trailApiUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Sherpa MCP Server - registered as native MCP type
resource sherpaApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'sherpa-mcp-api'
  properties: {
    displayName: 'Sherpa MCP Server'
    path: 'sherpa-mcp'
    protocols: ['https']
    subscriptionRequired: false
    type: 'mcp'
    backendId: last(split(sherpaBackendId, '/'))
    mcpProperties: {
      transportType: 'streamable'
    }
  }
}

// Apply OAuth policy to Sherpa MCP Server at API level
resource sherpaApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: sherpaApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../policies/oauth-validation-policy.xml')
  }
}

// Trail API - REST API with backend configured
resource trailApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'trail-api'
  properties: {
    displayName: 'Trail API'
    path: 'trail-api'
    protocols: ['https']
    subscriptionRequired: false
    apiType: 'http'
    serviceUrl: trailApiUrl
  }
}

// Apply OAuth policy to Trail API at API level
resource trailApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../policies/oauth-validation-policy.xml')
  }
}

// PRM Metadata API (anonymous access for OAuth discovery)
resource prmApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'oauth-prm'
  properties: {
    displayName: 'OAuth PRM Metadata'
    description: 'RFC 9728 Protected Resource Metadata for OAuth discovery'
    path: '/.well-known/oauth-protected-resource'
    protocols: ['https']
    subscriptionRequired: false
  }
}

output sherpaApiId string = sherpaApi.id
output trailApiId string = trailApi.id
output prmApiId string = prmApi.id
output configuredSherpaBackend string = sherpaBackendId
output configuredTrailUrl string = trailApiUrl
