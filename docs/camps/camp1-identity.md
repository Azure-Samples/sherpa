# Camp 1: Identity & Access Management

*"Establishing Your Identity on the Mountain"*

!!! info "Camp Details"
    **Duration:** 90 minutes  
    **Azure Services:** Entra ID, Managed Identity, Key Vault, Container Apps  
    **Primary Risks:** MCP07 (Insufficient Authentication), MCP01 (Token Mismanagement), MCP02 (Privilege Escalation)

## What You'll Learn

Building on Base Camp's foundation, you'll master enterprise-grade identity and access management in Azure. This camp tackles the critical challenge of managing secrets and implementing proper authentication for production MCP deployments.

!!! tip "Learning Objectives"
    - Implement OAuth 2.1 authentication with PKCE for MCP clients
    - Configure Azure Managed Identity for passwordless authentication
    - Secure secrets with Azure Key Vault
    - Apply least-privilege RBAC principles
    - Eliminate hardcoded credentials from your codebase

## The Challenge

Your MCP server needs to access Azure resources, but hardcoded connection strings and API keys create massive security vulnerabilities. You'll deploy a vulnerable system, exploit its weaknesses, then rebuild it using Azure's identity services.

## What You'll Build

<div class="grid cards" markdown>

- :material-key-variant:{ .lg .middle } __OAuth 2.1 Authentication__

    ---

    Implement modern authentication flows with PKCE for secure client access

- :material-shield-account:{ .lg .middle } __Managed Identity__

    ---

    Eliminate passwords with Azure's built-in identity service

- :material-lock:{ .lg .middle } __Key Vault Integration__

    ---

    Store and rotate secrets securely using industry best practices

- :material-account-lock:{ .lg .middle } __Least-Privilege RBAC__

    ---

    Grant only the permissions needed - nothing more

</div>

## Coming Soon

!!! warning "Under Development"
    This camp is being built right now! We're creating hands-on exercises that will teach you:
    
    - How to exploit hardcoded secrets and token mismanagement
    - Step-by-step OAuth 2.1 implementation
    - Managed Identity configuration for Container Apps
    - Key Vault setup and access patterns
    - RBAC role assignments and validation

!!! quote "Guide Reference"
    For comprehensive identity security guidance, see the [OWASP MCP Azure Security Guide](https://microsoft.github.io/mcp-azure-security-guide)

---

← [Base Camp](base-camp.md) | [Camp 2: Gateway Security](camp2-gateway.md) →
