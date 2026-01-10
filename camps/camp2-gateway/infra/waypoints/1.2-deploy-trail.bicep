// Waypoint 1.2: Deploy Trail API to APIM
// Creates backend and API with subscription key (no OAuth yet)

param apimName string
param backendUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Backend pointing to Trail API Container App
resource trailBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'trail-api-backend'
  properties: {
    title: 'Trail API'
    description: 'Backend for Trail API running in Container Apps'
    protocol: 'http'
    url: backendUrl
  }
}

// Trail API - exposed as REST API
resource trailApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'trail-api'
  properties: {
    displayName: 'Trail API'
    description: 'REST API for trail information and permits'
    path: 'trails'
    protocols: ['https']
    subscriptionRequired: true  // Requires subscription key
    apiType: 'http'
    serviceUrl: backendUrl
  }
}

// Define API operations
resource listTrailsOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'list-trails'
  properties: {
    displayName: 'List Trails'
    method: 'GET'
    urlTemplate: '/'
  }
}

resource getTrailOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'get-trail'
  properties: {
    displayName: 'Get Trail'
    method: 'GET'
    urlTemplate: '/{trailId}'
    templateParameters: [
      {
        name: 'trailId'
        type: 'string'
        required: true
      }
    ]
  }
}

resource getPermitsOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'get-permits'
  properties: {
    displayName: 'Get Permits'
    method: 'GET'
    urlTemplate: '/permits'
  }
}

// Create a subscription for the Trail API
resource trailSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  parent: apim
  name: 'trail-api-subscription'
  properties: {
    displayName: 'Trail API Basic Access'
    state: 'active'
    scope: trailApi.id  // Scoped to Trail API only
  }
}

output trailApiId string = trailApi.id
output trailBackendId string = trailBackend.id
output subscriptionKey string = trailSubscription.listSecrets().primaryKey
