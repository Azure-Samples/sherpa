# Camp 4: Monitoring & Telemetry

> **Looking for the workshop?** This README is a quick reference for the codebase. For the full step-by-step workshop guide, visit: **[Camp 4: Monitoring & Telemetry Workshop](https://azure-samples.github.io/sherpa/camps/camp4-monitoring/)**

---

> *"What you can't see, you can't protect"* - Comprehensive monitoring transforms security from reactive firefighting to proactive threat detection.

Implement comprehensive security monitoring for MCP servers using Azure Monitor, structured logging, dashboards, and intelligent alerting.

## Overview

- **Difficulty:** Advanced
- **Prerequisites:** Azure subscription, completed Camp 3 (recommended for context)
- **Tech Stack:** Python, MCP, Azure Functions, Azure Monitor, Log Analytics, Application Insights
- **Estimated Time:** 60 minutes

## Workshop Methodology

Camp 4 follows the **hidden -> visible -> actionable** pattern:

1. **Hidden**: Experience the lack of visibility with basic logging
2. **Visible**: Deploy structured telemetry and security dashboards
3. **Actionable**: Configure intelligent alert rules for security events

## What You'll Learn

- Implement structured logging with custom dimensions for security events
- Configure Azure Monitor OpenTelemetry for Application Insights
- Build security monitoring dashboards with Azure Workbooks
- Create alert rules for injection attacks, credential exposure, and errors
- Query security events with KQL (Kusto Query Language)

## OWASP MCP Risks Addressed

| Risk | Description | How We Address It |
|------|-------------|-------------------|
| MCP-08 | Lack of Audit and Telemetry | Structured logging with INJECTION_BLOCKED, PII_REDACTED, CREDENTIAL_DETECTED events |

## Quick Start

```bash
# Clone and navigate
cd camps/camp4-monitoring

# Deploy infrastructure (~15 minutes)
azd provision

# Follow the waypoint scripts

# Waypoint 1: Structured Logging
./scripts/1.1-show-visibility-gap.sh    # See lack of visibility
./scripts/1.2-deploy-function.sh        # Deploy telemetry-enabled function
./scripts/1.3-validate-telemetry.sh     # Query structured events

# Waypoint 2: Security Dashboard
./scripts/2.1-deploy-workbook.sh        # Deploy Azure Workbook
./scripts/2.2-generate-events.sh        # Generate security events
./scripts/2.3-view-dashboard.sh         # Open dashboard in browser

# Waypoint 3: Alert Rules
./scripts/3.1-deploy-alerts.sh          # Deploy alert rules
./scripts/3.2-trigger-alerts.sh         # Generate events to trigger alerts
./scripts/3.3-validate-alerts.sh        # Check alert status
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          APIM Gateway                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    Security Function                             │    │
│  │  ┌─────────────────┐         ┌─────────────────┐                │    │
│  │  │  input_check    │         │ sanitize_output │                │    │
│  │  │  ─────────────  │         │  ─────────────  │                │    │
│  │  │ • Injection     │         │ • PII Redaction │                │    │
│  │  │   Detection     │         │ • Credential    │                │    │
│  │  │ • Prompt Shield │         │   Scanning      │                │    │
│  │  └────────┬────────┘         └────────┬────────┘                │    │
│  │           │                           │                          │    │
│  │           └─────────┬─────────────────┘                          │    │
│  │                     │                                            │    │
│  │              ┌──────▼──────┐                                     │    │
│  │              │  Telemetry  │                                     │    │
│  │              │   Module    │                                     │    │
│  │              │  ─────────  │                                     │    │
│  │              │ Structured  │                                     │    │
│  │              │  Logging    │                                     │    │
│  │              └──────┬──────┘                                     │    │
│  └─────────────────────┼────────────────────────────────────────────┘    │
└────────────────────────┼─────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     Azure Monitor                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                  Application Insights                            │    │
│  │  ┌───────────────────────────────────────────────────────────┐  │    │
│  │  │  Custom Dimensions:                                        │  │    │
│  │  │  • event_type: INJECTION_BLOCKED, PII_REDACTED, ...       │  │    │
│  │  │  • category: shell_injection, sql_injection, ...           │  │    │
│  │  │  • correlation_id, tool_name, severity                     │  │    │
│  │  └───────────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                         │                                                │
│         ┌───────────────┼───────────────┐                               │
│         ▼               ▼               ▼                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                        │
│  │  Workbook  │  │   KQL      │  │   Alert    │                        │
│  │  Dashboard │  │  Queries   │  │   Rules    │                        │
│  └────────────┘  └────────────┘  └────────────┘                        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Security Event Types

| Event Type | Description | Severity |
|------------|-------------|----------|
| `INJECTION_BLOCKED` | Input validation blocked malicious request | WARNING |
| `PII_REDACTED` | PII was detected and redacted from output | INFO |
| `CREDENTIAL_DETECTED` | Credentials were detected and redacted | WARNING |
| `INPUT_CHECK_PASSED` | Request passed all security validations | INFO |
| `SECURITY_ERROR` | Security function encountered an error | ERROR |

## Alert Rules

| Alert | Threshold | Severity |
|-------|-----------|----------|
| High Injection Attack Rate | >10 blocked in 5min | Critical |
| Unusual PII Detection Rate | >50 entities in 15min | Warning |
| Security Function Errors | >3 in 5min | Warning |
| Credential Exposure | >0 detected | Critical |

## KQL Query Examples

### Security Events Summary
```kusto
AppTraces
| extend EventType = tostring(Properties.event_type)
| where EventType in ('INJECTION_BLOCKED', 'PII_REDACTED', 'CREDENTIAL_DETECTED')
| summarize Count=count() by EventType
| render piechart
```

### Blocked Attacks Over Time
```kusto
AppTraces
| extend EventType = tostring(Properties.event_type)
| where EventType == 'INJECTION_BLOCKED'
| summarize Count=count() by bin(TimeGenerated, 5m)
| render timechart
```

### Attacks by Category
```kusto
AppTraces
| extend EventType = tostring(Properties.event_type)
| where EventType == 'INJECTION_BLOCKED'
| extend Category = tostring(Properties.category)
| summarize Count=count() by Category
| order by Count desc
```

## Waypoint Summary

### Waypoint 1: Structured Logging

| Script | Description |
|--------|-------------|
| `1.1-show-visibility-gap.sh` | Generate events, show lack of visibility |
| `1.2-deploy-function.sh` | Deploy function with OpenTelemetry |
| `1.3-validate-telemetry.sh` | Query Log Analytics for structured events |

### Waypoint 2: Security Dashboard

| Script | Description |
|--------|-------------|
| `2.1-deploy-workbook.sh` | Deploy Azure Workbook dashboard |
| `2.2-generate-events.sh` | Generate mix of security events |
| `2.3-view-dashboard.sh` | Open dashboard in browser |

### Waypoint 3: Alert Rules

| Script | Description |
|--------|-------------|
| `3.1-deploy-alerts.sh` | Deploy alert rules (optional: `--email your@email.com`) |
| `3.2-trigger-alerts.sh` | Generate events to exceed thresholds |
| `3.3-validate-alerts.sh` | Check alert firing status |

## Project Structure

```
camps/camp4-monitoring/
├── azure.yaml                      # azd configuration
├── README.md
├── infra/
│   ├── main.bicep                  # Main infrastructure
│   ├── modules/
│   │   ├── workbook.bicep          # Azure Workbook (Dashboard)
│   │   ├── action-group.bicep      # Alert action group
│   │   ├── alert-rules.bicep       # Scheduled query alert rules
│   │   └── ...                     # Other modules
│   ├── workbooks/
│   │   └── mcp-security-dashboard.json  # Dashboard definition
│   └── waypoints/
│       └── 3.1-deploy-alerts.bicep # Alert deployment waypoint
├── security-function/
│   ├── function_app.py             # Endpoints with telemetry
│   ├── shared/
│   │   ├── telemetry.py            # Structured logging module
│   │   ├── injection_patterns.py
│   │   ├── pii_detector.py
│   │   └── credential_scanner.py
│   └── requirements.txt            # Includes OpenTelemetry
└── scripts/
    ├── 1.1-show-visibility-gap.sh
    ├── 1.2-deploy-function.sh
    ├── 1.3-validate-telemetry.sh
    ├── 2.1-deploy-workbook.sh
    ├── 2.2-generate-events.sh
    ├── 2.3-view-dashboard.sh
    ├── 3.1-deploy-alerts.sh
    ├── 3.2-trigger-alerts.sh
    └── 3.3-validate-alerts.sh
```

## Resources Deployed

| Resource | SKU | Purpose | Est. Cost |
|----------|-----|---------|-----------|
| Application Insights | Pay-as-you-go | Telemetry collection | ~$2.30/GB ingested |
| Log Analytics | PerGB2018 | Query and storage | ~$2.76/GB |
| Azure Workbook | Free | Dashboard | Free |
| Alert Rules | Free | Scheduled queries | Free (up to 100 rules) |
| Azure Function | Consumption | Security function | ~$0.20/1M executions |

## Troubleshooting

### Events not appearing in Log Analytics

- Events take 2-5 minutes to appear after generation
- Verify `APPLICATIONINSIGHTS_CONNECTION_STRING` is set in function app settings
- Check function app logs for telemetry configuration errors

### Workbook shows "No data"

- Verify time range is set appropriately (try "Last 1 hour")
- Run `2.2-generate-events.sh` to generate events
- Wait 2-5 minutes for events to propagate

### Alerts not firing

- Alert evaluation runs every 5 minutes
- Check event counts in Log Analytics against thresholds
- Verify alert rules are enabled with `3.3-validate-alerts.sh`

### KQL query errors

- Ensure `Properties.event_type` exists (structured logging deployed)
- Use `tostring()` to cast JSON properties for comparison

## Cleanup

```bash
# Remove all Azure resources
azd down --force --purge

# Clean up Entra ID app (optional)
az ad app delete --id $(azd env get-value MCP_APP_CLIENT_ID)
```

## Next Steps

After completing Camp 4, you have a fully observable MCP security deployment:

- **Real-time visibility** into security events
- **Dashboards** for monitoring attack patterns
- **Alerts** for immediate notification of threats

🏔️ **You've reached the summit!** Your MCP servers are now secure, monitored, and observable.
