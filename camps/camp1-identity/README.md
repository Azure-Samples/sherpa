# Camp 1: Identity & Access Management

> **📚 Workshop Guide:** For the full step-by-step workshop, visit: **[Camp 1: Identity & Access Management](https://azure-samples.github.io/sherpa/camps/camp1-identity/)**

---

Learn how to secure an MCP server deployed to Azure using Managed Identity, Key Vault, and OAuth 2.1 with JWT validation. See why cloud deployment amplifies security risks and how Azure's identity services provide production-grade solutions.

## Overview

| | |
|---|---|
| **Difficulty** | Intermediate |
| **Prerequisites** | Azure subscription, Base Camp recommended |
| **Tech Stack** | Python, FastMCP, Azure Container Apps, Entra ID, Key Vault |

## What You'll Learn

- Deploy MCP servers to Azure Container Apps
- Exploit cloud-specific vulnerabilities (token exposure in Portal)
- Migrate from static tokens to OAuth 2.1 with Entra ID
- Use Azure Managed Identity for passwordless authentication
- Secure secrets with Azure Key Vault

## OWASP MCP Risks Addressed

| Risk | Description | Camp 1 Solution |
|------|-------------|-----------------|
| [MCP-01](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp01-token-mismanagement/) | Token Mismanagement | OAuth 2.1 with short-lived JWTs |
| [MCP-07](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp07-authz/) | Insufficient Authentication | Entra ID + JWT validation |
| [MCP-02](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp02-privilege-escalation/) | Privilege Escalation | Managed Identity + Key Vault RBAC |

## Quick Start

```bash
cd camps/camp1-identity
azd up
```

Then follow the **[Workshop Guide](https://azure-samples.github.io/sherpa/camps/camp1-identity/)** for the exploit → fix → validate walkthrough.

## Security Transformation

| Before (Vulnerable) | After (Secure) |
|---------------------|----------------|
| Static token in env var | OAuth 2.1 JWT with Entra ID |
| Token never expires | ~1 hour expiration |
| Visible in Azure Portal | Not stored (issued per request) |
| Connection strings/keys | Managed Identity (passwordless) |
| Secrets in env vars | Azure Key Vault with RBAC |

## Project Structure

```
camps/camp1-identity/
├── azure.yaml                 # azd configuration
├── infra/                     # Bicep infrastructure
│   ├── main.bicep
│   └── modules/
├── secure-server/             # OAuth-enabled MCP server
│   └── src/
├── vulnerable-server/         # Static token MCP server
│   └── src/
└── scripts/                   # Workshop scripts
```

## Cleanup

```bash
azd down --force --purge
```

## Next Steps

- **[Camp 2: Gateway Security](../camp2-gateway/)** - Add API Management, rate limiting, and content safety
