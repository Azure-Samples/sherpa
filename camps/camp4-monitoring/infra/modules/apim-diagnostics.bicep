@description('The resource ID of the APIM instance')
param apimResourceId string

@description('The resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('Diagnostic settings name')
param diagnosticSettingsName string = 'mcp-security-logs'

// Reference the existing APIM resource
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: last(split(apimResourceId, '/'))
}

// Azure Monitor Diagnostic Settings for APIM
// This routes GatewayLogs to Log Analytics for querying and alerting
//
// IMPORTANT: Only enable GatewayLogs and GatewayLlmLogs categories.
// Enabling all 4 categories (including WebSocketConnectionLogs and DeveloperPortalAuditLogs)
// has been observed to cause issues with log routing to dedicated (resource-specific) tables.
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  scope: apim
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'  // Use resource-specific tables (ApiManagementGatewayLogs)
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'GatewayLlmLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      // WebSocketConnectionLogs and DeveloperPortalAuditLogs intentionally NOT enabled
      // to avoid issues with log routing to dedicated tables
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output diagnosticSettingsId string = diagnosticSettings.id
output diagnosticSettingsName string = diagnosticSettings.name
