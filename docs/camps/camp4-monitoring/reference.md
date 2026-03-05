---
hide:
  - toc
---

# Camp 4: Reference

*KQL primer, architecture deep dive, troubleshooting, and query cookbook*

← [Camp 4 Overview](index.md)

---

## Understanding Observability

| Aspect | Basic Logging | Observability |
|--------|---------------|---------------|
| **What it captures** | Text messages | Structured events with dimensions |
| **How you search** | Grep through files | Query across services in seconds |
| **Correlation** | Manual, painful | Automatic via correlation IDs |
| **Visualization** | Read log files | Dashboards, charts, trends |
| **Alerting** | Custom scripts | Built-in threshold monitoring |

The difference matters: `WARNING: Injection blocked: sql_injection` tells you something happened. A structured event with `event_type`, `injection_type`, `tool_name`, `correlation_id`, and `caller_ip` tells you *everything*, and lets you query, aggregate, and alert on it automatically.

---

## Meet Azure Monitor

Camp 4 uses four Azure Monitor components:

| Component | Role |
|-----------|------|
| **Log Analytics Workspace** | Central log repository — you query it with KQL |
| **Application Insights** | App monitoring — auto-captures requests, exceptions, and traces from your Functions |
| **Azure Workbooks** | Interactive dashboards combining text, KQL queries, and visualizations |
| **Azure Monitor Alerts** | Rules that trigger notifications when conditions are met |

### How Logs Flow

Camp 4 has a **two-layer security architecture**. Both layers stream telemetry to the same Log Analytics workspace:

| Layer | Source | Log Destination | What It Catches |
|-------|--------|----------------|----------------|
| **Layer 1** | APIM + Prompt Shields | `ApiManagementGatewayLogs` + `AppTraces` (via `<trace>` policy) | Prompt injection (AI-based) |
| **Layer 2** | Security Function | `AppTraces` (via App Insights SDK) | SQL injection, path traversal, shell injection, PII, credentials |

!!! info "Two Log Formats for Security Events"
    - **Layer 1 (APIM)**: Logs to `Properties.event_type` directly
    - **Layer 2 (Function)**: Logs to `Properties.custom_dimensions.event_type`
    
    Dashboard queries use `coalesce()` to handle both formats transparently.

!!! info "The 2-5 Minute Delay"
    Logs don't appear instantly in Log Analytics. Azure buffers and batches them for efficiency, resulting in a 2-5 minute ingestion delay. This is normal! When validating your setup, give it a few minutes before panicking.

### Unified Telemetry

All four services (APIM, security function v1/v2, MCP server, trail API) report to a **single shared Application Insights** instance. This gives you a single pane of glass — KQL queries can join telemetry across services, and alerts span the entire system.

