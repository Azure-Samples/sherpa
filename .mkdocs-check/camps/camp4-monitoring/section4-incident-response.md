---
hide:
  - toc
---

<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">Camp 4 · Attack Simulation</div>
      <h1>Incident Response</h1>
      <p>Simulate a multi-vector attack and trace it across your entire observability system.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">crisis_alert</span></span>
    </div>
  </div>
</div>

You've built the monitoring system. Now put it under pressure. This section simulates a realistic multi-vector attack so you can watch your dashboard light up, trace the attack across services, and verify your alerts fire.

## 4.1 Simulate Multi-Vector Attack

??? warning "Attack Simulation"

    Run the attack simulation:

    === "Bash"
        ```bash
        ./scripts/section4/4.1-simulate-attack.sh
        ```

    === "PowerShell"
        ```powershell
        ./scripts/section4/4.1-simulate-attack.ps1
        ```

    The script sends attacks in phases: reconnaissance, SQL injection, path traversal, shell injection, and prompt injection. It outputs correlation IDs you can use to trace each attack.

    **Now open your dashboard.** Go to the Azure Portal → your resource group → the Workbook you deployed in Section 3. Refresh and watch:

    - **MCP Request Volume** spikes as attack traffic arrives
    - **Attacks by Injection Type** breaks down exactly what was thrown at your server
    - **Recent Security Events** shows each blocked request with its correlation ID

    This is everything you built — APIM logging, structured detection, and dashboards — working together in real time.

    !!! tip "Alerts take longer"
        The "High Attack Volume" alert evaluates on a 5-minute window. Give it 5–10 minutes, then check your email (if you configured a notification in Section 3).

    **Trace an attack across services:**

    Copy a correlation ID from the script output and run this in Log Analytics:

    ```kusto
    let id = "PASTE-CORRELATION-ID";
    union
        (ApiManagementGatewayLogs | where CorrelationId == id
         | project TimeGenerated, Source="APIM", CorrelationId,
                  Details=strcat("HTTP ", ResponseCode, " from ", CallerIpAddress)),
        (AppTraces | where Properties has id
         | extend CustomDims = parse_json(replace_string(replace_string(
             tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
         | where tostring(CustomDims.correlation_id) == id
         | project TimeGenerated, Source="Function", CorrelationId=id,
                  Details=strcat(tostring(CustomDims.event_type), ": ", tostring(CustomDims.injection_type)))
    | order by TimeGenerated asc
    ```

    This reconstructs the full story of a single request across APIM and the security function. See the [KQL Query Reference](reference.md#kql-query-reference) for more investigation queries.

---

## Cleanup

When you're done with the workshop:

=== "Bash"
    ```bash
    # Remove all Azure resources
    azd down --force --purge

    # Clean up Entra ID app registrations (ignore errors if already deleted)
    az ad app delete --id $(azd env get-value MCP_APP_CLIENT_ID)
    az ad app delete --id $(azd env get-value APIM_CLIENT_APP_ID)
    ```

=== "PowerShell"
    ```powershell
    # Remove all Azure resources
    azd down --force --purge

    # Clean up Entra ID app registrations (ignore errors if already deleted)
    $MCP_ID = azd env get-value MCP_APP_CLIENT_ID
    $APIM_ID = azd env get-value APIM_CLIENT_APP_ID
    az ad app delete --id $MCP_ID
    az ad app delete --id $APIM_ID
    ```

---

## Congratulations!

You've completed Camp 4 and reached **Observation Peak**! Here's how far you've come:

| Before | After |
|--------|-------|
| APIM routed traffic silently | Every request logged with caller IP, timing, correlation |
| No AI-based attack detection | Layer 1 (Prompt Shields) blocks prompt injection at the edge |
| Function logged basic warnings | Structured events with custom dimensions and correlation IDs |
| No way to see attack patterns | Real-time dashboard showing all attack categories |
| Manual log checking | Automated alerts notify you of threats |

The **hidden → visible → actionable** pattern applies beyond monitoring: whenever you deploy something new, ask yourself, "If this breaks at 3 AM, how will I know?"

Your MCP servers are now **authenticated**, **protected**, **validated**, and **observable**. One more climb to go!
