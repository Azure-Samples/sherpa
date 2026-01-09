param apimName string
param tenantId string
param mcpAppClientId string
param contentSafetyBackendId string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

// Named values for use in policies
resource namedValueTenantId 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apim
  name: 'tenant-id'
  properties: {
    displayName: 'tenant-id'
    value: tenantId
    secret: false
  }
}

resource namedValueMcpAppClientId 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apim
  name: 'mcp-app-client-id'
  properties: {
    displayName: 'mcp-app-client-id'
    value: mcpAppClientId
    secret: false
  }
}

resource namedValueContentSafetyBackend 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apim
  name: 'content-safety-backend-id'
  properties: {
    displayName: 'content-safety-backend-id'
    value: contentSafetyBackendId
    secret: false
  }
}

// Note: Policies are applied via deployment scripts using XML files in infra/policies/
// This allows for better maintainability and validation of policy XML
