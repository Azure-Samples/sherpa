targetScope = 'resourceGroup'

// Import region selector functions
import { getApimBasicV2Region, getContentSafetyRegion } from './modules/region-selector.bicep'

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Entra ID Tenant ID')
param tenantId string = tenant().tenantId

@description('Publisher email for APIM')
param publisherEmail string = 'admin@example.com'

@description('Publisher name for APIM')
param publisherName string = 'Sherpa Workshop'

// Entra ID app registration IDs (set by preprovision hook via azd env)
// azd automatically converts SCREAMING_SNAKE_CASE env vars to camelCase params
@description('MCP Resource App Client ID')
param mcpAppClientId string = ''

@description('APIM Client App ID for Credential Manager')
param apimClientAppId string = ''

@description('Unique resource suffix - set by preprovision hook via RESOURCE_SUFFIX env var')
param resourceSuffix string = ''

// Suffix MUST be provided by preprovision hook to avoid soft-delete conflicts.
// The fallback using deployment().name is only for manual deployments and may cause issues.
var effectiveSuffix = !empty(resourceSuffix) ? resourceSuffix : substring(uniqueString(resourceGroup().id, deployment().name), 0, 5)

// Adjusted regions for services with limited availability
var apimLocation = getApimBasicV2Region(location)
var contentSafetyLocation = getContentSafetyRegion(location)

// Naming convention: camp4-{suffix}
// Suffix comes from preprovision hook (RESOURCE_SUFFIX) or auto-generates
var prefix = 'camp4-${effectiveSuffix}'

// Tags for all resources
var tags = {
  'azd-env-name': resourceGroup().name
  camp: 'camp4-monitoring'
}

// Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics'
  params: {
    name: 'log-${prefix}'
    location: location
    tags: tags
  }
}

// Shared Application Insights for all services (enables unified telemetry)
module appInsights 'modules/app-insights.bicep' = {
  name: 'app-insights'
  params: {
    name: 'ai-${prefix}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Container Registry
// Container registries: lowercase alphanumeric only, 5-50 chars
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    name: 'cr${replace(prefix, '-', '')}'
    location: location
    tags: tags
    principalId: containerAppsIdentity.outputs.principalId
  }
}

// Managed Identity for APIM
module managedIdentity 'modules/managed-identity.bicep' = {
  name: 'managed-identity'
  params: {
    name: 'id-apim-${prefix}'
    location: location
    tags: tags
  }
}

// Managed Identity for Container Apps
module containerAppsIdentity 'modules/managed-identity.bicep' = {
  name: 'container-apps-identity'
  params: {
    name: 'id-apps-${prefix}'
    location: location
    tags: tags
  }
}

// Managed Identity for Function App
module functionIdentity 'modules/managed-identity.bicep' = {
  name: 'function-identity'
  params: {
    name: 'id-func-${prefix}'
    location: location
    tags: tags
  }
}

