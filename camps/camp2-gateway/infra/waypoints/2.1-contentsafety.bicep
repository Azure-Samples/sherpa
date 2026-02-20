// Waypoint 2.1: Apply Content Safety
// Uses policy fragments for modular, reusable content safety checks
//
// Benefits of fragments:
// - Reusability: Same logic used across multiple APIs
// - Maintainability: Update once, applies everywhere
// - Testability: Fragment can be validated independently
// - Cleaner policies: Main policy stays focused

param apimName string
param tenantId string
param mcpAppClientId string
param apimGatewayUrl string
param contentSafetyEndpoint string
param managedIdentityClientId string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Reference existing APIs
resource sherpaApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'sherpa-mcp'
}

resource trailMcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'trail-mcp'
}

// ============================================================================
// Named Values (referenced by fragment and policies via {{...}} syntax)
// ============================================================================

resource namedValueContentSafety 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'content-safety-endpoint'
  properties: {
    displayName: 'content-safety-endpoint'
    value: contentSafetyEndpoint
    secret: false
  }
}

resource namedValueIdentity 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'managed-identity-client-id'
  properties: {
    displayName: 'managed-identity-client-id'
    value: managedIdentityClientId
    secret: false
  }
}

// ============================================================================
// Policy Fragment: MCP Content Safety
// ============================================================================

resource mcpContentSafetyFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apim
  name: 'mcp-content-safety'
  properties: {
    description: 'Extracts MCP tool arguments and checks for prompt injection using Azure Content Safety Prompt Shields API'
    format: 'rawxml'
    value: loadTextContent('../policies/fragments/mcp-content-safety.xml')
  }
  dependsOn: [
    namedValueContentSafety
    namedValueIdentity
  ]
}

// ============================================================================
// API Policies (using include-fragment)
// ============================================================================

// Apply policy to Sherpa API
resource sherpaPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: sherpaApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(
      loadTextContent('../policies/oauth-ratelimit-contentsafety.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apimGatewayUrl)
  }
  dependsOn: [
    mcpContentSafetyFragment
  ]
}

// Apply policy to Trail MCP Server
resource trailMcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailMcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(
      loadTextContent('../policies/oauth-ratelimit-contentsafety.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-gateway-url}}', apimGatewayUrl)
  }
  dependsOn: [
    mcpContentSafetyFragment
  ]
}

output fragmentId string = mcpContentSafetyFragment.id
