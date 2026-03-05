---
hide:
  - toc
---

# Section 1: Gateway Logging

*Explore pre-configured diagnostics and validate logs flow*

← [Camp 4 Overview](index.md)

---

Every MCP reques, legitimate or malicious, passes through APIM. By default, APIM routes traffic but records nothing. In this workshop, the Bicep infrastructure pre-configures **diagnostic settings** that stream two log categories (`GatewayLogs` and `GatewayLlmLogs`) to your Log Analytics workspace, so you can query traffic immediately after `azd up`.

| Without Diagnostic Settings | With Diagnostic Settings (this workshop) |
|-----------------------------|------------------------------------------|
| Traffic routes normally | Traffic routes normally |
| No record of who called, what failed, or how long it took | Every request logged with caller IP, timing, response code, correlation ID |
| Incidents are invisible | Queryable via KQL → dashboards → alerts |

## 1.1 Explore APIM Gateway Logging

???+ abstract "Send Traffic and See Logs Flow"

    Run the script to send traffic through APIM and verify logging:

    ```bash
    ./scripts/section1/1.1-explore.sh
    ```

    **What this script does:**

    1. **Sends legitimate MCP requests** through APIM
    2. **Sends attack requests** (SQL injection, path traversal)
    3. **Verifies diagnostic settings** are configured
    4. **Shows sample KQL queries** you can run

    **What you'll see:**

    | Component | Status |
    |-----------|--------|
    | :material-check: APIM routes requests | Working |
    | :material-check: Security function blocks attacks | Working |
    | :material-check: Diagnostic settings configured | Pre-deployed via Bicep |
    | :material-check: Logs flowing to Log Analytics | Verified |

    !!! tip "Log Ingestion Delay"
        Azure Monitor has a 2-5 minute ingestion delay. The first logs from a new deployment may take 5-10 minutes to appear.

## 1.2 Verify Diagnostic Configuration

???+ success "Understand What's Configured"

    Examine the diagnostic settings:

    ```bash
    ./scripts/section1/1.2-verify.sh
    ```

    Shows the diagnostic settings deployed via Bicep, which log categories are enabled, and where they're sent. See the **Key Log Tables** below for the fields available in each table.

    !!! tip "Verify in Azure Portal"
        **APIM** → **Monitoring** → **Diagnostic settings** → **mcp-security-logs**

## 1.3 Validate Logs Appear

!!! warning "Wait for Log Ingestion"
    For new deployments, logs need 2-5 minutes to appear in Log Analytics. If you run this immediately after `azd up`, you may see "No HTTP logs found yet." Wait a few minutes and try again.

???+ success "Query APIM Logs"

    Verify logs are flowing:

    ```bash
    ./scripts/section1/1.3-validate.sh
    ```

    **HTTP traffic query (ApiManagementGatewayLogs):**

    ```kusto
    ApiManagementGatewayLogs
    | where TimeGenerated > ago(1h)
    | where ApiId contains "mcp" or ApiId contains "sherpa"
    | project TimeGenerated, CallerIpAddress, Method, Url, ResponseCode, ApiId
    | order by TimeGenerated desc
    | limit 20
    ```

    !!! tip "New to KQL?"
        KQL reads left-to-right with `|` pipes, like Unix commands. See the [KQL Primer](reference.md#a-quick-kql-primer) for a full introduction.

    !!! tip "Filtering by ApiId vs Url"
        Using `ApiId contains "mcp"` is more reliable than `Url contains "/mcp/"` because ApiId is a structured field set during API import/configuration, while Url parsing can be fragile.

---

## Key Log Tables

This section uses these Azure Monitor log tables:

| Log Table | APIM Category | Key Fields |
|-----------|---------------|------------|
| **ApiManagementGatewayLogs** | GatewayLogs | `CallerIpAddress`, `ResponseCode`, `CorrelationId`, `Url`, `Method`, `ApiId` |
| **ApiManagementGatewayLlmLog** | GatewayLlmLogs | `PromptTokens`, `CompletionTokens`, `ModelName`, `CorrelationId` |

The `CorrelationId` field appears in both tables — you'll use it in Section 4 to trace a single request across APIM and the security function.

---

Logs from API Management are now flowing. But the security function's internal operations (what attacks were blocked, what PII was found) are still invisible. Let's fix that.

[Next: Function Observability →](section2-function-observability.md){ .md-button .md-button--primary }

---

← [Overview & Deploy](index.md) | [Function Observability →](section2-function-observability.md)
