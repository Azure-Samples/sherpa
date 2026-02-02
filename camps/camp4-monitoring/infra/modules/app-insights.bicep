@description('Name prefix for Application Insights')
param name string

@description('Location for the resource')
param location string

@description('Tags for the resource')
param tags object

@description('Log Analytics workspace ID for Application Insights')
param logAnalyticsWorkspaceId string

// Shared Application Insights for all services (APIM, Container Apps, Functions)
// This enables unified telemetry and cross-service KQL queries
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    // 100% sampling for workshop visibility - adjust for production
    SamplingPercentage: 100
  }
}

output id string = appInsights.id
output name string = appInsights.name
output connectionString string = appInsights.properties.ConnectionString
output instrumentationKey string = appInsights.properties.InstrumentationKey
