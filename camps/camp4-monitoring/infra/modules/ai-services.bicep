@description('Name of the AI Services resource')
param name string

@description('Location for the resource')
param location string

@description('Tags for the resource')
param tags object

@description('Principal ID of the function identity to grant access')
param functionIdentityPrincipalId string

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'CognitiveServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Grant Cognitive Services User role to Function App identity
resource cognitiveServicesUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, functionIdentityPrincipalId, 'CognitiveServicesUser')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: functionIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output id string = aiServices.id
output name string = aiServices.name
output endpoint string = aiServices.properties.endpoint
