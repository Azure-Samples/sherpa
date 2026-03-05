---
hide:
  - toc
---

# Camp 4: Monitoring & Telemetry

*Reaching Observation Peak*

![Monitoring](../../images/sherpa-monitoring.png)

!!! info "Camp Details"
    **Tech Stack:** Log Analytics, Application Insights, Azure Monitor, Workbooks, API Management, Container Apps, Functions, MCP  
    **Primary Risks:** [MCP08](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp08-telemetry/) (Lack of Audit and Telemetry)

### Welcome to Observation Peak!

You've made it to Camp 4, the last skill-building camp before the Summit! Throughout your journey, you've locked down authentication, put a gateway in front of your MCP servers, and added input validation and output sanitization. Your servers are now protected by multiple layers of defense.

But here's a question: **How do you know it's working?**

If an attacker probed your system last night, would you know? If your security function blocked 100 injection attempts yesterday, could you prove it to an auditor? If there's a sudden spike in attacks right now, would you be alerted?

This is where **observability** comes in, and it's just as important as the security controls themselves.

!!! quote "The Key Insight"
    Security controls without observability are like locks without security cameras. You might stop the intruder, but you'll never know they tried to get in.

---

## What You'll Build

By the end of Camp 4, every request will be logged, visualized, and alertable. Here's the complete architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                         MCP Client                              │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTPS Request
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     API Management (APIM)                       │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ LAYER 1: Prompt Shields (AI Content Safety)             │   │
│   │   • Scans for prompt injection attacks                  │   │
│   │   • Blocks jailbreak/manipulation attempts              │   │
│   │   • Logs via <trace> policy → AppTraces                 │   │
│   │     └── Properties.event_type (direct)                  │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   • Receives all MCP traffic                                    │
│   • Applies policies (auth, rate limiting)                      │
│   • Generates CorrelationId for tracing                         │
│   • Routes clean requests to security function                  │
│                                                                 │
│   Diagnostic Settings → Log Analytics                           │
│   └── GatewayLogs (HTTP details)                                │
│   └── GatewayLlmLogs (LLM usage)                                │
│   └── WebSocketConnectionLogs (WebSocket events)                │
└───────────────────────────────┬─────────────────────────────────┘
                                │ (if not blocked by Layer 1)
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Security Function (Layer 2)                  │
│   • Receives forwarded request + CorrelationId                  │
│   • Regex checks for SQL, path traversal, shell injection       │
│   • Scans for PII/credentials in responses                      │
│   • Logs structured events with custom dimensions               │
│                                                                 │
│   Application Insights SDK → AppTraces table                    │
│   └── Properties.custom_dimensions.event_type                   │
│   └── Properties.custom_dimensions.injection_type               │
│   └── Properties.custom_dimensions.correlation_id               │
└─────────────────────────────────────────────────────────────────┘
```

You'll wire up structured logging, build a security dashboard with Azure Workbooks, create alert rules that fire when attacks spike, and learn KQL to investigate incidents across services.

---

## Prerequisites

Before starting Camp 4, ensure you have:

:material-check: Azure subscription with Contributor access  
:material-check: Azure CLI installed and logged in (`az login`)  
:material-check: Azure Developer CLI installed (`azd auth login`)  
:material-check: Docker installed and running (for Container Apps deployment)  
:material-check: Completed Camp 3: I/O Security (recommended, but not required)

:material-arrow-right: [Full prerequisites guide](../../prerequisites.md) with installation instructions for all tools.

---

## Getting Started

```bash
# Navigate to Camp 4
cd camps/camp4-monitoring

# Deploy infrastructure AND services (~15 minutes)
azd up
```

This deploys an APIM gateway, security functions (v1 with basic logging, v2 with structured logging), a Log Analytics workspace, Application Insights, and the MCP server and Trail API on Container Apps.

!!! tip "Just want the full solution?"
    Skip the workshop and deploy everything at once — dashboards, alerts, and structured logging included. See [Production Deployment](production-deploy.md).

Once deployment completes, you're ready to start the workshop. Camp 4 follows the **hidden → visible → actionable** pattern — you'll explore what's already logging, make hidden events visible, then turn that visibility into dashboards and alerts.

Ready? Let's start by exploring what API Management is already logging.

[Start: Gateway Logging →](section1-apim-logging.md){ .md-button .md-button--primary }

---

← [Camp 3: I/O Security](../camp3-io-security.md) | [The Summit →](../summit.md)
