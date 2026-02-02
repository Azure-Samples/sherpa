/*
  Initial APIM API Setup for Camp 4
  
  This follows the Camp 2 pattern:
  1. Sherpa MCP Server - Native MCP type API (passthrough to Container App)
  2. Trail REST API - HTTP API with operations (backend for Trail MCP)
  3. Trail MCP Server - MCP API that wraps Trail REST API operations as tools
  4. Content Safety backend - For Layer 1 protection
  5. Security Function - For Layer 2 protection
  
  Security (Camp 4 starts with full security from Camp 3):
  - OAuth validation on MCP APIs (Sherpa MCP, Trail MCP)
  - Layer 1: Content Safety on MCP APIs
  - Layer 2: Security Function (input validation + output sanitization)
  
  This runs in postprovision hook after Container Apps are deployed.
*/

param apimName string
param sherpaServerUrl string
param trailApiUrl string
param contentSafetyEndpoint string
param tenantId string
param mcpAppClientId string
param functionAppUrl string
param functionAppV1Url string
param functionAppV2Url string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// ============================================
// Backends
// ============================================

// Backend: Sherpa MCP Server
resource sherpaBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'sherpa-mcp-backend'
  properties: {
    protocol: 'http'
    url: '${sherpaServerUrl}/mcp'
    title: 'Sherpa MCP Server'
    description: 'Backend for Sherpa MCP Server running in Container Apps'
  }
}

// Backend: Trail API
resource trailBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'trail-api-backend'
  properties: {
    protocol: 'http'
    url: trailApiUrl
    title: 'Trail REST API'
    description: 'Backend for Trail REST API with PII endpoint'
  }
}

// Backend: Content Safety
resource contentSafetyBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'content-safety-backend'
  properties: {
    protocol: 'http'
    url: contentSafetyEndpoint
    title: 'Azure AI Content Safety'
    description: 'Backend for Content Safety API (Layer 1)'
  }
}

// Named Value: Function App URL (for Layer 2 policies)
// This is the URL that policies use - starts pointing to v1, workshop swaps to v2
resource namedValueFunctionUrl 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'function-app-url'
  properties: {
    displayName: 'function-app-url'
    value: functionAppUrl  // Initially points to v1
    secret: false
  }
}

// Named Value: Function App v1 URL (for reference/switching)
resource namedValueFunctionV1Url 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'function-app-v1-url'
  properties: {
    displayName: 'function-app-v1-url'
    value: functionAppV1Url
    secret: false
  }
}

// Named Value: Function App v2 URL (for reference/switching)
resource namedValueFunctionV2Url 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'function-app-v2-url'
  properties: {
    displayName: 'function-app-v2-url'
    value: functionAppV2Url
    secret: false
  }
}

// ============================================
// Sherpa MCP API (Native MCP Type - Passthrough)
// ============================================

// Sherpa MCP API - registered as native MCP type for passthrough
resource sherpaMcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'sherpa-mcp'
  properties: {
    displayName: 'Sherpa MCP Server'
    description: 'MCP Server for weather, trails, and gear recommendations'
    path: 'sherpa/mcp'
    protocols: ['https']
    subscriptionRequired: false  // OAuth handles auth
    type: 'mcp'
    #disable-next-line BCP037 // backendId is a preview feature
    backendId: sherpaBackend.name
    #disable-next-line BCP037 // mcpProperties is a preview feature
    mcpProperties: {
      transportType: 'streamable'
    }
  }
}

// MCP endpoint operation (catch-all for MCP protocol)
resource mcpOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: sherpaMcpApi
  name: 'mcp-endpoint'
  properties: {
    displayName: 'MCP Endpoint'
    method: '*'
    urlTemplate: '/'
    description: 'MCP protocol endpoint - handles all MCP JSON-RPC requests'
  }
}

// Policy for Sherpa MCP API - OAuth + Content Safety + Security Function (Layer 1 + 2)
// Note: {{function-app-url}} is NOT replaced here - APIM resolves it at runtime from named value
// This allows switching between v1/v2 by just updating the named value
resource sherpaMcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: sherpaMcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(
      loadTextContent('../policies/sherpa-mcp-full-io-security.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId)
  }
  dependsOn: [namedValueFunctionUrl]
}

// ============================================
// Trail REST API (Backend for Trail MCP)
// ============================================

// Trail API - exposed as REST API (no auth - accessed via MCP layer)
resource trailApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'trail-api'
  properties: {
    displayName: 'Trail REST API'
    description: 'REST API for trail information and permit management'
    path: 'trailapi'
    protocols: ['https']
    subscriptionRequired: false
    apiType: 'http'
    serviceUrl: trailApiUrl
  }
}

