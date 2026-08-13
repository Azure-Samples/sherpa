// Waypoint 1.4: Register remote MCP servers in API Center

param apiCenterName string
param apimGatewayUrl string
param apimResourceId string
param currentUserObjectId string

var workspaceName = 'default'
var environmentName = 'camp2-apim'
var versionName = 'v1-0-0'
var definitionName = 'streamable-http'
var repositoryUrl = 'https://github.com/Azure-Samples/sherpa'
var issuesUrl = '${repositoryUrl}/issues'
var workshopDocsUrl = '${repositoryUrl}/tree/main/docs/camps/camp2-gateway'
var dataReaderRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'c7244dfb-f447-457d-b2ba-3999044d1706'
)

resource apiCenter 'Microsoft.ApiCenter/services@2024-06-01-preview' existing = {
  name: apiCenterName
}

resource defaultWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-06-01-preview' existing = {
  parent: apiCenter
  name: workspaceName
}

resource securityClassificationMetadata 'Microsoft.ApiCenter/services/metadataSchemas@2024-06-01-preview' = {
  parent: apiCenter
  name: 'security-classification'
  properties: {
    assignedTo: [
      {
        entity: 'api'
        required: false
        deprecated: false
      }
    ]
    schema: '{"type":"string","title":"Security classification","description":"Security and data-handling classification for this asset."}'
  }
}

resource authenticationMetadata 'Microsoft.ApiCenter/services/metadataSchemas@2024-06-01-preview' = {
  parent: apiCenter
  name: 'authentication-requirements'
  properties: {
    assignedTo: [
      {
        entity: 'api'
        required: false
        deprecated: false
      }
    ]
    schema: '{"type":"string","title":"Authentication requirements","description":"Non-secret instructions describing the authentication required by this asset."}'
  }
}

resource transportMetadata 'Microsoft.ApiCenter/services/metadataSchemas@2024-06-01-preview' = {
  parent: apiCenter
  name: 'mcp-transport'
  properties: {
    assignedTo: [
      {
        entity: 'api'
        required: false
        deprecated: false
      }
    ]
    schema: '{"type":"string","title":"MCP transport","description":"Model Context Protocol transport exposed by this server."}'
  }
}

resource useCasesMetadata 'Microsoft.ApiCenter/services/metadataSchemas@2024-06-01-preview' = {
  parent: apiCenter
  name: 'use-cases'
  properties: {
    assignedTo: [
      {
        entity: 'api'
        required: false
        deprecated: false
      }
    ]
    schema: '{"type":"string","title":"Use cases","description":"Primary supported use cases for this asset."}'
  }
}

resource apimEnvironment 'Microsoft.ApiCenter/services/workspaces/environments@2024-06-01-preview' = {
  parent: defaultWorkspace
  name: environmentName
  properties: {
    title: 'Camp 2 APIM Gateway'
    kind: 'testing'
    description: 'Non-production workshop environment hosting the Camp 2 MCP servers behind Azure API Management.'
    server: {
      type: 'Azure API Management'
      managementPortalUri: [
        'https://portal.azure.com/#resource${apimResourceId}'
      ]
    }
    onboarding: {
      instructions: 'Authenticate with Microsoft Entra OAuth through the MCP protected-resource metadata endpoints. Trails MCP also requires an Ocp-Apim-Subscription-Key header supplied by the consumer.'
    }
  }
}

resource sherpaApi 'Microsoft.ApiCenter/services/workspaces/apis@2024-06-01-preview' = {
  parent: defaultWorkspace
  name: 'sherpa-mcp'
  properties: any({
    title: 'Sherpa MCP Server'
    summary: 'Weather forecasts, trail conditions, and gear recommendations for mountain adventures.'
    description: 'Remote MCP server providing weather data, trail status, and gear recommendations. It is exposed through Azure API Management and secured with Microsoft Entra OAuth.'
    kind: 'mcp'
    contacts: [
      {
        name: 'Azure-Samples/sherpa'
        url: issuesUrl
      }
    ]
    externalDocumentation: [
      {
        title: 'Source repository'
        description: 'Workshop source, issues, and contribution guidance.'
        url: repositoryUrl
      }
      {
        title: 'Camp 2 workshop guide'
        description: 'Gateway security and API governance workshop documentation.'
        url: workshopDocsUrl
      }
      {
        title: 'Model Context Protocol'
        description: 'Model Context Protocol specification and documentation.'
        url: 'https://modelcontextprotocol.io'
      }
    ]
    customProperties: {
      'security-classification': 'Workshop / non-production; authenticated access required; no sensitive data'
      'authentication-requirements': 'Microsoft Entra OAuth. The client discovers authorization through RFC 9728 protected-resource metadata at the APIM gateway.'
      'mcp-transport': 'Streamable HTTP'
      'use-cases': 'Weather forecasts; trail condition checks; gear recommendations'
    }
    useCases: [
      {
        name: 'Weather planning'
        description: 'Retrieve weather forecasts for mountain locations.'
      }
      {
        name: 'Trail safety'
        description: 'Check trail conditions, closures, and hazards.'
      }
      {
        name: 'Gear preparation'
        description: 'Get gear recommendations based on current conditions.'
      }
    ]
  })
}

