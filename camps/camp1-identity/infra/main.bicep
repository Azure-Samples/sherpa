targetScope = 'resourceGroup'

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Entra ID Application Client ID for JWT validation')
param azureClientId string = ''

@description('Entra ID Tenant ID for JWT validation')
param azureTenantId string = ''

@description('Unique resource suffix - set by preprovision hook via RESOURCE_SUFFIX env var')
param resourceSuffix string = ''

var abbrs = loadJsonContent('abbreviations.json')
// Suffix comes from preprovision hook (RESOURCE_SUFFIX) to avoid soft-delete conflicts.
// The fallback using uniqueString is only for manual deployments and may cause issues.
var suffix = !empty(resourceSuffix) ? resourceSuffix : substring(uniqueString(resourceGroup().id, location), 0, 5)
var tags = {
  workshop: 'sherpa'
  camp: 'camp1'
}

// Log Analytics
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics'
  params: {
    name: '${abbrs.logAnalytics}sherpa-camp1-${suffix}'
    location: location
    tags: tags
  }
}

// Managed Identity
module identity 'modules/managed-identity.bicep' = {
  name: 'managed-identity'
  params: {
    name: '${abbrs.managedIdentity}sherpa-camp1-${suffix}'
    location: location
    tags: tags
  }
}

// Key Vault
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    name: '${abbrs.keyVault}sherpa-camp1-${suffix}'
    location: location
    tags: tags
    principalId: identity.outputs.principalId
  }
}

// Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    name: '${abbrs.containerRegistry}sherpacamp1${suffix}'
    location: location
    tags: tags
    principalId: identity.outputs.principalId
  }
}

// Container Apps Environment
module containerAppsEnv 'modules/container-apps-env.bicep' = {
  name: 'container-apps-env'
  params: {
    name: '${abbrs.containerAppsEnv}sherpa-camp1-${suffix}'
    location: location
    tags: tags
    logAnalyticsId: logAnalytics.outputs.id
  }
}

// Vulnerable Server Container App
module vulnerableServer 'modules/container-app.bicep' = {
  name: 'vulnerable-server'
  params: {
    name: '${abbrs.containerApp}vulnerable-${suffix}'
    location: location
    tags: tags
    serviceName: 'vulnerable-server'
    environmentId: containerAppsEnv.outputs.id
    containerImage: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    containerRegistryServer: containerRegistry.outputs.loginServer
    identityId: identity.outputs.id
    environmentVariables: [
      {
        name: 'REQUIRED_TOKEN'
        value: 'camp1_demo_token_INSECURE'
      }
    ]
  }
}

// Secure Server Container App
module secureServer 'modules/container-app.bicep' = {
  name: 'secure-server'
  params: {
    name: '${abbrs.containerApp}secure-${suffix}'
    location: location
    tags: tags
    serviceName: 'secure-server'
    environmentId: containerAppsEnv.outputs.id
    containerImage: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    containerRegistryServer: containerRegistry.outputs.loginServer
    identityId: identity.outputs.id
    environmentVariables: [
      {
        name: 'KEY_VAULT_URL'
        value: keyVault.outputs.vaultUri
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: !empty(azureClientId) ? azureClientId : identity.outputs.clientId
      }
      {
        name: 'AZURE_TENANT_ID'
        value: !empty(azureTenantId) ? azureTenantId : tenant().tenantId
      }
      {
        name: 'RESOURCE_URL'
        // Use the predictable FQDN pattern: <app-name>.<env-default-domain>
        value: 'https://${abbrs.containerApp}secure-${suffix}.${containerAppsEnv.outputs.defaultDomain}'
      }
    ]
  }
}

// Outputs for azd
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup().name

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnv.outputs.id

output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_KEY_VAULT_URL string = keyVault.outputs.vaultUri

output AZURE_MANAGED_IDENTITY_ID string = identity.outputs.id
output AZURE_MANAGED_IDENTITY_PRINCIPAL_ID string = identity.outputs.principalId
output AZURE_MANAGED_IDENTITY_CLIENT_ID string = identity.outputs.clientId

output VULNERABLE_SERVER_URL string = vulnerableServer.outputs.url
output VULNERABLE_SERVER_NAME string = vulnerableServer.outputs.name
output SECURE_SERVER_URL string = secureServer.outputs.url
output SECURE_SERVER_NAME string = secureServer.outputs.name
