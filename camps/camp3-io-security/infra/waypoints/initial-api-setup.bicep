/*
  Initial APIM API Setup for Camp 3
  
  This follows the Camp 2 pattern:
  1. Sherpa MCP Server - Native MCP type API (passthrough to Container App)
  2. Trail REST API - HTTP API with operations (backend for Trail MCP)
  3. Trail MCP Server - MCP API that wraps Trail REST API operations as tools
  4. Content Safety backend - For Layer 1 protection
  
  Security focus:
  - OAuth validation on MCP APIs only (Sherpa MCP, Trail MCP)
  - Content Safety on MCP APIs (Layer 1)
  - Trail REST API has no auth (accessed via MCP layer)
  
  This runs in postprovision hook after Container Apps are deployed.
*/

param apimName string
param sherpaServerUrl string
param trailApiUrl string
param contentSafetyEndpoint string
param tenantId string
param mcpAppClientId string

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

// ============================================
// Policy Fragment: MCP Content Safety (Prompt Shields)
// Reusable fragment for Layer 1 content safety checks
// ============================================

resource mcpContentSafetyFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apim
  name: 'mcp-content-safety'
  properties: {
    description: 'Extracts MCP tool arguments and checks for prompt injection using Azure Content Safety Prompt Shields API'
    format: 'rawxml'
    value: loadTextContent('../policies/fragments/mcp-content-safety.xml')
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

// Policy for Sherpa MCP API - OAuth + Content Safety (Layer 1 only)
resource sherpaMcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: sherpaMcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(
      loadTextContent('../policies/base-oauth-contentsafety.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apim.properties.gatewayUrl)
  }
  dependsOn: [
    mcpContentSafetyFragment
  ]
}

// Note: Cannot add suffix-pattern PRM operation to MCP type API
// VS Code should use RFC 9728 path-based discovery: /.well-known/oauth-protected-resource/sherpa/mcp

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

// Trail REST API Policy - passthrough (no auth, accessed via MCP layer)
resource trailApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''<policies>
    <inbound>
        <base />
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>'''
  }
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

// Policy for Trail MCP API - OAuth + Content Safety (Layer 1 only)
resource trailMcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailMcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(
      loadTextContent('../policies/base-oauth-contentsafety.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apim.properties.gatewayUrl)
  }
  dependsOn: [
    mcpContentSafetyFragment
  ]
}

// Note: Cannot add suffix-pattern PRM operation to MCP type API
// VS Code should use RFC 9728 path-based discovery: /.well-known/oauth-protected-resource/trails/mcp

// ============================================
// OAuth PRM Discovery API (RFC 9728)
// Enables VS Code MCP OAuth discovery
// ============================================

// OAuth PRM API for RFC 9728 path-based discovery
resource oauthPrmApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'oauth-prm'
  properties: {
    displayName: 'OAuth Protected Resource Metadata'
    description: 'RFC 9728 Protected Resource Metadata for OAuth discovery'
    path: ''  // Root path
    protocols: ['https']
    subscriptionRequired: false
    apiType: 'http'
  }
}

// PRM operation for Sherpa MCP (RFC 9728 path-based discovery)
resource oauthPrmSherpaMcpOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: oauthPrmApi
  name: 'get-prm-sherpa-mcp'
  properties: {
    displayName: 'Get PRM for Sherpa MCP'
    description: 'RFC 9728 path-based discovery for /sherpa/mcp resource'
    method: 'GET'
    urlTemplate: '/.well-known/oauth-protected-resource/sherpa/mcp'
  }
}

// Policy for Sherpa MCP PRM discovery
resource oauthPrmSherpaMcpPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: oauthPrmSherpaMcpOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(replace(
      loadTextContent('../policies/prm-metadata.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apim.properties.gatewayUrl),
      '{{api-path}}', 'sherpa/mcp')
  }
}

// PRM operation for Trail MCP (RFC 9728 path-based discovery)
resource oauthPrmTrailMcpOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: oauthPrmApi
  name: 'get-prm-trail-mcp'
  properties: {
    displayName: 'Get PRM for Trail MCP'
    description: 'RFC 9728 path-based discovery for /trails/mcp resource'
    method: 'GET'
    urlTemplate: '/.well-known/oauth-protected-resource/trails/mcp'
  }
}

// Policy for Trail MCP PRM discovery
resource oauthPrmTrailMcpPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: oauthPrmTrailMcpOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(replace(
      loadTextContent('../policies/prm-metadata.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apim.properties.gatewayUrl),
      '{{api-path}}', 'trails/mcp')
  }
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
