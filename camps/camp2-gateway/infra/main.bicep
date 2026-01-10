targetScope = 'resourceGroup'

// Import region selector functions
import { getApiCenterRegion, getApimBasicV2Region, getContentSafetyRegion } from './modules/region-selector.bicep'

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Entra ID Tenant ID')
param tenantId string = tenant().tenantId

@description('Publisher email for APIM')
param publisherEmail string = 'admin@example.com'

@description('Publisher name for APIM')
param publisherName string = 'Sherpa Workshop'

// Entra ID app registration IDs (set by preprovision hook)
@description('MCP Resource App Client ID')
param mcpAppClientId string

@description('APIM Client App ID for Credential Manager')
param apimClientAppId string

// Get environment name from resource group
var environmentName = resourceGroup().name

// Tags for all resources
var tags = {
  'azd-env-name': environmentName
  camp: 'camp2-gateway'
}

// Adjusted regions for services with limited availability
var apiCenterLocation = getApiCenterRegion(location)
var apimLocation = getApimBasicV2Region(location)
var contentSafetyLocation = getContentSafetyRegion(location)

// Naming convention
var resourceToken = toLower(uniqueString(resourceGroup().id, location))
var prefix = '${environmentName}-${resourceToken}'

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

// Content Safety (deployed now, configured via waypoint 2.1)
module contentSafety 'modules/content-safety.bicep' = {
  name: 'content-safety'
  params: {
    name: 'cs-${prefix}'
    location: contentSafetyLocation
    tags: tags
    apimIdentityPrincipalId: managedIdentity.outputs.principalId
  }
}

// API Management (empty - APIs added via waypoint scripts)
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

// API Center (empty - APIs registered via waypoint 1.3)
module apiCenter 'modules/api-center.bicep' = {
  name: 'api-center'
  params: {
    name: 'apic-${prefix}'
    location: apiCenterLocation
    tags: tags
  }
}

// Container Apps (pre-provisioned with placeholder images)
// azd deploy will update these with actual code during workshop
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
output API_CENTER_NAME string = apiCenter.outputs.name
output API_CENTER_LOCATION string = apiCenterLocation
output MANAGED_IDENTITY_PRINCIPAL_ID string = managedIdentity.outputs.principalId
output MANAGED_IDENTITY_CLIENT_ID string = managedIdentity.outputs.clientId
output SHERPA_SERVER_URL string = containerApps.outputs.sherpaServerUrl
output TRAIL_API_URL string = containerApps.outputs.trailApiUrl
