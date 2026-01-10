// Waypoint 1.1: Add OAuth Authentication to Sherpa MCP Server
// 
// This waypoint configures:
// 1. OAuth token validation on the MCP API (Entra ID tokens)
// 2. RFC 9728 Protected Resource Metadata (PRM) for discovery
// 3. Two PRM discovery paths (RFC 9728 standard + suffix pattern)
//
// Key learnings from implementation:
// - Entra app with empty identifierUris uses scopes like {appId}/scope_name
// - PRM operation must return BEFORE <base /> to skip OAuth validation
// - VS Code tries RFC 9728 path first: /.well-known/oauth-protected-resource/{path}
// - 401 response must include correct resource_metadata in both header AND body

param apimName string
param tenantId string
param mcpAppClientId string
param apimGatewayUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

resource sherpaMcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'sherpa-mcp'
}

// ============================================================
// OAuth PRM Discovery API
// Handles RFC 9728 path-based discovery: /.well-known/oauth-protected-resource/{path}
// ============================================================
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
// VS Code tries this path first: /.well-known/oauth-protected-resource/sherpa/mcp
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

// Policy for RFC 9728 path-based PRM discovery
resource oauthPrmSherpaMcpPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: oauthPrmSherpaMcpOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(
      loadTextContent('../policies/prm-metadata.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apimGatewayUrl)
  }
}

// ============================================================
// PRM Operation inside MCP API (suffix pattern)
// Handles: /sherpa/mcp/.well-known/oauth-protected-resource
// ============================================================
resource mcpPrmOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: sherpaMcpApi
  name: 'mcp-prm-operation'
  properties: {
    displayName: 'MCP Protected Resource Metadata'
    description: 'RFC 9728 PRM endpoint (suffix pattern)'
    method: 'GET'
    urlTemplate: '/.well-known/oauth-protected-resource'
  }
}

// Policy for suffix-pattern PRM discovery
// Returns PRM immediately WITHOUT calling <base /> to skip OAuth validation
resource mcpPrmPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: mcpPrmOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(
      loadTextContent('../policies/prm-metadata.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apimGatewayUrl)
  }
}

// ============================================================
// OAuth Token Validation Policy on MCP API
// Validates Entra ID tokens and returns proper 401 with PRM link
// ============================================================
resource mcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: sherpaMcpApi
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

// ============================================================
// Remove subscription key requirement (OAuth replaces it)
// ============================================================
resource updateMcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'sherpa-mcp'
  properties: {
    displayName: sherpaMcpApi.properties.displayName
    path: sherpaMcpApi.properties.path
    protocols: sherpaMcpApi.properties.protocols
    serviceUrl: sherpaMcpApi.properties.serviceUrl
    subscriptionRequired: false  // OAuth replaces subscription keys
    apiType: 'mcp'
  }
}

output oauthConfigured bool = true
output prmEndpointRfc9728 string = '${apimGatewayUrl}/.well-known/oauth-protected-resource/sherpa/mcp'
output prmEndpointSuffix string = '${apimGatewayUrl}/sherpa/mcp/.well-known/oauth-protected-resource'
