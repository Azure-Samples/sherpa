---
hide:
  - toc
---

# Section 3: Dashboards & Alerts

*Make security actionable*

← [Function Observability](section2-function-observability.md)

---

You have structured logs flowing and you can query them with KQL. But nobody has time to run queries all day. This is the final step in the **hidden → visible → actionable** journey: dashboards for at-a-glance status, and alerts that notify you at 3 AM.

## 3.1 Deploy the Dashboard

???+ abstract "Create Security Workbook"

    Deploy the Azure Monitor Workbook:

    ```bash
    ./scripts/section3/3.1-deploy-workbook.sh
    ```

    **Access the dashboard:**

    1. Open the [Azure Portal](https://portal.azure.com)
    2. Navigate to your **Log Analytics workspace** (`log-camp4-xxxxx`)
    3. Click **Workbooks** in the left menu
    4. Select **MCP Security Dashboard** from the list

    !!! tip "If the dashboard appears empty"
        Do a hard refresh (`Cmd+Shift+R` or `Ctrl+Shift+R`) to reload the portal UI. The visualization components sometimes fail to load on first access.

    **Dashboard panels:**

    | Panel | Type | Shows |
    |-------|------|-------|
    | MCP Request Volume | Area chart | Traffic over 24h |
    | Attacks by Injection Type | Pie chart | Breakdown of blocked attack categories |
    | Top Targeted Tools | Bar chart | Which MCP tools attackers probe most |
    | Top Error Sources | Table | IPs generating errors |
    | Recent Security Events | Table | Live feed of security activity |

    !!! info "Workshop vs Production Dashboard"
        This script deploys a workshop-friendly dashboard focused on exploration. The [Production Deployment](production-deploy.md) deploys an optimized version with security summary scorecards, severity distribution, and alert-ready panels. The production dashboard is defined in Bicep and deployed automatically with `DEPLOY_MODE=complete`.

    !!! info "Why Workbooks?"
        Azure has both **Workbooks** and **Dashboards**. Workbooks are interactive, document-like reports that query live data — no ETL pipelines, no staleness. For security monitoring, they're the better choice because you need analytical depth, not just pinned tiles.

## 3.2 Create Alert Rules

Dashboards are great when you're looking at them. Alerts watch your logs continuously and notify you when something needs attention.

???+ success "Set Up Automated Notifications"

    Create alert rules:

    ```bash
    ./scripts/section3/3.2-create-alerts.sh
    ```

    The script will prompt for an optional email address. You can skip this and view fired alerts in the Azure Portal instead.

    **What the script creates:**

    | Resource | Details |
    |----------|---------|
    | **Action Group** (`mcp-security-alerts`) | Notification list — email receiver if you provided one |
    | **Alert: High Attack Volume** (Sev 2 — Warning) | Fires when >10 attacks in 5 minutes. Detects active campaigns. |
    | **Alert: Credential Exposure** (Sev 1 — Error) | Fires on ANY credential detection. Critical security event. |

    Both alerts evaluate every 5 minutes. When the KQL query returns results, the alert fires and notifies your Action Group.

    !!! info "What's an Action Group?"
        An Action Group is your incident response contact list — email, SMS, webhook, or even an Azure Function for automated remediation. For this workshop, we keep it simple with email (or none). In production, you'd add SMS for critical alerts and webhooks for Slack/Teams.

    !!! warning "Alert Fatigue"
        The biggest mistake teams make is setting thresholds too low. If you get 50 alerts a day, you'll start ignoring them. Start with conservative thresholds and tune down as you learn your baseline.

    **Verify in Azure Portal:**

    1. Navigate to **Monitor** → **Alerts**
    2. Click **Alert rules** to see your configured rules
    3. After running the attack simulation in Section 4, wait 5-10 minutes and check for fired alerts

---

Dashboards and alerts are live. Time to put the whole system to the test.

[Next: Incident Response →](section4-incident-response.md){ .md-button .md-button--primary }

---

← [Function Observability](section2-function-observability.md) | [Incident Response →](section4-incident-response.md)
