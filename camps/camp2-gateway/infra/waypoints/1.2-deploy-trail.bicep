// Waypoint 1.2: Deploy Trail API to APIM
// Creates backend, API, Product, and subscription key (no OAuth yet)

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

// Trail Services Product - bundles REST API and MCP server
resource trailProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  parent: apim
  name: 'trail-services'
  properties: {
    displayName: 'Trail Services'
    description: 'Access to Trail REST API and MCP server'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
  }
}

// Trail API - exposed as REST API
// Path 'trailapi' is the APIM URL prefix, urlTemplates go directly to backend
resource trailApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'trail-api'
  properties: {
    displayName: 'Trail API'
    description: 'REST API for trail information and permit management'
    path: 'trailapi'
    protocols: ['https']
    subscriptionRequired: true
    apiType: 'http'
    serviceUrl: backendUrl
  }
}

// Add REST API to Product
resource trailApiProductLink 'Microsoft.ApiManagement/service/products/apis@2024-06-01-preview' = {
  parent: trailProduct
  name: trailApi.name
}


// ============================================
// Trail Operations
// ============================================

// GET /trailapi/trails -> backend /trails
resource listTrailsOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'list-trails'
  properties: {
    displayName: 'List Trails'
    description: 'List all available hiking trails'
    method: 'GET'
    urlTemplate: '/trails'
  }
}

// GET /trailapi/trails/{trailId} -> backend /trails/{trailId}
resource getTrailOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'get-trail'
  properties: {
    displayName: 'Get Trail'
    description: 'Get details for a specific trail'
    method: 'GET'
    urlTemplate: '/trails/{trailId}'
    templateParameters: [
      {
        name: 'trailId'
        type: 'string'
        required: true
        description: 'Trail identifier (e.g., summit-trail, base-trail)'
      }
    ]
  }
}

// GET /trailapi/trails/{trailId}/conditions -> backend /trails/{trailId}/conditions
resource checkConditionsOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'check-conditions'
  properties: {
    displayName: 'Check Conditions'
    description: 'Get current trail conditions and hazards'
    method: 'GET'
    urlTemplate: '/trails/{trailId}/conditions'
    templateParameters: [
      {
        name: 'trailId'
        type: 'string'
        required: true
        description: 'Trail identifier'
      }
    ]
  }
}

// ============================================
// Permit Operations
// ============================================

// GET /trailapi/permits/{permitId} -> backend /permits/{permitId}
resource getPermitOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'get-permit'
  properties: {
    displayName: 'Get Permit'
    description: 'Retrieve a trail permit by ID'
    method: 'GET'
    urlTemplate: '/permits/{permitId}'
    templateParameters: [
      {
        name: 'permitId'
        type: 'string'
        required: true
        description: 'Permit identifier (e.g., PRM-2025-0001)'
      }
    ]
  }
}

// POST /trailapi/permits -> backend /permits
resource requestPermitOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: trailApi
  name: 'request-permit'
  properties: {
    displayName: 'Request Permit'
    description: 'Request a new trail permit'
    method: 'POST'
    urlTemplate: '/permits'
  }
}

// Create a subscription for the Trail Services Product
resource trailSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  parent: apim
  name: 'trail-services-subscription'
  properties: {
    displayName: 'Trail Services Access'
    state: 'active'
    scope: trailProduct.id
  }
}

output trailApiId string = trailApi.id
output trailBackendId string = trailBackend.id
output trailProductId string = trailProduct.id
output subscriptionKey string = trailSubscription.listSecrets().primaryKey
