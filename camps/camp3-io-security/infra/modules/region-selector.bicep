// Region Selector for Camp 2 Gateway
// Handles resource types that may not be available in all regions

func getAdjustedRegion(location string, map object) string =>
  map.?overrides[?location] ?? (contains(map.?supportedRegions ?? [], location) ? location : (map.?default ?? location))

// API Center available regions
// See: https://learn.microsoft.com/azure/api-center/overview
// Note: API Center has limited region availability - falls back to eastus for US West regions
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
  // Only override regions that need redirection to nearest supported region
  overrides: {
    northeurope: 'westeurope'
    southeastasia: 'australiaeast'
    eastasia: 'australiaeast'
  }
  default: 'eastus'  // Fallback for US regions not in supportedRegions
}

@export()
@description('Based on an intended region, gets a supported region for API Center.')
func getApiCenterRegion(location string) string => getAdjustedRegion(location, apiCenterRegionMap)

// API Management Basic v2 available regions
// See: https://learn.microsoft.com/azure/api-management/api-management-region-availability
// Note: BasicV2 SKU has wide availability - most regions supported
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
    'westus3'
  ]
  overrides: {}  // No overrides needed - wide region support
  default: 'eastus'
}

@export()
@description('Based on an intended region, gets a supported region for API Management BasicV2 SKU.')
func getApimBasicV2Region(location string) string => getAdjustedRegion(location, apimBasicV2RegionMap)

// Content Safety available regions
// See: https://learn.microsoft.com/azure/ai-services/content-safety/overview
// Content Safety available regions
// See: https://learn.microsoft.com/azure/ai-services/content-safety/overview
// Note: Content Safety has wide availability - most regions supported
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
  overrides: {}  // No overrides needed - wide region support
  default: 'eastus'
}

@export()
@description('Based on an intended region, gets a supported region for Content Safety.')
func getContentSafetyRegion(location string) string => getAdjustedRegion(location, contentSafetyRegionMap)
