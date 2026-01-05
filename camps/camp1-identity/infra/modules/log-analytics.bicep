@description('Log Analytics workspace name')
param name string

@description('Location for resources')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output id string = logAnalytics.id
output customerId string = logAnalytics.properties.customerId
