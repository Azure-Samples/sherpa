# Camp 4: Monitoring & Telemetry

> **📚 Workshop Guide:** For the full step-by-step workshop, visit: **[Camp 4: Monitoring & Telemetry](https://azure-samples.github.io/sherpa/camps/camp4-monitoring/)**

---

Implement security monitoring for MCP servers using Azure Monitor, structured logging, dashboards, and intelligent alerting to detect and respond to threats in real-time.

## Overview

| | |
|---|---|
| **Difficulty** | Advanced |
| **Prerequisites** | Azure subscription, Camp 3 recommended |
| **Tech Stack** | Python, MCP, Azure Functions, Azure Monitor, Log Analytics, Application Insights |

## What You'll Learn

- Implement structured logging with custom dimensions for security events
- Configure Azure Monitor OpenTelemetry for Application Insights
- Enable unified telemetry across APIM, MCP Server, Functions, and REST APIs
- Build security monitoring dashboards with Azure Workbooks
- Create alert rules for injection attacks and credential exposure
- Query security events with KQL (Kusto Query Language)

## OWASP MCP Risks Addressed

| Risk | Description | Camp 4 Solution |
|------|-------------|-----------------|
| [MCP-08](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp08-logging/) | Lack of Audit and Telemetry | Structured logging + dashboards + alerts |

## Quick Start

```bash
cd camps/camp4-monitoring
azd up
```

Then follow the **[Workshop Guide](https://azure-samples.github.io/sherpa/camps/camp4-monitoring/)** for the hidden → visible → actionable walkthrough.

## Architecture

Camp 4 uses a **single shared Application Insights** instance for all services, enabling unified telemetry, KQL queries, and end-to-end transaction tracing.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MCP Client Request                             │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           API Management (APIM)                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  W3C Trace Context: traceparent + tracestate headers propagated    │    │
│  │  APIM Logger → Application Insights (100% sampling)                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            ▼                      ▼                      ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────────────────┐
│  Security Function│  │  Sherpa MCP Server│  │         Trail API             │
│  (Layer 2 checks) │  │  (Container App)  │  │       (Container App)         │
│                   │  │                   │  │                               │
│  • input_check    │  │  • get_weather    │  │  • /trails                    │
│  • sanitize_output│  │  • check_trail    │  │  • /permits                   │
│  + telemetry      │  │  • get_gear       │  │  • /permits/{id}/holder (PII) │
│                   │  │  + telemetry      │  │  + telemetry                  │
└─────────┬─────────┘  └─────────┬─────────┘  └──────────────┬────────────────┘
          │                      │                           │
          └──────────────────────┼───────────────────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Shared Application Insights                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │  KQL Queries    │  │  Transaction    │  │    Security Dashboard       │  │
│  │  (All services) │  │  Search         │  │    (Azure Workbook)         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘  │
│                                                                             │
│  + Log Analytics Workspace (KQL queries, 30-day retention)                  │
│  + Alert Rules (injection rate, credential exposure)                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Unified Telemetry Benefits

All services report to a single Application Insights instance, enabling:

- **Single pane of glass**: Query logs from APIM, MCP Server, Functions, and Trail API in one place
- **KQL across services**: Write queries that join telemetry from multiple services
- **Correlation IDs**: Trace requests across services using `x-correlation-id` header
- **Consistent alerting**: Create alerts that span the entire system

> **Note on Sampling:** This workshop uses 100% sampling for complete visibility during learning. In production, consider reducing sampling percentage to optimize costs while maintaining representative telemetry.

## Security Event Types

| Event Type | Description |
|------------|-------------|
| `INJECTION_BLOCKED` | Input validation blocked malicious request |
| `PII_REDACTED` | PII was detected and redacted from output |
| `CREDENTIAL_DETECTED` | Credentials were detected and redacted |
| `SECURITY_ERROR` | Security function encountered an error |

## Project Structure

```
camps/camp4-monitoring/
├── azure.yaml                 # azd configuration (deploys both function versions)
├── infra/                     # Bicep infrastructure
│   ├── main.bicep             # Deploys v1 and v2 Function Apps
│   ├── modules/
│   │   ├── app-insights.bicep # Shared Application Insights
│   │   ├── apim.bicep         # APIM with logger & diagnostics
│   │   ├── container-apps.bicep # MCP Server + Trail API
│   │   └── function-app.bicep # Security Function (parameterized)
│   └── policies/              # APIM policies with W3C trace propagation
├── security-function-v1/      # Basic logging (initially active)
│   └── function_app.py        # Uses logging.warning()
├── security-function-v2/      # Structured logging (workshop switches to this)
│   ├── function_app.py
│   └── shared/
│       └── security_logger.py # Azure Monitor OpenTelemetry
├── servers/
│   ├── sherpa-mcp-server/     # MCP Server with OpenTelemetry
│   └── trail-api/             # REST API with OpenTelemetry
└── scripts/                   # Workshop scripts
```

## Workshop Flow

Both function versions are deployed from the start. The workshop demonstrates the "hidden → visible → actionable" pattern by switching APIM's backend URL:

| Phase | State | Function | How |
|-------|-------|----------|-----|
| Initial | Hidden | v1 (basic logging) | `azd up` deploys both, APIM points to v1 |
| Section 2.2 | Visible | v2 (structured logging) | Script updates APIM named value |
| Section 3-4 | Actionable | v2 | Add dashboards and alerts |

This approach eliminates redeployment wait times during the workshop.

## Telemetry Dependencies

All services use `azure-monitor-opentelemetry` for consistent telemetry:

| Service | Package | Purpose |
|---------|---------|---------|
| Security Function | `azure-monitor-opentelemetry` | Structured logging, custom dimensions |
| Trail API | `azure-monitor-opentelemetry`, `opentelemetry-instrumentation-fastapi` | Auto-instrumentation, request tracing |
| Sherpa MCP Server | `azure-monitor-opentelemetry` | Custom spans for MCP tool calls |

## Cleanup

```bash
azd down --force --purge
```

## Next Steps

🏔️ **Congratulations!** You've reached the summit. Your MCP servers are now secure, monitored, and observable.

- Review the **[Summit page](https://azure-samples.github.io/sherpa/camps/summit/)** for a recap of your journey
- Apply these patterns to your own MCP deployments
