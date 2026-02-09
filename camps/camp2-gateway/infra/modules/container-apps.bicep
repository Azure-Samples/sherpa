@description('Container Apps Environment ID')
param containerAppsEnvironmentId string

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('Container Registry login server')
param containerRegistryServer string

@description('Managed Identity ID for ACR access')
param identityId string

// Sherpa MCP Server - Pre-provisioned with placeholder
resource sherpaMcpServer 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'sherpa-mcp-server'
  location: location
  tags: union(tags, {
    'azd-service-name': 'sherpa-mcp-server'
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistryServer
          identity: identityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'sherpa-mcp-server'
          // Public placeholder - azd deploy will replace with actual image from ACR
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'PORT'
              value: '8000'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// Trail API - Pre-provisioned with placeholder
resource trailApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'trail-api'
  location: location
  tags: union(tags, {
    'azd-service-name': 'trail-api'
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistryServer
          identity: identityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'trail-api'
          // Public placeholder - azd deploy will replace with actual image from ACR
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'PORT'
              value: '8001'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// Outputs for waypoint scripts
output sherpaServerFqdn string = sherpaMcpServer.properties.configuration.ingress.fqdn
output sherpaServerUrl string = 'https://${sherpaMcpServer.properties.configuration.ingress.fqdn}'
output trailApiFqdn string = trailApi.properties.configuration.ingress.fqdn
output trailApiUrl string = 'https://${trailApi.properties.configuration.ingress.fqdn}'
