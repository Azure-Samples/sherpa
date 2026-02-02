@description('Name of the Function App')
param name string

@description('Location for the resource')
param location string

@description('Tags for the resource')
param tags object

@description('Storage account name for Function App')
param storageAccountName string

@description('Managed identity resource ID')
param identityId string

@description('Managed identity client ID')
param identityClientId string

@description('Azure AI Services endpoint for PII detection')
param aiServicesEndpoint string

@description('Content Safety endpoint for Prompt Shields')
param contentSafetyEndpoint string

@description('Application Insights connection string (shared across all services)')
param appInsightsConnectionString string

@description('The azd service name for deployment linking (e.g., security-function-v1 or security-function-v2)')
param azdServiceName string

// Get reference to storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Flex Consumption Plan
resource flexPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${name}-plan'
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true // Linux
  }
}

// Function App (Flex Consumption)
resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': azdServiceName })
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    serverFarmId: flexPlan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}deployments'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'python'
        version: '3.11'
      }
    }
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'AI_SERVICES_ENDPOINT'
          value: aiServicesEndpoint
        }
        {
          name: 'CONTENT_SAFETY_ENDPOINT'
          value: contentSafetyEndpoint
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: identityClientId
        }
      ]
    }
  }
}

// Blob container for deployments
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource deploymentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'deployments'
  properties: {
    publicAccess: 'None'
  }
}

output id string = functionApp.id
output name string = functionApp.name
output url string = 'https://${functionApp.properties.defaultHostName}'
