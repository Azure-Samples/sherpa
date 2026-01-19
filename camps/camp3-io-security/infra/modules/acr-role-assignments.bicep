@description('Container Registry name')
param acrName string

@description('Sherpa MCP Server Principal ID')
param sherpaPrincipalId string

@description('Trail API Principal ID')
param trailPrincipalId string

// Reference existing ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// ACR Pull role definition
var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

// Grant Sherpa MCP Server ACR Pull access
resource sherpaAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, sherpaPrincipalId, acrPullRoleDefinitionId, 'sherpa')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: sherpaPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Trail API ACR Pull access
resource trailAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, trailPrincipalId, acrPullRoleDefinitionId, 'trail')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: trailPrincipalId
    principalType: 'ServicePrincipal'
  }
}
