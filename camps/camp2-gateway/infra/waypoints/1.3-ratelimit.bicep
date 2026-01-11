// Waypoint 1.3: Apply Rate Limiting
// Adds rate limiting policy to Trail API

param apimName string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Reference Trail API
resource trailApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: 'trail-api'
}

// Apply Rate Limiting to Trail REST API
resource trailPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: trailApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../policies/ratelimit-only.xml')
  }
}
