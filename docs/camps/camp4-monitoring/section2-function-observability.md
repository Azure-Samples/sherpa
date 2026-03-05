---
hide:
  - toc
---

# Section 2: Function Observability

*Switch from basic logging to structured telemetry*

← [Gateway Logging](section1-apim-logging.md)

---

APIM logs show HTTP traffic, but the security function's internal operations (what attacks were blocked, what PII was found) are still invisible. This section upgrades from basic logging to structured telemetry.

## Two-Layer Blocking Architecture

Attacks are blocked at two layers, and each logs to a different property path. KQL queries need to check **both** locations to capture all attack types:

| Attack Type | Blocked By | Log Location |
|-------------|-----------|--------------|
| **Prompt injection** | Layer 1 (APIM/Prompt Shields) | `Properties.event_type` |
| **SQL injection** | Layer 2 (Security Function) | `Properties.custom_dimensions.event_type` |
| **Path traversal** | Layer 2 (Security Function) | `Properties.custom_dimensions.event_type` |
| **Shell injection** | Layer 2 (Security Function) | `Properties.custom_dimensions.event_type` |

## The Problem: Basic Logging Is Invisible

Most developers start with basic logging:

```python
logging.warning(f"Injection blocked: {category}")
```

This produces a log line like:
```
2024-01-15 14:30:00 WARNING Injection blocked: sql_injection
```

Simple and readable, but not useful for security analysis at scale:

- **You can't query it** — Want to count SQL injections vs. shell injections? You'd need fragile regex parsing.
- **You can't correlate it** — Which APIM request triggered this log? No correlation ID to link them.
- **You can't aggregate it** — How many attacks per hour? Per tool? Per source IP? Each question requires custom text parsing.

The solution is **structured logging**: emitting events as key-value pairs (dimensions) rather than formatted strings. You'll see this in action in step 2.2.

## 2.1 See Basic Logging Limitations

???+ abstract "Experience Unstructured Logs"

    Run the script to trigger security events:

    ```bash
    ./scripts/section2/2.1-exploit.sh
    ```

    **What you'll discover:**

    The script attempts to query `AppTraces` in Log Analytics, but with v1's basic `logging.warning()` calls, the table doesn't even exist! Basic Python logging writes to stdout/console—it doesn't automatically flow to Application Insights as structured, queryable data.

    This is the core problem: **security events are happening, but they're invisible to your monitoring tools.**

    :material-close: No `AppTraces` table to query  
    :material-close: No correlation IDs linking to APIM logs  
    :material-close: No way to build dashboards or alerts  
    :material-close: Logs exist only in function console output (if you know where to look)

## 2.2 Deploy Structured Logging

???+ success "Switch to v2 with Custom Dimensions"

    Switch APIM to use the pre-deployed v2 function and send test attacks:

    ```bash
    ./scripts/section2/2.2-fix.sh
    ```

    !!! tip "No Redeployment Required!"
        Both function versions were deployed during initial `azd up`. This script updates APIM's named value `function-app-url` to point to v2, then sends a few test attacks (SQL injection, path traversal, shell injection) to generate structured log entries for the next step.

    **What changes:**

    ```python
    # v1 (basic): Hard to query
    logging.warning(f"Injection blocked: {category}")

    # v2 (structured): Rich, queryable events
    log_injection_blocked(
        injection_type=result.category,
        reason=result.reason,
        correlation_id=correlation_id,
        tool_name=tool_name
    )
    ```

    **Custom dimensions now available:**

    | Dimension | Example Value | Why It Matters |
    |-----------|---------------|----------------|
    | `event_type` | `INJECTION_BLOCKED` | Filter by event category |
    | `injection_type` | `sql_injection` | Know exactly what was blocked |
    | `correlation_id` | `abc-123-xyz` | Trace across APIM + Function |
    | `tool_name` | `search-trails` | Identify targeted tools |

    !!! info "What Are Custom Dimensions?"
        When you log with Azure Monitor/Application Insights, you can attach **custom dimensions**—arbitrary key-value pairs that become queryable fields. Think of them as adding columns to your log database that you can filter, group, and aggregate. See the [Reference](reference.md#custom-dimensions) for the full list.

    !!! info "How Correlation IDs Flow Through the System"
        When a request arrives at APIM, it's assigned a unique `RequestId` (accessible via `context.RequestId` in policies). This ID appears as `CorrelationId` in APIM's gateway logs.

        For end-to-end tracing, APIM must **explicitly pass** this ID to backend services. In our security function calls, the policy includes:

        ```xml
        <set-header name="x-correlation-id" exists-action="override">
            <value>@(context.RequestId.ToString())</value>
        </set-header>
        ```

        The security function extracts this header (or generates its own if missing) and includes it in every log event.

## 2.3 Validate Structured Logs

???+ success "Query Security Events"

    !!! warning "Wait for Log Ingestion"
        The test attacks from step 2.2 need 2-5 minutes to appear in Log Analytics. If you see "No structured logs found yet," wait a few minutes and try again.

    Run the validation script:

    ```bash
    ./scripts/section2/2.3-validate.sh
    ```

    **Try it yourself** — open Log Analytics in the Azure portal and run this query to count attacks by type:

    ```kusto
    AppTraces
    | where Properties has "event_type"
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | extend EventType = tostring(CustomDims.event_type),
             InjectionType = tostring(CustomDims.injection_type)
    | where EventType == "INJECTION_BLOCKED"
    | summarize Count=count() by InjectionType
    | order by Count desc
    ```

    The `parse_json(replace_string(...))` pattern normalizes Python's single-quoted JSON into valid JSON for KQL. You'll see this pattern throughout the workshop.

    !!! note "More KQL Queries"
        The [KQL Query Reference](reference.md#kql-query-reference) has additional queries including recent events with details, most targeted tools, end-to-end correlation tracing, and unified queries that span both Layer 1 and Layer 2 logs.

---

You now have structured, queryable security events flowing to Application Insights. Time to make them *actionable* with dashboards and alerts.

[Next: Dashboards & Alerts →](section3-dashboards-alerts.md){ .md-button .md-button--primary }

---

← [Gateway Logging](section1-apim-logging.md) | [Dashboards & Alerts →](section3-dashboards-alerts.md)
