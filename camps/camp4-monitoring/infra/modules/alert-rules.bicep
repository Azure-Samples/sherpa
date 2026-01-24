@description('Name prefix for alert rules')
param namePrefix string

@description('Location for the alert rules')
param location string

@description('Tags for the resources')
param tags object

@description('Log Analytics Workspace ID to query')
param logAnalyticsWorkspaceId string

@description('Action Group ID for alert notifications')
param actionGroupId string

// Alert 1: High Injection Attack Rate
// Fires when more than 10 injection attacks are blocked in 5 minutes
resource highInjectionRateAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${namePrefix}-high-injection-rate'
  location: location
  tags: tags
  properties: {
    displayName: 'High Injection Attack Rate'
    description: 'Alert when more than 10 injection attacks are blocked in 5 minutes. This may indicate an active attack or compromised client.'
    severity: 0 // Critical
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      logAnalyticsWorkspaceId
    ]
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
AppTraces
| extend EventType = tostring(Properties.event_type)
| where EventType == 'INJECTION_BLOCKED'
| summarize Count = count()
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 10
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
      customProperties: {
        AlertCategory: 'Security'
        RiskType: 'InjectionAttack'
      }
    }
    autoMitigate: true
  }
}

// Alert 2: Unusual PII Detection Rate
// Fires when more than 50 PII entities are redacted in 15 minutes
resource unusualPiiRateAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${namePrefix}-unusual-pii-rate'
  location: location
  tags: tags
  properties: {
    displayName: 'Unusual PII Detection Rate'
    description: 'Alert when more than 50 PII entities are detected in 15 minutes. This may indicate data exfiltration attempt or system misconfiguration.'
    severity: 2 // Warning
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      logAnalyticsWorkspaceId
    ]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
AppTraces
| extend EventType = tostring(Properties.event_type)
| where EventType == 'PII_REDACTED'
| extend EntityCount = toint(Properties.entity_count)
| summarize TotalEntities = sum(EntityCount)
'''
          timeAggregation: 'Total'
          metricMeasureColumn: 'TotalEntities'
          operator: 'GreaterThan'
          threshold: 50
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
      customProperties: {
        AlertCategory: 'Security'
        RiskType: 'DataExfiltration'
      }
    }
    autoMitigate: true
  }
}

// Alert 3: Security Function Errors
// Fires when more than 3 errors occur in 5 minutes
resource securityErrorsAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${namePrefix}-security-errors'
  location: location
  tags: tags
  properties: {
    displayName: 'Security Function Errors'
    description: 'Alert when more than 3 security function errors occur in 5 minutes. This may indicate service degradation or misconfiguration.'
    severity: 2 // Warning
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      logAnalyticsWorkspaceId
    ]
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
AppTraces
| extend EventType = tostring(Properties.event_type)
| where EventType == 'SECURITY_ERROR'
| summarize Count = count()
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 3
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
      customProperties: {
        AlertCategory: 'Operations'
        RiskType: 'ServiceDegradation'
      }
    }
    autoMitigate: true
  }
}

// Alert 4: Credential Exposure
// Fires immediately when any credential is detected (threshold > 0)
resource credentialExposureAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${namePrefix}-credential-exposure'
  location: location
  tags: tags
  properties: {
    displayName: 'Credential Exposure Detected'
    description: 'Alert when any credentials are detected in MCP responses. Immediate investigation required as this may indicate secret leakage.'
    severity: 0 // Critical
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      logAnalyticsWorkspaceId
    ]
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
AppTraces
| extend EventType = tostring(Properties.event_type)
| where EventType == 'CREDENTIAL_DETECTED'
| summarize Count = count()
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
      customProperties: {
        AlertCategory: 'Security'
        RiskType: 'CredentialExposure'
      }
    }
    autoMitigate: true
  }
}

output highInjectionRateAlertId string = highInjectionRateAlert.id
output unusualPiiRateAlertId string = unusualPiiRateAlert.id
output securityErrorsAlertId string = securityErrorsAlert.id
output credentialExposureAlertId string = credentialExposureAlert.id
