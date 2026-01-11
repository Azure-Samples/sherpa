// Waypoint 1.4: Register APIs in API Center
// Registers MCP servers for discoverability

param apiCenterName string
param apimGatewayUrl string

resource apiCenter 'Microsoft.ApiCenter/services@2024-03-01' existing = {
  name: apiCenterName
}

// Use default workspace (API Center free tier only allows 1 workspace)
resource defaultWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' existing = {
  parent: apiCenter
  name: 'default'
}

// Register Sherpa MCP Server
resource sherpaRegistration 'Microsoft.ApiCenter/services/workspaces/apis@2024-03-01' = {
  parent: defaultWorkspace
  name: 'sherpa-mcp'
  properties: {
    title: 'Sherpa MCP Server'
    summary: 'Weather forecasts, trail conditions, and gear recommendations for mountain adventures'
    description: 'MCP Server providing real-time weather data, trail status updates, and personalized gear recommendations. Secured with OAuth 2.0 via Azure API Management at ${apimGatewayUrl}/sherpa/mcp'
    kind: 'mcp'
    externalDocumentation: [
      {
        title: 'MCP Specification'
        url: 'https://modelcontextprotocol.io'
      }
    ]
  }
}

// Register Trails MCP Server
resource trailsMcpRegistration 'Microsoft.ApiCenter/services/workspaces/apis@2024-03-01' = {
  parent: defaultWorkspace
  name: 'trails-mcp'
  properties: {
    title: 'Trails MCP Server'
    summary: 'Trail information, permit management, and hiking conditions'
    description: 'MCP Server for browsing trails, checking conditions, and managing hiking permits. Secured with OAuth 2.0 via Azure API Management at ${apimGatewayUrl}/trails/mcp'
    kind: 'mcp'
    externalDocumentation: [
      {
        title: 'MCP Specification'
        url: 'https://modelcontextprotocol.io'
      }
    ]
  }
}

output workspaceId string = defaultWorkspace.id
