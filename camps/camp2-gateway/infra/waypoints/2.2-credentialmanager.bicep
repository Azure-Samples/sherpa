// Waypoint 2.2: Apply Credential Manager
// Adds get-authorization-context policy for secured backend calls

param apimName string
param tenantId string
param mcpAppClientId string
param apimClientAppId string
param apimClientSecret string
param apimGatewayUrl string
param contentSafetyEndpoint string
param trailApiUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Reference existing Trail API
resource trailApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'trail-api'
}

// Store client secret as named value (secret)
resource clientSecretNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'apim-client-secret'
  properties: {
    displayName: 'apim-client-secret'
    value: apimClientSecret
    secret: true
  }
}

// Apply full policy stack to Trail API permits operation
resource trailPermitsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  name: '${apim.name}/trail-api/get-permits/policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(replace(replace(replace(replace(
      loadTextContent('../policies/credential-manager.xml'),
      '{{tenant-id}}', tenantId),
      '{{mcp-app-client-id}}', mcpAppClientId),
      '{{apim-client-app-id}}', apimClientAppId),
      '{{apim-gateway-url}}', apimGatewayUrl),
      '{{content-safety-endpoint}}', contentSafetyEndpoint),
      '{{trail-api-url}}', trailApiUrl)
  }
  dependsOn: [
    clientSecretNamedValue
  ]
}