resource sherpaVersion 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-06-01-preview' = {
  parent: sherpaApi
  name: versionName
  properties: {
    title: '1.0.0'
    lifecycleStage: 'preview'
  }
}

resource sherpaDefinition 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = {
  parent: sherpaVersion
  name: definitionName
  properties: {
    title: 'Streamable HTTP'
    description: 'Streamable HTTP definition for the Sherpa MCP Server.'
  }
}

resource sherpaDeployment 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-06-01-preview' = {
  parent: sherpaApi
  name: environmentName
  properties: {
    title: 'Sherpa MCP on Camp 2 APIM'
    description: 'Active non-production deployment of the Sherpa MCP Server through Azure API Management.'
    environmentId: '/workspaces/${workspaceName}/environments/${environmentName}'
    definitionId: '/workspaces/${workspaceName}/apis/${sherpaApi.name}/versions/${versionName}/definitions/${definitionName}'
    server: {
      runtimeUri: [
        '${apimGatewayUrl}/sherpa/mcp'
      ]
    }
    state: 'active'
  }
  dependsOn: [
    apimEnvironment
    sherpaDefinition
  ]
}

resource trailsApi 'Microsoft.ApiCenter/services/workspaces/apis@2024-06-01-preview' = {
  parent: defaultWorkspace
  name: 'trails-mcp'
  properties: any({
    title: 'Trails MCP Server'
    summary: 'Trail information, permit management, and hiking conditions.'
    description: 'Remote MCP server generated from the Trail REST API by Azure API Management. It requires Microsoft Entra OAuth and an APIM subscription key supplied by the consumer.'
    kind: 'mcp'
    contacts: [
      {
        name: 'Azure-Samples/sherpa'
        url: issuesUrl
      }
    ]
    externalDocumentation: [
      {
        title: 'Source repository'
        description: 'Workshop source, issues, and contribution guidance.'
        url: repositoryUrl
      }
      {
        title: 'Camp 2 workshop guide'
        description: 'Gateway security and API governance workshop documentation.'
        url: workshopDocsUrl
      }
      {
        title: 'Model Context Protocol'
        description: 'Model Context Protocol specification and documentation.'
        url: 'https://modelcontextprotocol.io'
      }
    ]
    customProperties: {
      'security-classification': 'Workshop / non-production; authenticated access required; no sensitive data'
      'authentication-requirements': 'Microsoft Entra OAuth plus an Ocp-Apim-Subscription-Key header. Credentials are configured by the consumer and are not stored in API Center.'
      'mcp-transport': 'Streamable HTTP'
      'use-cases': 'Trail discovery; condition and hazard checks; permit retrieval and requests'
    }
    useCases: [
      {
        name: 'Trail discovery'
        description: 'Browse available hiking trails and retrieve trail details.'
      }
      {
        name: 'Condition monitoring'
        description: 'Check current trail conditions and hazards.'
      }
      {
        name: 'Permit management'
        description: 'Retrieve and request trail permits.'
      }
    ]
  })
}

resource trailsVersion 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-06-01-preview' = {
  parent: trailsApi
  name: versionName
  properties: {
    title: '1.0.0'
    lifecycleStage: 'preview'
  }
}

resource trailsDefinition 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = {
  parent: trailsVersion
  name: definitionName
  properties: {
    title: 'Streamable HTTP'
    description: 'Streamable HTTP definition for the Trails MCP Server.'
  }
}

resource trailsDeployment 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-06-01-preview' = {
  parent: trailsApi
  name: environmentName
  properties: {
    title: 'Trails MCP on Camp 2 APIM'
    description: 'Active non-production deployment of the Trails MCP Server through Azure API Management.'
    environmentId: '/workspaces/${workspaceName}/environments/${environmentName}'
    definitionId: '/workspaces/${workspaceName}/apis/${trailsApi.name}/versions/${versionName}/definitions/${definitionName}'
    server: {
      runtimeUri: [
        '${apimGatewayUrl}/trails/mcp'
      ]
    }
    state: 'active'
  }
  dependsOn: [
    apimEnvironment
    trailsDefinition
  ]
}

resource dataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(apiCenter.id, currentUserObjectId, dataReaderRoleDefinitionId)
  scope: apiCenter
  properties: {
    roleDefinitionId: dataReaderRoleDefinitionId
    principalId: currentUserObjectId
    principalType: 'User'
  }
}

output mcpRegistryEndpoint string = 'https://${apiCenter.name}.data.${apiCenter.location}.azure-apicenter.ms/workspaces/${workspaceName}/v0.1/servers'
output sherpaMcpEndpoint string = sherpaDeployment.properties.server.runtimeUri[0]
output trailsMcpEndpoint string = trailsDeployment.properties.server.runtimeUri[0]
