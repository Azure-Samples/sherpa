# Camp 1: Identity & Access Management

> **Looking for the workshop?** This README is a quick reference for the codebase. For the full step-by-step workshop guide, visit: **[Camp 1: Identity & Access Management Workshop](https://azure-samples.github.io/sherpa/camps/camp1-identity/)**

---

> *"Establishing Your Identity on the Mountain"*

Learn how to secure an MCP server deployed to Azure using Managed Identity, Key Vault, and OAuth 2.1 with JWT validation. This camp demonstrates why cloud deployment amplifies security risks and how Azure's identity services provide production-grade solutions.

## Overview

- **Difficulty:** Intermediate
- **Prerequisites:** Azure subscription, completed Base Camp (recommended)
- **Tech Stack:** Python, FastMCP, Azure Container Apps, Entra ID, Key Vault

## What You'll Learn

- Deploy MCP servers to Azure Container Apps
- Exploit cloud-specific vulnerabilities (token exposure in Portal)
- Migrate from static tokens to OAuth 2.1 with Entra ID
- Use Azure Managed Identity for passwordless authentication
- Secure secrets with Azure Key Vault
- Implement JWT validation with audience checking
- Apply least-privilege RBAC principles

## OWASP Risks Addressed

- **MCP01:** Token Mismanagement
- **MCP07:** Insufficient Authentication  
- **MCP02:** Privilege Escalation

## 📖 Complete Workshop Documentation

**All detailed instructions, exploits, and security guidance are on GitHub Pages:**

### 👉 **[View Full Camp 1 Workshop](https://azure-samples.github.io/sherpa/camps/camp1-identity/)**

The documentation includes:

- **Waypoint 1:** Deploy Vulnerable Server to Azure
- **Waypoint 2:** Exploit Cloud Vulnerabilities  
- **Waypoint 3:** Enable Managed Identity
- **Waypoint 4:** Migrate Secrets to Key Vault
- **Waypoint 5:** Upgrade to OAuth 2.1 with JWT Validation
- **Waypoint 6:** Validate Security

Each waypoint includes step-by-step commands, expected outputs, and security explanations.

## Security Transformation

| Security Control | Before (Vulnerable) | After (Secure) |
|-----------------|---------------------|----------------|
| **Authentication** | Static token in env var | OAuth 2.1 JWT with Entra ID |
| **Token Lifetime** | Never expires | ~1 hour expiration |
| **Token Storage** | Visible in Azure Portal | Not stored (issued per request) |
| **Azure Access** | Connection strings/keys | Managed Identity (passwordless) |
| **Secrets** | Environment variables | Azure Key Vault with RBAC |
| **Validation** | Token string match only | JWT signature, issuer, audience, expiration |
| **Revocation** | Impossible | Token expiry + Entra ID revocation |
| **Audit Trail** | None | Azure Monitor logs all access |

## Key Technologies

- **Azure Container Apps:** Serverless container hosting
- **Azure Managed Identity:** Passwordless authentication to Azure services
- **Azure Key Vault:** Secure secret storage with RBAC
- **Azure Entra ID:** Enterprise identity and OAuth provider
- **FastMCP:** Modern MCP framework with authentication support
- **OAuth 2.1:** Modern authentication with PKCE and short-lived tokens

## Authentication Flows

This workshop demonstrates two OAuth 2.1 flows. Choose based on your scenario:

| Flow | Best For | How It Works |
|------|----------|--------------|
| **Device Code Flow** | CLI tools, headless servers, SSH sessions | Displays a code to enter at microsoft.com/devicelogin |
| **Authorization Code + PKCE** | Desktop apps, browser-based tools, VS Code | Opens browser, redirects back to localhost:8090 |

**Recommendation:** Start with Device Code Flow - it works in any terminal. Use Authorization Code + PKCE when building apps that can handle browser redirects.

## Next Steps

After completing Camp 1:

1. **Review your own MCP servers** for token exposure risks
2. **Apply Managed Identity** to eliminate credentials in code
3. **Migrate secrets to Key Vault** for centralized management
4. **Implement OAuth 2.1** for production authentication

Continue your journey:

**[→ Camp 2: Gateway & Network Security](../camp2-gateway/)**

---

**Resources:**

- [Complete Workshop Documentation](https://azure-samples.github.io/sherpa/camps/camp1-identity/)
- [OWASP MCP Azure Security Guide](https://microsoft.github.io/mcp-azure-security-guide/)
- [Azure Managed Identity Docs](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [OAuth 2.1 Specification](https://oauth.net/2.1/)

---

[← Base Camp](../base-camp/) | [Sherpa Home](../../README.md) | [Camp 2 →](../camp2-gateway/)
