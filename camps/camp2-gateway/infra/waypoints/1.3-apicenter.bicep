// Waypoint 1.3: Register APIs in API Center
// Registers MCP servers for discoverability

param apiCenterName string
param apimName string
param apimGatewayUrl string

resource apiCenter 'Microsoft.ApiCenter/services@2024-03-01' existing = {
  name: apiCenterName
}

// Create workspace for MCP servers
resource mcpWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' = {
  parent: apiCenter
  name: 'mcp-servers'
  properties: {
    title: 'MCP Servers'
    description: 'Model Context Protocol servers for AI assistants'
  }
}

// Register Sherpa MCP Server
resource sherpaRegistration 'Microsoft.ApiCenter/services/workspaces/apis@2024-03-01' = {
  parent: mcpWorkspace
  name: 'sherpa-mcp'
  properties: {
    title: 'Sherpa MCP Server'
    description: 'MCP Server for weather, trails, and gear recommendations'
    kind: 'rest'  // Note: API Center doesn't have MCP type yet
    lifecycleStage: 'production'
    externalDocumentation: [
      {
        title: 'MCP Specification'
        url: 'https://modelcontextprotocol.io'
      }
    ]
    customProperties: {
      mcpEndpoint: '${apimGatewayUrl}/sherpa-mcp/mcp'
      transportType: 'streamable'
    }
  }
}

// Register Trail API
resource trailRegistration 'Microsoft.ApiCenter/services/workspaces/apis@2024-03-01' = {
  parent: mcpWorkspace
  name: 'trail-api'
  properties: {
    title: 'Trail API'
    description: 'REST API for trail information and permits'
    kind: 'rest'
    lifecycleStage: 'production'
    customProperties: {
      restEndpoint: '${apimGatewayUrl}/trails'
    }
  }
}

output workspaceId string = mcpWorkspace.id
