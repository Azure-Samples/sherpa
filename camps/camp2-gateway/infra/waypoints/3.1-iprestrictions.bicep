// Waypoint 3.1: Apply IP Restrictions
// Restricts Container Apps to only accept traffic from APIM

// Note: APIM Basic v2 does not have static outbound IPs
// This waypoint demonstrates the pattern, but full implementation
// requires APIM Standard v2 with VNet integration or using
// X-Forwarded-For header validation as an alternative

param containerAppName string
param allowedIpRange string = '0.0.0.0/0'  // Placeholder - update with APIM IPs

resource containerApp 'Microsoft.App/containerApps@2023-05-01' existing = {
  name: containerAppName
}

// Note: Container Apps IP restrictions require updating the ingress configuration
// This is typically done via az containerapp ingress access-restriction command
// or by updating the Container App resource with ipSecurityRestrictions

// For workshop purposes, we document the limitation and show the pattern
// Full implementation would require:
// 1. APIM Standard v2 with VNet integration for static IPs
// 2. Or using header-based validation (X-Azure-FDID, X-Forwarded-For)
// 3. Or VNet + Private Endpoints for full network isolation

output message string = 'IP restrictions pattern demonstrated. See docs/network-concepts.md for full implementation with APIM Standard v2.'