!!! tip "Correlation IDs"
    Use the `x-correlation-id` header (based on APIM's RequestId) to trace requests across services in your KQL queries.

!!! note "Production Sampling Consideration"
    This workshop uses **100% sampling** for complete visibility during learning. In production environments, consider reducing the sampling percentage to optimize costs while maintaining representative telemetry. You can configure this in the Application Insights resource or in the Bicep infrastructure.

---

## A Quick KQL Primer

Throughout this workshop, you'll write queries in **KQL (Kusto Query Language)**. If you've never used it, don't worry, it's quite intuitive once you see a few examples.

### KQL Basics

KQL queries flow from left to right using the pipe (`|`) operator, similar to Unix commands:

```kusto
TableName
| where SomeColumn == "value"      // Filter rows
| project Column1, Column2         // Select columns
| summarize count() by Column1     // Aggregate
| order by count_ desc             // Sort
| limit 10                         // Take top N
```

### Essential Operators

| Operator | Purpose | Example |
|----------|---------|---------|
| `where` | Filter rows | `where ResponseCode >= 400` |
| `project` | Select/rename columns | `project TimeGenerated, CallerIpAddress` |
| `extend` | Add computed columns | `extend Duration = DurationMs/1000` |
| `summarize` | Aggregate | `summarize count() by ToolName` |
| `order by` | Sort | `order by TimeGenerated desc` |
| `limit` / `take` | Return N rows | `limit 20` |
| `render` | Visualize | `render timechart` |

### Working with Custom Dimensions

The security function logs custom dimensions using Azure Monitor OpenTelemetry. These are stored in `Properties.custom_dimensions` as a Python dict string (with single quotes). To query them, you need to convert to JSON and parse:

```kusto
AppTraces
| where Properties has "event_type"
| extend CustomDims = parse_json(
    replace_string(
        replace_string(
            tostring(Properties.custom_dimensions),
            "'", "\""
        ),
        "None", "null"
    ))
| extend EventType = tostring(CustomDims.event_type)
| where EventType == "INJECTION_BLOCKED"
```

!!! warning "Why the Complex Parsing?"
    Azure Monitor OpenTelemetry for Python stores custom dimensions as a Python dict string, not JSON. This means:
    
    - Single quotes instead of double quotes: `{'key': 'value'}` vs `{"key": "value"}`
    - `None` instead of `null`
    - `True`/`False` instead of `true`/`false`
    
    The `replace_string()` calls convert to valid JSON before `parse_json()` can work.

!!! info "Two Log Sources for Security Events"
    Security events come from **two different sources** with slightly different formats:
    
    **Layer 1 (APIM/Prompt Shields)** - Logged via `<trace>` policy:
    ```kusto
    // Properties are at the root level
    | extend EventType = tostring(Properties.event_type)
    | extend Category = tostring(Properties.category)
    ```
    
    **Layer 2 (Security Function)** - Logged via OpenTelemetry:
    ```kusto
    // Properties are nested in custom_dimensions as Python dict string
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | extend EventType = tostring(CustomDims.event_type)
    ```
    
    **Unified query** (handles both layers):
    ```kusto
    | extend Props = parse_json(Properties)
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
    | extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
    ```

!!! tip "Pre-filter for Performance"
    Always use `| where Properties has "event_type"` before the parsing step. This filters at the storage level and dramatically improves query performance.

### Time Filters

KQL has built-in time functions:

```kusto
| where TimeGenerated > ago(1h)     // Last hour
| where TimeGenerated > ago(7d)     // Last 7 days
| where TimeGenerated between (datetime(2024-01-01) .. datetime(2024-01-31))
```

---

## Key Log Tables

This workshop focuses on these Azure Monitor log tables for MCP security monitoring:

| Log Table | APIM Category | Key Fields |
|-----------|---------------|------------|
| **ApiManagementGatewayLogs** | GatewayLogs | `CallerIpAddress`, `ResponseCode`, `CorrelationId`, `Url`, `Method`, `ApiId` |
| **ApiManagementGatewayLlmLog** | GatewayLlmLogs | `PromptTokens`, `CompletionTokens`, `ModelName`, `CorrelationId` |
| **AppTraces** | (App Insights) | `Message`, `SeverityLevel`, custom dimensions (`event_type`, `correlation_id`, `injection_type`) |

!!! note "MCP Protocol-Level Logging"
    Azure is developing MCP-specific logging capabilities that will capture tool names, session IDs, and client information at the protocol level. Until generally available, `GatewayLogs` captures HTTP-level MCP traffic, and `AppTraces` captures security function events including tool names extracted from JSON-RPC payloads.

## Custom Dimensions

When you log with Azure Monitor/Application Insights, you can attach **custom dimensions**—arbitrary key-value pairs that become queryable fields.

In the `Properties` column of `AppTraces`, you'll find:

| Dimension | Example | Query Use |
|-----------|---------|-----------|
| `event_type` | `INJECTION_BLOCKED` | Filter security events |
| `injection_type` | `sql_injection` | Breakdown by attack category |
| `correlation_id` | `abc-123-xyz` | Cross-service tracing |
| `tool_name` | `search-trails` | Identify targeted tools |
| `severity` | `WARNING` | Filter by importance |

Think of custom dimensions as adding columns to your log database that you can filter, group, and aggregate.

---

## KQL Query Reference

This section is your **cheat sheet**—a collection of queries you'll use regularly for security monitoring.

Each query is designed to answer a specific question. Copy them into Log Analytics and modify as needed.

!!! info "Common Parse Pattern"
    Most queries below use the same boilerplate to handle both Layer 1 (APIM) and Layer 2 (Function) log formats:
    ```kusto
    | extend Props = parse_json(Properties)
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
    | extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
    ```
    See [Working with Custom Dimensions](#working-with-custom-dimensions) for why this is necessary.

!!! tip "Running KQL Queries"
    To run these queries:
    
    1. Go to the Azure Portal → Log Analytics workspace
    2. Click **Logs** in the left menu
    3. Paste the query and click **Run**
    
    You can also save frequently-used queries for quick access.

### Security Events Summary

```kusto
// Unified query that captures events from both Layer 1 (APIM) and Layer 2 (Function)
AppTraces
| where Properties has "event_type"
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(
    tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
| where EventType in ('INJECTION_BLOCKED', 'PII_REDACTED', 'CREDENTIAL_DETECTED')
| summarize Count=count() by EventType
| render piechart
```

### Attacks by Category

```kusto
// Shows all attack types including prompt_injection (Layer 1) and sql/path/shell (Layer 2)
AppTraces
| where Properties has "event_type"
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(
    tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
| where EventType == 'INJECTION_BLOCKED'
| extend Category = coalesce(tostring(Props.category), tostring(CustomDims.category))
| summarize Count=count() by Category
| order by Count desc
```

### Attack Trends Over Time

```kusto
AppTraces
| where Properties has "event_type"
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(
    tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
| where EventType == 'INJECTION_BLOCKED'
| summarize Count=count() by bin(TimeGenerated, 5m)
| render timechart
```

### Most Targeted MCP Tools

```kusto
AppTraces
| where Properties has "event_type"
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(
    tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
| where EventType == 'INJECTION_BLOCKED'
| extend ToolName = coalesce(tostring(Props.tool_name), tostring(CustomDims.tool_name))
| where isnotempty(ToolName)
| summarize Count=count() by ToolName
| top 10 by Count desc
```

### Trace a Single Request

```kusto
// Replace with an actual correlation ID from your logs
let correlation_id = "YOUR-CORRELATION-ID";
AppTraces
| where Properties has "correlation_id"
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(
    tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend CorrelationId = coalesce(tostring(Props.correlation_id), tostring(CustomDims.correlation_id))
| where CorrelationId == correlation_id
| project TimeGenerated, Message, Props, CustomDims
| order by TimeGenerated asc
```

### Full Log Correlation (Incident Response)

Use CorrelationId to trace a request across ALL log tables:

```kusto
// Cross-service investigation using CorrelationId
let correlationId = "YOUR-CORRELATION-ID";
let timeRange = ago(24h);
// APIM HTTP logs
ApiManagementGatewayLogs
| where TimeGenerated > timeRange
| where CorrelationId == correlationId
| project TimeGenerated, Source="APIM-HTTP", CallerIpAddress, ResponseCode
| union (
    // Security logs (both Layer 1 and Layer 2)
    AppTraces
    | where TimeGenerated > timeRange
    | where Properties has "correlation_id"
    | extend Props = parse_json(Properties)
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
    | extend CorrelId = coalesce(tostring(Props.correlation_id), tostring(CustomDims.correlation_id))
    | where CorrelId == correlationId
    | extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
    | extend Source = iff(isnotempty(tostring(Props.event_type)), "Layer1-APIM", "Layer2-Function")
    | project TimeGenerated, Source, EventType, Message
)
| order by TimeGenerated asc
```

### Suspicious Client Analysis

```kusto
// Find clients with high attack rates using APIM gateway logs
ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| where ApiId contains "mcp" or ApiId contains "sherpa"
| where ResponseCode >= 400
| summarize ErrorCount=count() by CallerIpAddress
| where ErrorCount > 10
| order by ErrorCount desc
```

### MCP Tool Risk Assessment

```kusto
// Which tools are most frequently targeted? (unified query)
AppTraces
| where TimeGenerated > ago(7d)
| where Properties has "event_type"
| extend Props = parse_json(Properties)
| extend CustomDims = parse_json(replace_string(replace_string(
    tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
| extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type)),
         ToolName = coalesce(tostring(Props.tool_name), tostring(CustomDims.tool_name))
| where EventType == "INJECTION_BLOCKED" and isnotempty(ToolName)
| summarize AttackAttempts=count() by ToolName
| order by AttackAttempts desc
```

### Cross-Service Queries (Unified Telemetry)

These queries leverage the shared Application Insights instance where all services report telemetry.

!!! info "Log Analytics Table Names"
    When querying from **Log Analytics workspace**, use these table names:
    
    - `AppRequests` (not `requests`)
    - `AppDependencies` (not `dependencies`)
    - `AppTraces` (not `traces`)
    
    Column names also differ: `TimeGenerated` (not `timestamp`), `AppRoleName` (not `cloud_RoleName`), `Success` (not `success`), `DurationMs` (not `duration`).

!!! note "Service Instrumentation"
    All services in this workshop have OpenTelemetry instrumentation configured:
    
    - **APIM, funcv1, funcv2**: Auto-instrumented, appear in `AppRequests`
    - **trail-api**: FastAPI instrumentation, appears in `AppRequests` when receiving HTTP traffic
    - **sherpa-mcp-server**: OpenTelemetry configured, appears in `AppTraces` (MCP uses **Streamable HTTP** transport, which supports both single JSON responses and SSE streaming for longer operations. APIM proxies these requests to the backend MCP server.)
    
    The queries below union data from both `AppRequests` and `AppTraces` to give a complete picture across all services.

#### Service Health Overview

```kusto
// Request counts and error rates by service (including MCP servers via AppTraces)
let httpServices = AppRequests
| where TimeGenerated > ago(1h)
| summarize 
    total = count(),
    failed = countif(Success == false),
    avg_duration_ms = avg(DurationMs)
  by AppRoleName
| extend error_rate = round(failed * 100.0 / total, 2);
let mcpServices = AppTraces
| where TimeGenerated > ago(1h)
| where AppRoleName == "sherpa-mcp-server"
| where Message startswith "get_weather" or Message startswith "check_trail" or Message startswith "get_gear"
| summarize total = count() by AppRoleName
| extend failed = 0, avg_duration_ms = 0.0, error_rate = 0.0;
union httpServices, mcpServices
| project AppRoleName, total, failed, error_rate, avg_duration_ms
| order by total desc
```

#### Security Function Performance

```kusto
// Security function endpoint performance
AppRequests
| where AppRoleName contains "func"
| where TimeGenerated > ago(1h)
| summarize 
    avg_duration = avg(DurationMs),
    p95_duration = percentile(DurationMs, 95),
    success_rate = round(countif(Success == true) * 100.0 / count(), 2),
    request_count = count()
  by Name
| order by request_count desc
```

#### MCP Tool Performance (Custom Spans)

```kusto
// MCP tool invocations from sherpa-mcp-server
AppTraces
| where TimeGenerated > ago(24h)
| where AppRoleName == "sherpa-mcp-server"
| where Message startswith "get_weather" or Message startswith "check_trail" or Message startswith "get_gear"
| extend tool = case(
    Message startswith "get_weather", "get_weather",
    Message startswith "check_trail", "check_trail_conditions",
    Message startswith "get_gear", "get_gear_recommendations",
    "unknown")
| extend location = extract("location=([^,]+)", 1, Message)
| summarize call_count = count() by tool
| order by call_count desc
```

#### MCP Tool Usage Patterns

```kusto
// MCP tool parameter analysis from sherpa-mcp-server
AppTraces
| where TimeGenerated > ago(24h)
| where AppRoleName == "sherpa-mcp-server"
| where Message startswith "get_weather" or Message startswith "check_trail" or Message startswith "get_gear"
| extend tool = case(
    Message startswith "get_weather", "get_weather",
    Message startswith "check_trail", "check_trail_conditions",
    Message startswith "get_gear", "get_gear_recommendations",
    "unknown")
| extend location = extract("location=([^\"\\)]+)", 1, Message),
         trail_id = extract("trail_id=([^\"\\)]+)", 1, Message),
         conditions = extract("conditions=([^\"\\)]+)", 1, Message)
| project TimeGenerated, tool, location, trail_id, conditions
| where isnotempty(location) or isnotempty(trail_id) or isnotempty(conditions)
```

#### Slowest Requests Across All Services

```kusto
// Top 20 slowest requests across all services
AppRequests
| where TimeGenerated > ago(1h)
| where Success == true
| top 20 by DurationMs desc
| project 
    TimeGenerated,
    service = AppRoleName,
    Name,
    duration_ms = round(DurationMs, 2),
    ResultCode
```

#### All Services Activity Summary

```kusto
// Activity summary across all services
let httpActivity = AppRequests
| where TimeGenerated > ago(1h)
| summarize 
    request_count = count(),
    avg_duration_ms = round(avg(DurationMs), 2)
  by AppRoleName;
let mcpActivity = AppTraces
| where TimeGenerated > ago(1h)
| where AppRoleName == "sherpa-mcp-server"
| where Message startswith "get_weather" or Message startswith "check_trail" or Message startswith "get_gear"
| summarize request_count = count() by AppRoleName
| extend avg_duration_ms = 0.0;  // Duration not tracked in current logging
union httpActivity, mcpActivity
| order by request_count desc
```

---

## Architecture Deep Dive

### The Security Event Types

Security events come from two layers, each with specific event types:

#### Layer 1 Events (APIM/Prompt Shields)

| Event Type | When Emitted | What to Do |
|------------|--------------|------------|
| `INJECTION_BLOCKED` (prompt) | AI-based prompt injection detected | Investigate intent, may be attack reconnaissance |

Layer 1 logs are at `Properties.event_type` directly.

#### Layer 2 Events (Security Function)

| Event Type | When Emitted | Severity | What to Do |
|------------|--------------|----------|------------|
| `INJECTION_BLOCKED` (sql/path/shell) | Regex pattern detected in input | WARNING | Investigate source, consider blocking IP |
| `PII_REDACTED` | Personal data found and masked in output | INFO | Normal operation, audit trail |
| `CREDENTIAL_DETECTED` | API keys/tokens found in output | ERROR | Immediate investigation, possible breach |
| `INPUT_CHECK_PASSED` | Request passed all security checks | DEBUG | Normal operation |
| `SECURITY_ERROR` | Security function itself failed | ERROR | Check function health, review logs |

Layer 2 logs are at `Properties.custom_dimensions.event_type`.

### Log Table Relationships

The tables connect via `CorrelationId`. The key difference between Layer 1 and Layer 2 logs is where properties are stored:

- **Layer 1 (APIM)**: Properties at root level — `Properties.event_type`
- **Layer 2 (Function)**: Properties nested in `custom_dimensions` as a Python dict string — requires `parse_json(replace_string(...))`

Dashboard queries use `coalesce()` to handle both formats transparently.

### Outbound Policy Considerations

APIM outbound policies can inspect and modify responses, but there's an important limitation with streaming responses:

| Response Type | `context.Response.Body.As<string>()` | Outbound Policy Safe? |
|---------------|--------------------------------------|----------------------|
| Single JSON | ✅ Returns complete body | ✅ Yes |
| SSE Stream | ⚠️ May timeout or return partial data | ⚠️ Unreliable |

**Why the workshop's outbound sanitization works:**

The sherpa-mcp-server returns **single JSON responses** for its simple tools. The connection closes after the complete response, so APIM can buffer and inspect the body.

```xml
<!-- This works because sherpa-mcp-server returns complete JSON responses -->
<set-body>@(context.Response.Body.As<string>(preserveContent: true))</set-body>
```

!!! warning "If Your MCP Server Returns SSE Streams"
    If you modify the MCP server to return SSE streams (for long-running operations or progress updates), the outbound policy will:
    
    - **Timeout** waiting for the stream to complete
    - **Get partial data** if the stream takes longer than the policy timeout
    - **Block streaming** if `buffer-response="true"` is set
    
    For streaming MCP servers, move security validation to:
    
    1. **Inbound policies** (validate input before forwarding)
    2. **The MCP server itself** (sanitize before streaming)

---

## Troubleshooting

Things don't always work the first time. Here are the most common issues and how to fix them.

???+ question "My KQL queries return no results"

    **Don't panic!** This is the #1 issue people hit. Check these things in order:

    1. **Wait 2-5 minutes.** Logs don't appear instantly. If you just enabled diagnostics or deployed the function, grab a coffee and try again.

    2. **Check your time range.** The default in Log Analytics might be "Last 24 hours", if you just deployed, try "Last 1 hour" or "Last 30 minutes".

    3. **Verify diagnostic settings exist:**
       ```bash
       az monitor diagnostic-settings list \
         --resource "/subscriptions/.../providers/Microsoft.ApiManagement/service/YOUR-APIM" \
         --query "[].name"
       ```

    4. **Verify Application Insights is connected:**
       ```bash
       az functionapp config appsettings list \
         --name $FUNCTION_APP_NAME \
         --resource-group $AZURE_RESOURCE_GROUP \
         --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']"
       ```

    5. **Generate some events!** Run the exploit scripts to create log entries, then wait a few minutes.

???+ question "The dashboard shows 'No data'"

    **Workbooks need data to display.** If panels are empty:

    1. **Adjust the time range** at the top of the workbook to a wider window (try "Last 7 days")
    
    2. **Generate events** by running:
       ```bash
       ./scripts/section4/4.1-simulate-attack.sh
       ```
    
    3. **Wait for ingestion** (2-5 minutes), then refresh the workbook

    4. **Check the workspace connection** - Make sure the workbook is querying the right Log Analytics workspace

???+ question "Alerts aren't firing even though I see events"

    **Alerts run on a schedule, not in real-time:**

    1. **Alert evaluation interval**: Default is every 5 minutes. Wait at least 10 minutes after generating events.

    2. **Check thresholds**: The "High Attack Volume" alert requires >10 attacks in 5 minutes. Did you generate enough events?

    3. **Verify the alert is enabled**:
       - Azure Portal → Monitor → Alerts → Alert rules
       - Check that your rules show "Enabled"

    4. **Check action group**: Even if the alert fires, notifications need a properly configured action group with valid email/webhook.

???+ question "Properties.event_type returns nothing but I see the data"

    **This depends on which layer emitted the log:**
    
    - **Layer 1 (APIM/Prompt Shields)**: Properties are stored directly
    - **Layer 2 (Security Function)**: Properties are stored in `custom_dimensions` as a Python dict string
    
    **For Layer 1 logs** (prompt injection):
    ```kusto
    | extend EventType = tostring(Properties.event_type)  // ✓ Works for APIM traces
    ```
    
    **For Layer 2 logs** (SQL, path, shell injection):
    ```kusto
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | extend EventType = tostring(CustomDims.event_type)  // ✓ Works for Function logs
    ```
    
    **For unified queries** (handles both layers):
    ```kusto
    | extend Props = parse_json(Properties)
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Props.custom_dimensions), "'", "\""), "None", "null"))
    | extend EventType = coalesce(tostring(Props.event_type), tostring(CustomDims.event_type))
    | where EventType == "INJECTION_BLOCKED"  // ✓ Matches both layers
    ```

    Check what's actually in Properties:
    ```kusto
    AppTraces 
    | where Properties has "event_type"
    | take 5 
    | project Properties
    ```

    Layer 1 logs will show `event_type` directly:
    ```json
    {"event_type": "INJECTION_BLOCKED", "category": "prompt_injection", ...}
    ```
    
    Layer 2 logs will show it nested with single quotes:
    ```json
    {"custom_dimensions": "{'event_type': 'INJECTION_BLOCKED', ...}"}
    ```

???+ question "I'm seeing 'Request rate is large' errors"

    **You might be hitting rate limits.** This happens if you:
    
    - Run attack simulations too fast
    - Have multiple people using the same deployment
    
    Solution: Wait a few minutes, or add delays between requests in your scripts.

---

← [Camp 4 Overview](index.md)
