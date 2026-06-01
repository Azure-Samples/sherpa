---
title: MCP Governance with Azure API Center
description: "Register and govern MCP servers centrally with Azure API Center to prevent shadow deployments, enable discovery, and track compliance."
keywords: Microsoft, Azure API Center, MCP governance, API governance, shadow server, API discovery, compliance
hide:
  - toc
---

<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">Camp 2 · Registry</div>
      <h1>API and MCP Governance</h1>
      <p>Discover shadow MCP servers, enforce standards, and centralize API governance with Azure API Center.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">hub</span></span>
    </div>
  </div>
</div>

??? info "What is API Center?"
    **API Center** provides a centralized catalog for all your APIs and MCP servers:

    - **Native MCP Support** - API Center recognizes MCP as a first-class API type alongside REST, GraphQL, and gRPC
    - **Shadow Server Prevention** - Require all MCP servers to register before deployment
    - **Discovery** - Search for MCP servers across your organization
    - **Documentation** - Links to MCP tool definitions and usage guides
    - **Versioning** - Track MCP server versions and deprecation schedules
    - **Ownership** - See who owns each MCP server and how to contact them
    - **Compliance** - Tag MCP servers with compliance requirements (HIPAA, PCI, etc.)

    Think of it like a library catalog, but for APIs and MCP servers. If it's not in API Center, it shouldn't be deployed.

## The Security Challenge: Shadow MCP Servers & API Sprawl

**OWASP Risks:** [MCP09 (Shadow MCP Servers)](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp09-shadow-servers/) (primary), with secondary mitigation of [MCP03 (Tool Poisoning)](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp03-tool-poisoning/) — a curated registry blocks unknown or poisoned tools from being discovered and invoked.

As your organization grows, teams independently deploy MCP servers, creating dangerous blind spots:

- **Shadow MCP servers** - Teams deploy unauthorized servers without security review
- **Discovery problem** - Security team doesn't know what MCP servers exist
- **Documentation scattered** - Each team maintains their own docs
- **Duplicate servers** - Two teams build the same MCP tools
- **No ownership tracking** - Who maintains the weather MCP server?
- **Compliance blind spots** - Can't prove all MCP servers meet security standards
- **Unvetted access** - Shadow servers may expose sensitive data without proper controls

You need **centralized API governance** to discover all MCP servers and prevent shadow deployments.

![API Center governance overview](../../images/camp2_section2.png){ .center width=720 }

---

## Fix: Register MCP Servers in API Center

Register your MCP servers in Azure API Center:

=== "Bash"
    ```bash
    ./scripts/1.4-fix.sh
    ```

=== "PowerShell"
    ```powershell
    ./scripts/1.4-fix.ps1
    ```

This registers:

- **Sherpa MCP Server** - Weather, trails, and gear recommendations
- **Trails MCP Server** - Trail information and permit management

**View your registered MCP servers:**

After running the script, open the Azure Portal and navigate to your API Center. You'll see:

| Name | Summary | Type |
|------|---------|------|
| Sherpa MCP Server | Weather forecasts, trail conditions, and gear recommendations | MCP |
| Trails MCP Server | Trail information, permit management, and hiking conditions | MCP |

!!! tip "MCP is a First-Class API Type"
    Notice that API Center lists **MCP** as the API type, not REST or GraphQL. Azure API Center natively understands MCP servers, making it easy to discover and govern all your AI tool integrations in one place.

---

## What You Just Fixed

**Before (no governance):**

- Shadow MCP servers deployed without security review
- No visibility into what MCP servers exist
- Duplicate implementations across teams
- No compliance tracking
- Can't enforce security standards

**After (API Center):**

- All MCP servers registered in central catalog
- Shadow servers discovered and documented
- Easy discovery prevents duplicate work
- Track compliance requirements per server
- Security review before deployment

**OWASP MCP09 (Shadow MCP Servers)** mitigation complete, with secondary defense against **MCP03 (Tool Poisoning)** via registry-gated tool discovery! +mdi:check+

---

## Going Further: API Center Portal & AI Foundry Integration

??? tip "Deploy API Center Portal for Self-Service Discovery"
    **API Center Portal** provides a self-service website where developers can discover and explore your registered MCP servers without needing Azure Portal access.

    **Benefits:**

    - **Self-service discovery** - Developers find MCP servers without asking around
    - **Documentation hub** - Each MCP server's docs in one place
    - **Access control** - Portal respects Azure RBAC permissions
    - **Customizable** - Brand with your organization's look and feel

    **To deploy:**

    1. Create a Static Web App in Azure
    2. Configure it to use API Center as the backend
    3. Set up authentication (Entra ID recommended)

    **Full setup guide:** [Set up API Center Portal](https://learn.microsoft.com/en-us/azure/api-center/set-up-api-center-portal)

??? tip "Microsoft Foundry MCP Integration"
    **Microsoft Foundry** provides enterprise-grade infrastructure for AI applications, including native MCP server support. When combined with API Center governance, you get a complete solution for managing MCP servers at scale.

    **Key capabilities:**

    - **Centralized security** - Apply consistent security policies across all MCP servers
    - **Monitoring** - Track MCP server usage, errors, and performance
    - **Credential management** - Securely manage OAuth tokens and API keys
    - **Multi-region** - Deploy MCP servers globally with consistent governance

    **Security best practices for MCP in Foundry:**

    - Use Managed Identity for MCP server authentication
    - Enable audit logging for all MCP tool invocations
    - Apply network isolation (VNet integration)
    - Register all MCP servers in API Center before deployment

    **Full guide:** [MCP Security Best Practices in Azure AI Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/mcp/security-best-practices?view=foundry)
