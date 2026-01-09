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

// Container Apps (Sherpa MCP Server + Trail API)
module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    environmentId: containerAppsEnv.outputs.id
    location: location
    tags: tags
    containerRegistryName: containerRegistry.outputs.name
    prefix: prefix
  }
}

// Content Safety
module contentSafety 'modules/content-safety.bicep' = {
  name: 'content-safety'
  params: {
    name: 'cs-${prefix}'
    location: contentSafetyLocation
    tags: tags
    apimIdentityPrincipalId: managedIdentity.outputs.principalId
  }
}

// API Management
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
  }
}

// APIM Backends
module apimBackends 'modules/apim-backends.bicep' = {
  name: 'apim-backends'
  params: {
    apimName: apim.outputs.name
    sherpaMcpServerUrl: containerApps.outputs.sherpaMcpServerUrl
    trailApiUrl: containerApps.outputs.trailApiUrl
    contentSafetyEndpoint: contentSafety.outputs.endpoint
  }
}

// APIM MCP Servers (import existing + expose REST)
module apimMcpServers 'modules/apim-mcp-servers.bicep' = {
  name: 'apim-mcp-servers'
  params: {
    apimName: apim.outputs.name
    sherpaBackendId: apimBackends.outputs.sherpaBackendId
    trailApiUrl: apimBackends.outputs.trailApiUrl
  }
}

// APIM Policies
module apimPolicies 'modules/apim-policies.bicep' = {
  name: 'apim-policies'
  params: {
    apimName: apim.outputs.name
    tenantId: tenantId
    mcpAppClientId: mcpAppClientId
    contentSafetyBackendId: apimBackends.outputs.contentSafetyBackendId
  }
}

// API Center
module apiCenter 'modules/api-center.bicep' = {
  name: 'api-center'
  params: {
    name: 'apic-${prefix}'
    location: apiCenterLocation
    tags: tags
  }
}

// Outputs
output AZURE_RESOURCE_GROUP string = resourceGroup().name
output AZURE_LOCATION string = location
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output APIM_GATEWAY_URL string = apim.outputs.gatewayUrl
output APIM_NAME string = apim.outputs.name
output APIM_LOCATION string = apimLocation
output SHERPA_MCP_SERVER_URL string = containerApps.outputs.sherpaMcpServerUrl
output TRAIL_API_URL string = containerApps.outputs.trailApiUrl
output CONTENT_SAFETY_ENDPOINT string = contentSafety.outputs.endpoint
output CONTENT_SAFETY_LOCATION string = contentSafetyLocation
output API_CENTER_NAME string = apiCenter.outputs.name
output API_CENTER_LOCATION string = apiCenterLocation
output CONTAINER_APPS_ENV_ID string = containerAppsEnv.outputs.id
