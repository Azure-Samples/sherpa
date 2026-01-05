@description('Container App name')
param name string

@description('Location for resources')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

@description('Container Apps Environment ID')
param environmentId string

@description('Container image')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Container registry server')
param containerRegistryServer string

@description('Managed Identity ID')
param identityId string

@description('Environment variables')
param environmentVariables array = []

@description('Service name for azd tagging')
param serviceName string

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: union(tags, {
    'azd-service-name': serviceName
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
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
          name: serviceName
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: environmentVariables
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output id string = containerApp.id
output name string = containerApp.name
output fqdn string = containerApp.properties.configuration.ingress.fqdn
output url string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
