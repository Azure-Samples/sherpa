param name string
param location string
param tags object

resource apiCenter 'Microsoft.ApiCenter/services@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Free'
  }
  properties: {}
}

output id string = apiCenter.id
output name string = apiCenter.name
