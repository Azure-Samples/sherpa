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
param mcpAppClientId string

@description('APIM Client App ID for Credential Manager')
param apimClientAppId string

// Adjusted regions for services with limited availability
var apimLocation = getApimBasicV2Region(location)
var contentSafetyLocation = getContentSafetyRegion(location)

// Naming convention: camp3-{unique suffix}
// Uses a short unique suffix derived from resource group ID
var suffix = substring(uniqueString(resourceGroup().id, location), 0, 5)
var prefix = 'camp3-${suffix}'

// Tags for all resources
var tags = {
  'azd-env-name': resourceGroup().name
  camp: 'camp3-io-security'
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

// Storage Account for Function App
// Storage accounts: lowercase alphanumeric only, 3-24 chars
var functionAppName = 'func-${prefix}'
module storageAccount 'modules/storage-account.bicep' = {
  name: 'storage-account'
  params: {
    name: 'st${replace(prefix, '-', '')}'
    location: location
    tags: tags
    principalId: functionIdentity.outputs.principalId
  }
}

// Function App (Layer 2 - Security Functions)
module functionApp 'modules/function-app.bicep' = {
  name: 'function-app'
  params: {
    name: functionAppName
    location: location
    tags: tags
    storageAccountName: storageAccount.outputs.name
    identityId: functionIdentity.outputs.id
    identityClientId: functionIdentity.outputs.clientId
    aiServicesEndpoint: aiServices.outputs.endpoint
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
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
  }
}

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
output FUNCTION_APP_NAME string = functionApp.outputs.name
output FUNCTION_APP_URL string = functionApp.outputs.url
output AI_SERVICES_ENDPOINT string = aiServices.outputs.endpoint