// Container Apps Environment
module containerAppsEnv 'modules/container-apps-env.bicep' = {
  name: 'container-apps-env'
  params: {
    name: 'cae-${prefix}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Content Safety (Layer 1)
module contentSafety 'modules/content-safety.bicep' = {
  name: 'content-safety'
  params: {
    name: 'cs-${prefix}'
    location: contentSafetyLocation
    tags: tags
    apimIdentityPrincipalId: managedIdentity.outputs.principalId
    functionIdentityPrincipalId: functionIdentity.outputs.principalId
  }
}

// Azure AI Services (for PII detection - Layer 2)
module aiServices 'modules/ai-services.bicep' = {
  name: 'ai-services'
  params: {
    name: 'ai-${prefix}'
    location: location
    tags: tags
    functionIdentityPrincipalId: functionIdentity.outputs.principalId
  }
}

// Storage Account for Function App v1 (Basic Logging)
// Storage accounts: lowercase alphanumeric only, 3-24 chars
var functionAppV1Name = 'funcv1-${prefix}'
module storageAccountV1 'modules/storage-account.bicep' = {
  name: 'storage-account-v1'
  params: {
    name: 'stv1${replace(prefix, '-', '')}'
    location: location
    tags: tags
    principalId: functionIdentity.outputs.principalId
  }
}

// Storage Account for Function App v2 (Structured Logging)
var functionAppV2Name = 'funcv2-${prefix}'
module storageAccountV2 'modules/storage-account.bicep' = {
  name: 'storage-account-v2'
  params: {
    name: 'stv2${replace(prefix, '-', '')}'
    location: location
    tags: tags
    principalId: functionIdentity.outputs.principalId
  }
}

// Function App v1 (Layer 2 - Security Functions - Basic Logging)
// This is the "hidden" state - logs security events but can't be queried/alerted
module functionAppV1 'modules/function-app.bicep' = {
  name: 'function-app-v1'
  params: {
    name: functionAppV1Name
    location: location
    tags: tags
    storageAccountName: storageAccountV1.outputs.name
    identityId: functionIdentity.outputs.id
    identityClientId: functionIdentity.outputs.clientId
    aiServicesEndpoint: aiServices.outputs.endpoint
    contentSafetyEndpoint: contentSafety.outputs.endpoint
    appInsightsConnectionString: appInsights.outputs.connectionString
    azdServiceName: 'security-function-v1'
  }
}

// Function App v2 (Layer 2 - Security Functions - Structured Logging)
// This is the "visible" state - uses security_logger.py with Azure Monitor
module functionAppV2 'modules/function-app.bicep' = {
  name: 'function-app-v2'
  params: {
    name: functionAppV2Name
    location: location
    tags: tags
    storageAccountName: storageAccountV2.outputs.name
    identityId: functionIdentity.outputs.id
    identityClientId: functionIdentity.outputs.clientId
    aiServicesEndpoint: aiServices.outputs.endpoint
    contentSafetyEndpoint: contentSafety.outputs.endpoint
    appInsightsConnectionString: appInsights.outputs.connectionString
    azdServiceName: 'security-function-v2'
  }
}

// API Management (with OAuth + Content Safety pre-configured)
module apim 'modules/apim.bicep' = {
  name: 'apim'
  params: {
    name: 'apim-${prefix}'
    location: apimLocation
    tags: tags
    publisherEmail: publisherEmail
    publisherName: publisherName
    managedIdentityId: managedIdentity.outputs.id
    managedIdentityClientId: managedIdentity.outputs.clientId
    apimClientAppId: apimClientAppId
    tenantId: tenantId
    mcpAppClientId: mcpAppClientId
    appInsightsId: appInsights.outputs.id
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
  }
}

// Container Apps (Sherpa MCP Server + Trail API)
module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    containerAppsEnvironmentId: containerAppsEnv.outputs.id
    location: location
    tags: tags
    containerRegistryServer: containerRegistry.outputs.loginServer
    identityId: containerAppsIdentity.outputs.id
    appInsightsConnectionString: appInsights.outputs.connectionString
    sanitizeFunctionUrl: '${functionAppV1.outputs.url}/api/sanitize-output'
    sanitizeEnabled: true  // Camp 4: sanitization enabled by default
  }
}

// APIM Diagnostic Settings - routes GatewayLogs to Log Analytics
// Pre-configured for immediate visibility (no manual enablement needed in Section 1)
// This enables the ApiManagementGatewayLogs table for KQL queries
module apimDiagnostics 'modules/apim-diagnostics.bicep' = {
  name: 'apim-diagnostics'
  params: {
    apimResourceId: apim.outputs.id
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// NOTE: Azure Monitor Workbook and Action Group are NOT deployed here - they are created by
// workshop scripts (3.1-deploy-workbook.sh, 3.2-create-alerts.sh) as part of the 
// "visible → actionable" learning progression in Section 3.
// 
// APIM Diagnostic Settings ARE deployed (apim-diagnostics module above) so that
// ApiManagementGatewayLogs is available immediately. Section 1 focuses on understanding
// and querying these logs rather than enabling them.

// Outputs for azd and waypoint scripts
output AZURE_RESOURCE_GROUP string = resourceGroup().name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenantId
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnv.outputs.id
output APIM_GATEWAY_URL string = apim.outputs.gatewayUrl
output APIM_NAME string = apim.outputs.name
output APIM_LOCATION string = apimLocation
output CONTENT_SAFETY_ENDPOINT string = contentSafety.outputs.endpoint
output CONTENT_SAFETY_LOCATION string = contentSafetyLocation
output MANAGED_IDENTITY_PRINCIPAL_ID string = managedIdentity.outputs.principalId
output MANAGED_IDENTITY_CLIENT_ID string = managedIdentity.outputs.clientId
output SHERPA_SERVER_URL string = containerApps.outputs.sherpaServerUrl
output TRAIL_API_URL string = containerApps.outputs.trailApiUrl
output FUNCTION_APP_V1_NAME string = functionAppV1.outputs.name
output FUNCTION_APP_V1_URL string = functionAppV1.outputs.url
output FUNCTION_APP_V2_NAME string = functionAppV2.outputs.name
output FUNCTION_APP_V2_URL string = functionAppV2.outputs.url
// Legacy outputs for backward compatibility - point to v1 by default
output FUNCTION_APP_NAME string = functionAppV1.outputs.name
output FUNCTION_APP_URL string = functionAppV1.outputs.url
output AI_SERVICES_ENDPOINT string = aiServices.outputs.endpoint
output LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.id
output LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.outputs.name
// NOTE: WORKBOOK_ID and ACTION_GROUP_ID removed - created by workshop scripts, not Bicep
output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsights.outputs.connectionString
output APPLICATIONINSIGHTS_NAME string = appInsights.outputs.name
