@description('Name of the action group')
param name string

@description('Location for the action group (use global for action groups)')
param location string = 'global'

@description('Tags for the resource')
param tags object

@description('Short name for the action group (max 12 characters)')
param shortName string = 'MCPSecAlerts'

@description('Optional email address for notifications')
param notificationEmail string = ''

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    groupShortName: shortName
    enabled: true
    // Email receiver (optional - configured via parameter)
    emailReceivers: notificationEmail != '' ? [
      {
        name: 'SecurityTeam'
        emailAddress: notificationEmail
        useCommonAlertSchema: true
      }
    ] : []
    // Webhook receivers can be added for integration with other systems
    webhookReceivers: []
    // Azure app push notifications (for Azure mobile app)
    azureAppPushReceivers: []
    // SMS receivers
    smsReceivers: []
    // Voice call receivers
    voiceReceivers: []
    // Logic App receivers
    logicAppReceivers: []
    // Azure Function receivers
    azureFunctionReceivers: []
    // ARM role receivers (notify users with specific Azure roles)
    armRoleReceivers: []
  }
}

output id string = actionGroup.id
output name string = actionGroup.name
