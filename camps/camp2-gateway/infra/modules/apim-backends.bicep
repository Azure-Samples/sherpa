param apimName string
param sherpaMcpServerUrl string
param trailApiUrl string
param contentSafetyEndpoint string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

// Backend for Sherpa MCP Server
resource sherpaBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apim
  name: 'sherpa-mcp-backend'
  properties: {
    protocol: 'http'
    url: sherpaMcpServerUrl
  }
}

// Backend for Trail API
resource trailApiBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apim
  name: 'trail-api-backend'
  properties: {
    protocol: 'http'
    url: trailApiUrl
  }
}

// Backend for Content Safety
resource contentSafetyBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apim
  name: 'content-safety-backend'
  properties: {
    protocol: 'http'
    url: contentSafetyEndpoint
    credentials: {
      header: {
        'Ocp-Apim-Subscription-Key': []
      }
    }
  }
}

output sherpaBackendId string = sherpaBackend.name
output trailApiBackendId string = trailApiBackend.name
output trailApiUrl string = trailApiUrl
output contentSafetyBackendId string = contentSafetyBackend.name