// GET /trailapi/trails - List all trails
resource listTrailsOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'list-trails'
  properties: {
    displayName: 'List Trails'
    description: 'List all available hiking trails'
    method: 'GET'
    urlTemplate: '/trails'
  }
}

// GET /trailapi/trails/{trailId} - Get trail details
resource getTrailOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'get-trail'
  properties: {
    displayName: 'Get Trail'
    description: 'Get details for a specific trail'
    method: 'GET'
    urlTemplate: '/trails/{trailId}'
    templateParameters: [
      {
        name: 'trailId'
        type: 'string'
        required: true
        description: 'Trail identifier (e.g., summit-trail, base-trail)'
      }
    ]
  }
}

// GET /trailapi/trails/{trailId}/conditions - Get trail conditions
resource checkConditionsOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'check-conditions'
  properties: {
    displayName: 'Check Conditions'
    description: 'Get current trail conditions and hazards'
    method: 'GET'
    urlTemplate: '/trails/{trailId}/conditions'
    templateParameters: [
      {
        name: 'trailId'
        type: 'string'
        required: true
        description: 'Trail identifier'
      }
    ]
  }
}

// GET /trailapi/permits/{permitId} - Get permit details
resource getPermitOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'get-permit'
  properties: {
    displayName: 'Get Permit'
    description: 'Retrieve a trail permit by ID'
    method: 'GET'
    urlTemplate: '/permits/{permitId}'
    templateParameters: [
      {
        name: 'permitId'
        type: 'string'
        required: true
        description: 'Permit identifier (e.g., PRM-2025-0001)'
      }
    ]
  }
}

// GET /trailapi/permits/{permitId}/holder - Get permit holder PII (vulnerable endpoint)
resource getPermitHolderOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'get-permit-holder'
  properties: {
    displayName: 'Get Permit Holder'
    description: 'Get permit holder details (contains PII - demonstrates data leakage)'
    method: 'GET'
    urlTemplate: '/permits/{permitId}/holder'
    templateParameters: [
      {
        name: 'permitId'
        type: 'string'
        required: true
        description: 'Permit identifier'
      }
    ]
  }
}

// Trail REST API Policy - Output sanitization (Layer 2)
// Input security is on trail-mcp, output sanitization is here (before SSE wrapping)
// Note: {{function-app-url}} is NOT replaced here - APIM resolves it at runtime from named value
resource trailApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../policies/trail-api-output-sanitization.xml')
  }
  dependsOn: [namedValueFunctionUrl]
}

// ============================================
// Trail MCP Server (Wraps REST API as MCP Tools)
// ============================================

// Trail MCP API - exposes REST operations as MCP tools
resource trailMcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'trail-mcp'
  properties: {
    type: 'mcp'
    displayName: 'Trail MCP Server'
    description: 'MCP server exposing trail and permit operations as tools'
    subscriptionRequired: false  // OAuth handles auth
    path: 'trails'               // MCP type adds /mcp automatically -> trails/mcp
    protocols: ['https']
    #disable-next-line BCP037 // mcpTools is a preview feature
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
        name: getPermitHolderOp.name
        operationId: getPermitHolderOp.id
        description: getPermitHolderOp.properties.description
      }
    ]
  }
  dependsOn: [
    listTrailsOp
    getTrailOp
    checkConditionsOp
    getPermitOp
    getPermitHolderOp
  ]
}

// Policy for Trail MCP API - OAuth + Content Safety + Input Check (Layer 1 + 2 input)
// Output sanitization is on trail-api (to avoid SSE blocking)
// Note: {{function-app-url}} is NOT replaced here - APIM resolves it at runtime from named value
resource trailMcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailMcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(
      loadTextContent('../policies/trail-mcp-input-security.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId)
  }
  dependsOn: [namedValueFunctionUrl]
}

// ============================================
// Outputs
// ============================================

output sherpaMcpApiId string = sherpaMcpApi.id
output trailApiId string = trailApi.id
output trailMcpApiId string = trailMcpApi.id
output sherpaBackendId string = sherpaBackend.id
output trailBackendId string = trailBackend.id
output contentSafetyBackendId string = contentSafetyBackend.id
output sherpaMcpEndpoint string = '${apim.properties.gatewayUrl}/sherpa/mcp'
output trailMcpEndpoint string = '${apim.properties.gatewayUrl}/trails/mcp'
