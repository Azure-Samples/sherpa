// Waypoint 1.2: Export Trail API as MCP Server
// Creates an MCP API that wraps the REST API operations as MCP tools
// Pattern from: https://github.com/Azure-Samples/AI-Gateway/tree/main/labs/mcp-from-api

param apimName string
param apiName string = 'trail-api'
param productName string = 'trail-services'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Reference the existing REST API
resource trailApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: apiName
}

// Reference the existing Product
resource trailProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' existing = {
  parent: apim
  name: productName
}

// Reference each operation from the REST API
resource listTrailsOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: trailApi
  name: 'list-trails'
}

resource getTrailOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: trailApi
  name: 'get-trail'
}

resource checkConditionsOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: trailApi
  name: 'check-conditions'
}

resource getPermitOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: trailApi
  name: 'get-permit'
}

resource requestPermitOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: trailApi
  name: 'request-permit'
}

// Create MCP API that exposes REST operations as MCP tools
resource trailMcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'trail-mcp'
  properties: {
    type: 'mcp'
    displayName: 'Trail MCP Server'
    description: 'MCP server exposing trail and permit operations as tools'
    subscriptionRequired: true  // Same security as REST API
    path: 'trails'              // APIM path: /trails/mcp
    protocols: ['https']
    mcpTools: [
      {
        name: listTrailsOp.name
        operationId: listTrailsOp.id
        description: listTrailsOp.properties.description
      }
      {
        name: getTrailOp.name
        operationId: getTrailOp.id
        description: getTrailOp.properties.description
      }
      {
        name: checkConditionsOp.name
        operationId: checkConditionsOp.id
        description: checkConditionsOp.properties.description
      }
      {
        name: getPermitOp.name
        operationId: getPermitOp.id
        description: getPermitOp.properties.description
      }
      {
        name: requestPermitOp.name
        operationId: requestPermitOp.id
        description: requestPermitOp.properties.description
      }
    ]
  }
}

// Add MCP API to the Trail Services Product (uses same subscription as REST API)
resource trailMcpProductLink 'Microsoft.ApiManagement/service/products/apis@2024-06-01-preview' = {
  parent: trailProduct
  name: trailMcp.name
}

output trailMcpId string = trailMcp.id
output mcpEndpoint string = '${apim.properties.gatewayUrl}/trails/mcp'
