param environmentId string
param location string
param tags object
param containerRegistryName string
param prefix string

// Create short resource token for Container App names (32 char limit)
var resourceToken = substring(replace(prefix, '-', ''), 0, min(length(replace(prefix, '-', '')), 10))

// Reference existing ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

// Sherpa MCP Server (name must be <= 32 chars)
resource sherpaMcpServer 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'ca-sherpa-${resourceToken}'
  location: location
  tags: tags
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
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'sherpa-mcp-server'
          image: '${acr.properties.loginServer}/sherpa-mcp-server:latest'
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
        maxReplicas: 3
      }
    }
  }
}

// Trail API
resource trailApi 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'ca-trail-${resourceToken}'
  location: location
  tags: tags
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
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'trail-api'
          image: '${acr.properties.loginServer}/trail-api:latest'
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
        maxReplicas: 3
      }
    }
  }
}

output sherpaMcpServerUrl string = 'https://${sherpaMcpServer.properties.configuration.ingress.fqdn}'
output sherpaMcpServerFqdn string = sherpaMcpServer.properties.configuration.ingress.fqdn
output trailApiUrl string = 'https://${trailApi.properties.configuration.ingress.fqdn}'
output trailApiFqdn string = trailApi.properties.configuration.ingress.fqdn
