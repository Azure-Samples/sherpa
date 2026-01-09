// Region Selector for Camp 2 Gateway
// Handles resource types that may not be available in all regions

func getAdjustedRegion(location string, map object) string =>
  map.?overrides[?location] ?? (contains(map.?supportedRegions ?? [], location) ? location : (map.?default ?? location))

// API Center available regions
// See: https://learn.microsoft.com/azure/api-center/overview
var apiCenterRegionMap = {
  supportedRegions: [
    'eastus'
    'westeurope'
    'uksouth'
    'centralindia'
    'australiaeast'
    'francecentral'
    'swedencentral'
    'canadacentral'
  ]
  overrides: {
    westus: 'westus2'
    westus2: 'eastus'
    westus3: 'eastus'
    eastus2: 'eastus'
    centralus: 'eastus'
    southcentralus: 'eastus'
    northcentralus: 'eastus'
    northeurope: 'westeurope'
    southeastasia: 'australiaeast'
    eastasia: 'australiaeast'
  }
  default: 'eastus'
}

@export()
@description('Based on an intended region, gets a supported region for API Center.')
func getApiCenterRegion(location string) string => getAdjustedRegion(location, apiCenterRegionMap)

// API Management Basic v2 available regions
// See: https://learn.microsoft.com/azure/api-management/api-management-region-availability
var apimBasicV2RegionMap = {
  supportedRegions: [
    'australiacentral'
    'australiaeast'
    'australiasoutheast'
    'brazilsouth'
    'canadacentral'
    'centralindia'
    'centralus'
    'eastasia'
    'eastus'
    'eastus2'
    'francecentral'
    'germanywestcentral'
    'italynorth'
    'japaneast'
    'koreacentral'
    'northcentralus'
    'northeurope'
    'norwayeast'
    'southafricanorth'
    'southcentralus'
    'southindia'
    'swedencentral'
    'switzerlandnorth'
    'uaenorth'
    'uksouth'
    'ukwest'
    'westeurope'
    'westus'
    'westus2'
  ]
  overrides: {
    westus3: 'westus2'
  }
  default: 'westus2'
}

@export()
@description('Based on an intended region, gets a supported region for API Management BasicV2 SKU.')
func getApimBasicV2Region(location string) string => getAdjustedRegion(location, apimBasicV2RegionMap)

// Content Safety available regions
// See: https://learn.microsoft.com/azure/ai-services/content-safety/overview
var contentSafetyRegionMap = {
  supportedRegions: [
    'australiaeast'
    'brazilsouth'
    'canadacentral'
    'centralindia'
    'eastus'
    'eastus2'
    'francecentral'
    'germanywestcentral'
    'japaneast'
    'koreacentral'
    'northcentralus'
    'norwayeast'
    'southafricanorth'
    'southcentralus'
    'southindia'
    'swedencentral'
    'switzerlandnorth'
    'uaenorth'
    'uksouth'
    'westeurope'
    'westus'
    'westus2'
    'westus3'
  ]
  overrides: {
    centralus: 'eastus2'
    northeurope: 'westeurope'
    southeastasia: 'australiaeast'
    eastasia: 'australiaeast'
  }
  default: 'eastus2'
}

@export()
@description('Based on an intended region, gets a supported region for Content Safety.')
func getContentSafetyRegion(location string) string => getAdjustedRegion(location, contentSafetyRegionMap)
