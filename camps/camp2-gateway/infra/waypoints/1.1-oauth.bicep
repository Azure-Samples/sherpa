// Waypoint 1.1: Apply OAuth Authentication
// Adds PRM metadata endpoint and OAuth validation policy

param apimName string
param tenantId string
param mcpAppClientId string
param apimGatewayUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Reference existing Sherpa API
resource sherpaApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'sherpa-mcp'
}

// PRM Metadata API (anonymous access for OAuth discovery - RFC 9728)
resource prmApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'oauth-prm'
  properties: {
    displayName: 'OAuth Protected Resource Metadata'
    description: 'RFC 9728 Protected Resource Metadata for OAuth discovery'
    path: '.well-known'
    protocols: ['https']
    subscriptionRequired: false
  }
}

resource prmOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: prmApi
  name: 'get-prm'
  properties: {
    displayName: 'Get Protected Resource Metadata'
    method: 'GET'
    urlTemplate: '/oauth-protected-resource'
  }
}

// PRM policy returns OAuth discovery metadata
resource prmPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: prmApi
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

// Apply OAuth validation policy to Sherpa API
resource sherpaPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: sherpaApi
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

// Update Sherpa API to not require subscription (OAuth is now enforced)
resource sherpaApiUpdate 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'sherpa-mcp'
  properties: {
    displayName: 'Sherpa MCP Server'
    description: 'MCP Server for weather, trails, and gear recommendations'
    path: 'sherpa-mcp'
    protocols: ['https']
    subscriptionRequired: false  // OAuth is now enforced via policy
    type: 'mcp'
    mcpProperties: {
      transportType: 'streamable'
    }
  }
}

output prmApiId string = prmApi.id
