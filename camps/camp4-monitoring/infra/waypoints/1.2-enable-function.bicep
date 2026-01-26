/*
  Waypoint 1.2: Enable Security Function in APIM
  
  This waypoint adds the function URL as a named value and can be used
  to programmatically update the APIM configuration.
  
  Note: For the workshop, we use scripts to update policies dynamically.
  This bicep file is provided as a reference for production deployments.
*/

param apimName string
param functionAppUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

// Add function URL as named value
resource namedValueFunctionUrl 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'function-app-url'
  properties: {
    displayName: 'function-app-url'
    value: functionAppUrl
    secret: false
  }
}
