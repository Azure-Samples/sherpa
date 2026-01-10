param name string
param location string
param tags object
param publisherEmail string
param publisherName string
param managedIdentityId string
param managedIdentityClientId string
param apimClientAppId string
param tenantId string
param mcpAppClientId string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Named value for managed identity client ID (used in policies)
resource namedValueIdentityClientId 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'managed-identity-client-id'
  properties: {
    displayName: 'managed-identity-client-id'
    value: managedIdentityClientId
    secret: false
  }
}

// Named value for APIM client app ID (used in Credential Manager policy)
resource namedValueApimClientId 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'apim-client-app-id'
  properties: {
    displayName: 'apim-client-app-id'
    value: apimClientAppId
    secret: false
  }
}

// Named value for APIM Gateway URL
resource namedValueGatewayUrl 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'apim-gateway-url'
  properties: {
    displayName: 'apim-gateway-url'
    value: apim.properties.gatewayUrl
    secret: false
  }
}

// Named value for tenant ID (used in OAuth policies)
resource namedValueTenantId 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'tenant-id'
  properties: {
    displayName: 'tenant-id'
    value: tenantId
    secret: false
  }
}

// Named value for MCP app client ID (used in OAuth policies)
resource namedValueMcpAppClientId 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'mcp-app-client-id'
  properties: {
    displayName: 'mcp-app-client-id'
    value: mcpAppClientId
    secret: false
  }
}

output id string = apim.id
output name string = apim.name
output gatewayUrl string = apim.properties.gatewayUrl
output managementUrl string = apim.properties.managementApiUrl
