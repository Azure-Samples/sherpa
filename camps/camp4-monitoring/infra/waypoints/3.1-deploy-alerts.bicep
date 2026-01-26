targetScope = 'resourceGroup'

@description('Primary location for resources')
param location string = resourceGroup().location

@description('Optional email address for alert notifications')
param notificationEmail string = ''

@description('Unique resource suffix - auto-generated if not provided')
param resourceSuffix string = ''

// Generate suffix: use provided value, or auto-generate from resource group
var effectiveSuffix = !empty(resourceSuffix) ? resourceSuffix : substring(uniqueString(resourceGroup().id), 0, 5)

// Get the existing Log Analytics workspace
// The workspace was created during initial azd provision
var prefix = 'camp4-${effectiveSuffix}'

// Tags for resources
var tags = {
  'azd-env-name': resourceGroup().name
  camp: 'camp4-monitoring'
  waypoint: '3.1-deploy-alerts'
}

// Reference existing Log Analytics workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: 'log-${prefix}'
}

// Deploy Action Group for alert notifications
module actionGroup '../modules/action-group.bicep' = {
  name: 'action-group-waypoint'
  params: {
    name: 'ag-${prefix}'
    tags: tags
    notificationEmail: notificationEmail
  }
}

// Deploy Alert Rules
module alertRules '../modules/alert-rules.bicep' = {
  name: 'alert-rules-waypoint'
  params: {
    namePrefix: 'alert-${prefix}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.id
    actionGroupId: actionGroup.outputs.id
  }
}

// Outputs
output ACTION_GROUP_ID string = actionGroup.outputs.id
output ACTION_GROUP_NAME string = actionGroup.outputs.name
output HIGH_INJECTION_ALERT_ID string = alertRules.outputs.highInjectionRateAlertId
output CREDENTIAL_EXPOSURE_ALERT_ID string = alertRules.outputs.credentialExposureAlertId
