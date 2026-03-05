@description('Name of the workbook')
param name string

@description('Location for the workbook')
param location string

@description('Tags for the resource')
param tags object

@description('Log Analytics Workspace ID to link the workbook to')
param logAnalyticsWorkspaceId string

@description('Application Insights resource ID for Application Map link')
param appInsightsId string = ''

@description('Display name for the workbook')
param displayName string = 'MCP Security Dashboard'

// Generate a unique GUID for the workbook based on name and resource group
var workbookId = guid(resourceGroup().id, name)

// Workbook content with security monitoring panels
var workbookContent = {
  version: 'Notebook/1.0'
  items: [
    // Title and description
    {
      type: 1
      content: {
        json: '# MCP Security Monitoring Dashboard\n\nReal-time visibility into security events from the MCP Security Function. Use this dashboard to monitor blocked attacks, PII redactions, and credential exposures.\n\n## � Unified Telemetry\n\nAll services (APIM, MCP Server, Functions, Trail API) report to this shared Application Insights instance, enabling comprehensive security monitoring and cross-service queries.'
      }
      name: 'title'
    }
    // Telemetry Info Panel
    {
      type: 1
      content: {
        json: '### 🔍 Cross-Service Queries\n\nThis dashboard monitors security events from all services:\n\n1. **Security Function**: Injection blocking, PII redaction, credential detection\n2. **APIM Gateway**: Request logging, error rates, latency\n3. **MCP Server & Trail API**: Request tracing with OpenTelemetry\n\n> **Tip**: Use the `x-correlation-id` in KQL queries to trace requests across services.'
      }
      name: 'tracingInfo'
    }
    // Time range parameter
    {
      type: 9
      content: {
        version: 'KqlParameterItem/1.0'
        parameters: [
          {
            id: 'timeRange'
            version: 'KqlParameterItem/1.0'
            name: 'TimeRange'
            type: 4
            isRequired: true
            value: {
              durationMs: 3600000
            }
            typeSettings: {
              selectableValues: [
                { durationMs: 300000, displayText: 'Last 5 minutes' }
                { durationMs: 900000, displayText: 'Last 15 minutes' }
                { durationMs: 1800000, displayText: 'Last 30 minutes' }
                { durationMs: 3600000, displayText: 'Last hour' }
                { durationMs: 14400000, displayText: 'Last 4 hours' }
                { durationMs: 43200000, displayText: 'Last 12 hours' }
                { durationMs: 86400000, displayText: 'Last 24 hours' }
                { durationMs: 604800000, displayText: 'Last 7 days' }
              ]
            }
            label: 'Time Range'
          }
        ]
        style: 'pills'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'parameters'
    }
    // Panel 1: Security Summary Scorecards
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
let data = AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
| where EventType in ('INJECTION_BLOCKED', 'PII_REDACTED', 'CREDENTIAL_DETECTED', 'SECURITY_ERROR')
| summarize Count=count() by EventType;
datatable(EventType:string, SortOrder:int, Label:string)[
    'INJECTION_BLOCKED', 1, '🛡️ Injections Blocked',
    'PII_REDACTED', 2, '🔒 PII Redacted',
    'CREDENTIAL_DETECTED', 3, '⚠️ Credentials Detected',
    'SECURITY_ERROR', 4, '❌ Security Errors'
]
| join kind=leftouter data on EventType
| project Label, Count = coalesce(Count, 0), SortOrder
| order by SortOrder asc
'''
        size: 4
        title: 'Security Summary'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'tiles'
        tileSettings: {
          titleContent: {
            columnMatch: 'Label'
            formatter: 1
          }
          leftContent: {
            columnMatch: 'Count'
            formatter: 12
            formatOptions: {
              palette: 'auto'
            }
            numberFormat: {
              unit: 17
              options: {
                style: 'decimal'
                maximumFractionDigits: 0
              }
            }
          }
          showBorder: true
        }
      }
      name: 'securitySummary'
    }
    // Panel 2: Blocked Attacks by Category (Pie Chart)
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
| where EventType == 'INJECTION_BLOCKED'
| extend Category = coalesce(tostring(Props.category), tostring(CustomDims.category))
| summarize Count=count() by Category
| render piechart
'''
        size: 1
        title: 'Blocked Attacks by Category'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'piechart'
      }
      name: 'attacksByCategory'
    }
    // Panel 3: Attack Trends by Tool
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
| where EventType == 'INJECTION_BLOCKED'
| extend ToolName = coalesce(tostring(Props.tool_name), tostring(CustomDims.tool_name))
| where isnotempty(ToolName)
| summarize Count=count() by ToolName
| top 10 by Count desc
| render barchart
'''
        size: 0
        title: 'Attack Trends by MCP Tool'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'barchart'
      }
      name: 'attacksByTool'
    }
    // Panel 5: Recent Security Events (Table)
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
| where EventType in ('INJECTION_BLOCKED', 'PII_REDACTED', 'CREDENTIAL_DETECTED', 'SECURITY_ERROR')
| extend
    Category = coalesce(tostring(Props.category), tostring(CustomDims.category)),
    CorrelationId = coalesce(tostring(Props.correlation_id), tostring(CustomDims.correlation_id)),
    Severity = case(
        isnotnull(Props.severity), tostring(Props.severity),
        isnotnull(CustomDims.severity), tostring(CustomDims.severity),
        SeverityLevel == 4, 'CRITICAL',
        SeverityLevel == 3, 'ERROR',
        SeverityLevel == 2, 'WARNING',
        'INFO'
    )
| project TimeGenerated, EventType, Category, Severity, Message, CorrelationId
| order by TimeGenerated desc
| take 50
'''
        size: 0
        title: 'Recent Security Events'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'table'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'EventType'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'colors'
                thresholdsGrid: [
                  { operator: '==', thresholdValue: 'INJECTION_BLOCKED', representation: 'redBright', text: '{0}{1}' }
                  { operator: '==', thresholdValue: 'CREDENTIAL_DETECTED', representation: 'orange', text: '{0}{1}' }
                  { operator: '==', thresholdValue: 'PII_REDACTED', representation: 'blue', text: '{0}{1}' }
                  { operator: '==', thresholdValue: 'SECURITY_ERROR', representation: 'red', text: '{0}{1}' }
                  { operator: 'Default', representation: 'gray', text: '{0}{1}' }
                ]
              }
            }
            {
              columnMatch: 'Severity'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'colors'
                thresholdsGrid: [
                  { operator: '==', thresholdValue: 'CRITICAL', representation: 'redDark', text: '{0}{1}' }
                  { operator: '==', thresholdValue: 'ERROR', representation: 'red', text: '{0}{1}' }
                  { operator: '==', thresholdValue: 'WARNING', representation: 'orange', text: '{0}{1}' }
                  { operator: '==', thresholdValue: 'INFO', representation: 'blue', text: '{0}{1}' }
                  { operator: 'Default', representation: 'gray', text: '{0}{1}' }
                ]
              }
            }
          ]
        }
      }
      name: 'recentEvents'
    }
  ]
  isLocked: false
  fallbackResourceIds: [
    logAnalyticsWorkspaceId
  ]
}

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: workbookId
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: displayName
    category: 'workbook'
    version: '1.0'
    serializedData: string(workbookContent)
    sourceId: logAnalyticsWorkspaceId
  }
}

output id string = workbook.id
output name string = workbook.name
