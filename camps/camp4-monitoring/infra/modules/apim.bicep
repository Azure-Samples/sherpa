param name string
param location string
param tags object
param publisherEmail string
param publisherName string
param managedIdentityId string
param managedIdentityClientId string
param apimClientAppId string = ''
param tenantId string
param mcpAppClientId string = ''

@description('Content Safety endpoint for Prompt Shields policy fragment')
param contentSafetyEndpoint string = ''

@description('Application Insights resource ID for APIM logger')
param appInsightsId string

@description('Application Insights instrumentation key for APIM logger')
param appInsightsInstrumentationKey string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Named value for managed identity client ID (used in policies)
resource namedValueIdentityClientId 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'managed-identity-client-id'
  properties: {
    displayName: 'managed-identity-client-id'
    value: managedIdentityClientId
    secret: false
  }
}

// Named value for APIM client app ID (used in Credential Manager policy)
// Only created if the value is provided (set by preprovision hook)
resource namedValueApimClientId 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = if (!empty(apimClientAppId)) {
  parent: apim
  name: 'apim-client-app-id'
  properties: {
    displayName: 'apim-client-app-id'
    value: apimClientAppId
    secret: false
  }
}

// Named value for APIM Gateway URL
resource namedValueGatewayUrl 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'apim-gateway-url'
  properties: {
    displayName: 'apim-gateway-url'
    value: apim.properties.gatewayUrl
    secret: false
  }
}

// Named value for tenant ID (used in OAuth policies)
resource namedValueTenantId 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'tenant-id'
  properties: {
    displayName: 'tenant-id'
    value: tenantId
    secret: false
  }
}

// Named value for MCP app client ID (used in OAuth policies)
// Only created if the value is provided (set by preprovision hook)
resource namedValueMcpAppClientId 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = if (!empty(mcpAppClientId)) {
  parent: apim
  name: 'mcp-app-client-id'
  properties: {
    displayName: 'mcp-app-client-id'
    value: mcpAppClientId
    secret: false
  }
}

// Named value for Content Safety endpoint (used in policy fragments)
// Only created if the value is provided
resource namedValueContentSafety 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = if (!empty(contentSafetyEndpoint)) {
  parent: apim
  name: 'content-safety-endpoint'
  properties: {
    displayName: 'content-safety-endpoint'
    value: contentSafetyEndpoint
    secret: false
  }
}

// APIM Logger for Application Insights (enables unified telemetry & distributed tracing)
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apim
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    isBuffered: true
    resourceId: appInsightsId
  }
}

// APIM Diagnostics - API-level logging with 100% sampling for workshop visibility
// Note: In production, consider lowering sampling percentage for cost optimization
resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2024-06-01-preview' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    loggerId: apimLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100  // 100% for workshop - adjust for production
    }
    frontend: {
      request: {
        headers: ['traceparent', 'tracestate', 'x-correlation-id']
        body: { bytes: 8192 }
      }
      response: {
        headers: ['traceparent', 'tracestate']
        body: { bytes: 8192 }
      }
    }
    backend: {
      request: {
        headers: ['traceparent', 'tracestate', 'x-correlation-id']
        body: { bytes: 8192 }
      }
      response: {
        headers: ['traceparent', 'tracestate']
        body: { bytes: 8192 }
      }
    }
    // Enable correlation for distributed tracing
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: true
    operationNameFormat: 'Url'
  }
}

// Azure Monitor Logger - enables logging to Log Analytics via diagnostic settings
// This logger is automatically created by Azure when you enable diagnostic settings,
// but we configure it explicitly to ensure proper logging configuration
resource azureMonitorLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apim
  name: 'azuremonitor'
  properties: {
    loggerType: 'azureMonitor'
    isBuffered: true
  }
}

// Azure Monitor Diagnostics - enables GatewayLogs to flow to Log Analytics
// CRITICAL: Without this, diagnostic settings route logs but APIM doesn't emit them
// This is what actually populates ApiManagementGatewayLogs table
resource azureMonitorDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2024-06-01-preview' = {
  parent: apim
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    loggerId: azureMonitorLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100  // 100% for workshop - adjust for production
    }
    frontend: {
      request: {
        headers: ['x-correlation-id', 'traceparent']
        body: { bytes: 8192 }
      }
      response: {
        headers: ['traceparent']
        body: { bytes: 8192 }
      }
    }
    backend: {
      request: {
        headers: ['x-correlation-id', 'traceparent']
        body: { bytes: 8192 }
      }
      response: {
        headers: ['traceparent']
        body: { bytes: 8192 }
      }
    }
    logClientIp: true
  }
}

output id string = apim.id
output name string = apim.name
output gatewayUrl string = apim.properties.gatewayUrl
output managementUrl string = apim.properties.managementApiUrl
