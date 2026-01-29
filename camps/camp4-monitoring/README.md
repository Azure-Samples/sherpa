# Camp 4: Monitoring & Telemetry

> **📚 Workshop Guide:** For the full step-by-step workshop, visit: **[Camp 4: Monitoring & Telemetry](https://azure-samples.github.io/sherpa/camps/camp4-monitoring/)**

---

Implement security monitoring for MCP servers using Azure Monitor, structured logging, dashboards, and intelligent alerting to detect and respond to threats in real-time.

## Overview

| | |
|---|---|
| **Difficulty** | Advanced |
| **Prerequisites** | Azure subscription, Camp 3 recommended |
| **Tech Stack** | Python, MCP, Azure Functions, Azure Monitor, Log Analytics |

## What You'll Learn

- Implement structured logging with custom dimensions for security events
- Configure Azure Monitor OpenTelemetry for Application Insights
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

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Function                        │
│  ┌─────────────────┐         ┌─────────────────┐            │
│  │  input_check    │         │ sanitize_output │            │
│  │  + telemetry    │         │  + telemetry    │            │
│  └────────┬────────┘         └────────┬────────┘            │
│           └──────────┬────────────────┘                     │
└──────────────────────┼──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Azure Monitor                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Application │  │   Azure     │  │   Alert     │          │
│  │  Insights   │  │  Workbook   │  │   Rules     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

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
├── azure.yaml                 # azd configuration
├── infra/                     # Bicep infrastructure
│   ├── main.bicep
│   ├── modules/
│   └── workbooks/             # Dashboard definitions
├── security-function/         # Azure Function with telemetry
│   ├── function_app.py
│   └── shared/
│       └── telemetry.py       # Structured logging module
└── scripts/                   # Workshop scripts
```

## Cleanup

```bash
azd down --force --purge
```

## Next Steps

🏔️ **Congratulations!** You've reached the summit. Your MCP servers are now secure, monitored, and observable.

- Review the **[Summit page](https://azure-samples.github.io/sherpa/camps/summit/)** for a recap of your journey
- Apply these patterns to your own MCP deployments
