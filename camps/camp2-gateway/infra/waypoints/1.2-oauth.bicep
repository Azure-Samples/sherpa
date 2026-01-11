// Waypoint 1.2: Add OAuth to Trail MCP Server (keeping subscription keys)
// 
// This waypoint configures:
// 1. OAuth token validation on the Trail MCP API (Entra ID tokens)
// 2. RFC 9728 Protected Resource Metadata (PRM) for discovery
//
// Note: MCP API type doesn't support custom operations, so we:
// - Use the existing oauth-prm API for RFC 9728 path-based discovery
// - Apply OAuth validation policy at API level (no suffix pattern for MCP type)
//
// Demonstrates hybrid authentication: subscription key + OAuth
// - Subscription key = which application (tracking/billing)
// - OAuth token = which user (authentication/audit)

param apimName string
param tenantId string
param mcpAppClientId string
param apimGatewayUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

resource trailMcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'trail-mcp'
}

// Reference existing OAuth PRM API (created by 1.1-fix)
resource oauthPrmApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'oauth-prm'
}

// ============================================================
// PRM Operation for Trail MCP (RFC 9728 path-based discovery)
// VS Code tries this path first: /.well-known/oauth-protected-resource/trails/mcp
// ============================================================
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

// Policy for RFC 9728 path-based PRM discovery (Trail MCP)
resource oauthPrmTrailMcpPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: oauthPrmTrailMcpOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(replace(
      loadTextContent('../policies/prm-metadata.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apimGatewayUrl),
      '/sherpa/mcp', '/trails/mcp')  // Update resource path for Trail MCP
  }
}

// ============================================================
// OAuth Token Validation Policy on Trail MCP API
// Validates Entra ID tokens and returns proper 401 with PRM link
// Works WITH subscription keys (both required)
// 
// Note: MCP type APIs don't support operations, so we can only apply
// API-level policy. The 401 response will use context.Api.Path
// which resolves to "trails" for this API.
// ============================================================
resource trailMcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailMcpApi
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

output policyApplied bool = true
