---
hide:
  - toc
---

# Production Deployment

*Deploy the fully-configured stack in one command*

← [Incident Response](section4-incident-response.md)

---

## Skip the Workshop, Deploy Everything

Throughout Camp 4, you built observability step by step: enabling diagnostics, switching to structured logging, deploying a dashboard, and creating alert rules. That's great for learning — but what if you just want the end result?

The **complete deployment mode** deploys the entire Camp 4 stack in a single `azd up`, including:

| Component | Workshop Mode (default) | Complete Mode |
|-----------|------------------------|---------------|
| APIM + Diagnostic Settings | :material-check: Deployed | :material-check: Deployed |
| Security Function v1 (basic logging) | :material-check: **Active** | :material-check: Deployed |
| Security Function v2 (structured logging) | :material-check: Deployed | :material-check: **Active** |
| MCP Server + Trail API | :material-check: Deployed | :material-check: Deployed |
| Security Dashboard (Workbook) | :material-close: Manual (Section 3) | :material-check: Deployed |
| Alert Rules + Action Group | :material-close: Manual (Section 3) | :material-check: Deployed |
| APIM routes to v2 | :material-close: Manual (Section 2) | :material-check: Automatic |

In complete mode, APIM routes directly to v2 (structured logging) and the workbook + alert rules are deployed via Bicep — no workshop scripts needed.

---

## Deploy

### 1. Create a Fresh Environment

If you already have a Camp 4 environment from the workshop, create a new one to keep things separate:

```bash
cd camps/camp4-monitoring

# Create a new azd environment
azd env new camp4-complete

# Set your subscription and region
azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>
azd env set AZURE_LOCATION <your-region>
```

!!! tip "Finding Your Subscription ID"
    ```bash
    az account show --query id -o tsv
    ```

### 2. Set Complete Mode

```bash
azd env set DEPLOY_MODE complete
```

This single variable controls the full deployment:

- **Bicep** conditionally deploys the workbook, action group, and alert rules
- **Postprovision hook** routes APIM to v2 instead of v1

### 3. Deploy

```bash
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

```bash
./scripts/section4/4.1-simulate-attack.sh
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

```bash
# Remove all Azure resources for this environment
azd down --force --purge

# Clean up Entra ID app registrations (ignore errors if already deleted)
az ad app delete --id $(azd env get-value MCP_APP_CLIENT_ID)
az ad app delete --id $(azd env get-value APIM_CLIENT_APP_ID)
```

---
