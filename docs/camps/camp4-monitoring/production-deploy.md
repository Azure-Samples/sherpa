---
title: Deploy the Full MCP Observability Stack
description: "Provision Camp 4's complete observability stack (diagnostics, structured logging, dashboards, and alerts) in a single azd command with DEPLOY_MODE=complete."
keywords: Microsoft, azd deploy, DEPLOY_MODE, Bicep, observability stack, structured logging, Azure Monitor
hide:
  - toc
---

<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">Camp 4 · Production</div>
      <h1>Production Deployment</h1>
      <p>Deploy the fully-configured observability stack in one command.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">rocket_launch</span></span>
    </div>
  </div>
</div>

## Skip the Workshop, Deploy Everything

Throughout Camp 4, you built observability step by step: enabling diagnostics, switching to structured logging, deploying a dashboard, and creating alert rules. That's great for learning — but what if you just want the end result?

![Camp 4 all-in-one production deployment](../../images/camp4_allinone.png){ .center width=720 }

The **complete deployment mode** deploys the entire Camp 4 stack in a single `azd up`, including:

| Component | Workshop Mode (default) | Complete Mode |
|-----------|------------------------|---------------|
| APIM + Diagnostic Settings | +mdi:check+ Deployed | +mdi:check+ Deployed |
| Security Function v1 (basic logging) | +mdi:check+ **Active** | +mdi:check+ Deployed |
| Security Function v2 (structured logging) | +mdi:check+ Deployed | +mdi:check+ **Active** |
| MCP Server + Trail API | +mdi:check+ Deployed | +mdi:check+ Deployed |
| Security Dashboard (Workbook) | +mdi:close+ Manual (Section 3) | +mdi:check+ Deployed |
| Alert Rules + Action Group | +mdi:close+ Manual (Section 3) | +mdi:check+ Deployed |
| APIM routes to v2 | +mdi:close+ Manual (Section 2) | +mdi:check+ Automatic |

In complete mode, APIM routes directly to v2 (structured logging) and the workbook + alert rules are deployed via Bicep — no workshop scripts needed.

---

## Deploy

### 1. Create a Fresh Environment

If you already have a Camp 4 environment from the workshop, create a new one to keep things separate:

=== "Bash"
    ```bash
    cd camps/camp4-monitoring

    # Clear any stale environment variables from previous camps
    unset AZURE_ENV_NAME
    unset AZURE_RESOURCE_GROUP

    # Create and select the new azd environment
    azd env new camp4-complete
    azd env select camp4-complete

    # Set your subscription and region
    azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>
    azd env set AZURE_LOCATION <your-region>
    ```

=== "PowerShell"
    ```powershell
    cd camps/camp4-monitoring

    # Clear any stale environment variables from previous camps
    Remove-Item Env:AZURE_ENV_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:AZURE_RESOURCE_GROUP -ErrorAction SilentlyContinue

    # Create and select the new azd environment
    azd env new camp4-complete
    azd env select camp4-complete

    # Set your subscription and region
    azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>
    azd env set AZURE_LOCATION <your-region>
    ```

!!! warning "Shell Environment Variables Override azd"
    If `AZURE_ENV_NAME` or `AZURE_RESOURCE_GROUP` are set in your shell (e.g., from a previous camp), `azd` will use those values instead of the newly created environment — even if you ran `azd env new`. Always clear them before deploying to a new environment.

!!! tip "Finding Your Subscription ID"
    ```bash
    az account show --query id -o tsv
    ```

### 2. Set Complete Mode

=== "Bash"
    ```bash
    azd env set DEPLOY_MODE complete
    ```

=== "PowerShell"
    ```powershell
    azd env set DEPLOY_MODE complete
    ```

This single variable controls the full deployment:

- **Bicep** conditionally deploys the workbook, action group, and alert rules
- **Postprovision hook** routes APIM to v2 instead of v1

### 3. Deploy

=== "Bash"
    ```bash
    azd up
    ```

=== "PowerShell"
    ```powershell
    azd up
    ```

This takes ~10-15 minutes. When it finishes, you'll have the complete observability stack running.

??? info "What Gets Deployed"
    The `azd up` command runs three phases:

    **Provision** (Bicep infrastructure):

    - Log Analytics workspace + Application Insights
    - Container Apps environment with MCP server and Trail API
    - Azure Functions (v1 and v2)
    - API Management with diagnostic settings, policies, and Prompt Shields
    - **Security Dashboard** (Azure Workbook) with 4 panels
    - **Action Group** for alert notifications
    - **4 Alert Rules**: high injection rate, unusual PII volume, security errors, credential exposure

    **Postprovision** (configuration):

    - APIM APIs and operations configured via REST API
    - Content Safety policy fragment applied
    - `function-app-url` named value set to **v2** (structured logging)

    **Deploy** (code):

    - Security Function v1 and v2 uploaded to Azure Functions
    - MCP server and Trail API container images pushed and deployed

### 4. Run the Simulated Attack

Once deployment completes, immediately run the attack simulation to generate data:

=== "Bash"
    ```bash
    ./scripts/section4/4.1-simulate-attack.sh
    ```

=== "PowerShell"
    ```powershell
    ./scripts/section4/4.1-simulate-attack.ps1
    ```

This sends multiple attack types (SQL injection, path traversal, shell injection, prompt injection) through the APIM gateway. While the logs are ingesting, you can verify the deployment.

### 5. Verify in the Portal

By the time you've navigated to the portal, the logs should be flowing. Open your resource group and check:

- **MCP Security Dashboard** (Workbook) → Scorecards show injection and PII counts, pie chart shows blocked attacks by category
- **Log Analytics** → Logs → Run: `AppTraces | where TimeGenerated > ago(10m) | take 10`
- **Monitor** → Alert rules → 4 active rules (high injection rate should have fired from the simulation)

!!! tip "Log Ingestion Delay"
    Azure Log Analytics typically has a 2-5 minute ingestion delay. If the dashboard is empty, wait a couple of minutes and refresh.

---

## Cleanup

=== "Bash"
    ```bash
    # Remove all Azure resources for this environment
    azd down --force --purge

    # Clean up Entra ID app registrations (ignore errors if already deleted)
    az ad app delete --id $(azd env get-value MCP_APP_CLIENT_ID)
    az ad app delete --id $(azd env get-value APIM_CLIENT_APP_ID)
    ```

=== "PowerShell"
    ```powershell
    # Remove all Azure resources for this environment
    azd down --force --purge

    # Clean up Entra ID app registrations (ignore errors if already deleted)
    $MCP_ID = azd env get-value MCP_APP_CLIENT_ID
    $APIM_ID = azd env get-value APIM_CLIENT_APP_ID
    az ad app delete --id $MCP_ID
    az ad app delete --id $APIM_ID
    ```
