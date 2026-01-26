@description('Name of the workbook')
param name string

@description('Location for the workbook')
param location string

@description('Tags for the resource')
param tags object

@description('Log Analytics Workspace ID to link the workbook to')
param logAnalyticsWorkspaceId string

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
        json: '# MCP Security Monitoring Dashboard\n\nReal-time visibility into security events from the MCP Security Function. Use this dashboard to monitor blocked attacks, PII redactions, and credential exposures.'
      }
      name: 'title'
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
    // Panel 1: Security Events Over Time
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend EventType = tostring(Properties.event_type)
| where EventType in ('INJECTION_BLOCKED', 'PII_REDACTED', 'CREDENTIAL_DETECTED')
| summarize Count=count() by bin(TimeGenerated, 5m), EventType
| render timechart
'''
        size: 0
        title: 'Security Events Over Time'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'timechart'
        chartSettings: {
          seriesLabelSettings: [
            { seriesName: 'INJECTION_BLOCKED', color: 'red' }
            { seriesName: 'PII_REDACTED', color: 'blue' }
            { seriesName: 'CREDENTIAL_DETECTED', color: 'orange' }
          ]
        }
      }
      name: 'securityEventsTimechart'
    }
    // Panel 2: Blocked Attacks by Category (Pie Chart)
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend EventType = tostring(Properties.event_type)
| where EventType == 'INJECTION_BLOCKED'
| extend Category = tostring(Properties.category)
| summarize Count=count() by Category
| render piechart
'''
        size: 1
        title: 'Blocked Attacks by Category'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'piechart'
      }
      customWidth: '50'
      name: 'attacksByCategory'
    }
    // Panel 3: PII Redaction Summary (Stat Tiles)
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend EventType = tostring(Properties.event_type)
| where EventType == 'PII_REDACTED'
| extend EntityCount = toint(Properties.entity_count)
| summarize
    TotalEvents = count(),
    TotalEntities = sum(EntityCount)
| project
    strcat('📊 PII Events: ', TotalEvents),
    strcat('🔒 Entities Redacted: ', TotalEntities)
'''
        size: 3
        title: 'PII Redaction Summary'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'tiles'
        tileSettings: {
          showBorder: true
        }
      }
      customWidth: '50'
      name: 'piiSummary'
    }
    // Panel 4: Attack Trends by Tool
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend EventType = tostring(Properties.event_type)
| where EventType == 'INJECTION_BLOCKED'
| extend ToolName = tostring(Properties.tool_name)
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
| extend EventType = tostring(Properties.event_type)
| where EventType in ('INJECTION_BLOCKED', 'PII_REDACTED', 'CREDENTIAL_DETECTED', 'SECURITY_ERROR')
| extend
    Category = tostring(Properties.category),
    CorrelationId = tostring(Properties.correlation_id),
    Severity = tostring(Properties.severity)
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
                  { operator: '==', thresholdValue: 'ERROR', representation: 'red', text: '{0}{1}' }
                  { operator: '==', thresholdValue: 'WARNING', representation: 'orange', text: '{0}{1}' }
                  { operator: 'Default', representation: 'green', text: '{0}{1}' }
                ]
              }
            }
          ]
        }
      }
      name: 'recentEvents'
    }
    // Panel 6: Error Rate
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
AppTraces
| where TimeGenerated >= {TimeRange:start} and TimeGenerated <= {TimeRange:end}
| extend EventType = tostring(Properties.event_type)
| where EventType == 'SECURITY_ERROR'
| summarize ErrorCount=count() by bin(TimeGenerated, 5m)
| render timechart
'''
        size: 0
        title: 'Security Function Error Rate'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'timechart'
        chartSettings: {
          seriesLabelSettings: [
            { seriesName: 'ErrorCount', color: 'red' }
          ]
        }
      }
      name: 'errorRate'
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
