# 🏔️ The MCP Security Summit Workshop

*A Sherpa's Guide to Securing Model Context Protocol Servers in Azure*

<div align="center">

**🚀 [Start the Workshop →](https://azure-samples.github.io/sherpa/)**

</div>

<div align="center">
  <img src="docs/images/sherpa-mcp-workshop.png" alt="MCP Security Workshop" width="300">
</div>

## Overview

This workshop takes you on an expedition from Base Camp to the Summit, where you'll learn to secure Model Context Protocol (MCP) servers in Azure. Like any great mountain expedition, we'll face challenges, but with proper preparation and the right tools, we'll reach the peak together.

MCP is an open protocol that lets AI applications connect to external tools and data sources. It's becoming the standard way to extend AI capabilities—and that means security is critical. This workshop teaches you practical, hands-on security techniques you can apply immediately.

**Aligned with:** [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) | [OWASP MCP Top 10 2025](https://owasp.org/www-project-mcp-top-10/)

## The Journey

Our expedition follows a proven path where each camp builds on the last, creating defense-in-depth security.

<div align="center">
  <img src="docs/images/sherpa-mcp-workshop-map.png" alt="Expedition Route">
</div>

| Camp | Theme | Focus |
|:----:|:-----:|:-----:|
| **Base Camp** | Understanding the Mountain | MCP fundamentals, basic authentication |
| **Camp 1** | Establishing Your Identity | OAuth, Managed Identity, Key Vault |
| **Camp 2** | Scaling the Gateway Ridge | API/MCP Gateway, Private Endpoints, API Center |
| **Camp 3** | Navigating I/O Pass | Content Safety, Input Validation, PII Detection |
| **Camp 4** | Observation Peak | Logging, Monitoring, Threat Detection |
| **Summit** | Full Integration | Red Team / Blue Team, Defense Validation |

## Reference Guide

Comprehensive security guidance is available at:  
**[microsoft.github.io/mcp-azure-security-guide](https://microsoft.github.io/mcp-azure-security-guide/)**

Throughout the workshop, we reference specific sections for deeper dives on each OWASP MCP Top 10 2025 risk.

## Prerequisites

- **Azure subscription** with Contributor access
- **VS Code** with GitHub Copilot or MCP extension
- **Azure CLI** installed and authenticated
- **Python 3.10+** installed
- **Node.js 22+** installed
- Basic familiarity with Azure Portal
- No prior MCP or security expertise required

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Azure-Samples/sherpa.git
   cd sherpa
   ```

2. **Start at Base Camp:**
   ```bash
   cd camps/base-camp
   ```

3. **Follow the guide:**  
   Visit **[azure-samples.github.io/sherpa](https://azure-samples.github.io/sherpa/)** for step-by-step instructions following our proven "Deploy → Exploit → Fix → Validate" pattern.

## Workshop Methodology

Each camp follows our proven pattern:

1. **Deploy Vulnerable System** — Experience the risks firsthand
2. **Exploit Vulnerabilities** — Use VS Code MCP client to demonstrate attacks
3. **Implement Security Fixes** — Apply Azure security controls
4. **Validate** — Re-attempt exploits to confirm protection
5. **Summary & Teaching Points** — Connect to OWASP risks and guide references

## OWASP MCP Top 10 2025 Coverage

Category names below follow the current OWASP MCP Top 10 2025 list. Links point to Azure-specific implementation guidance in the companion security guide.

| Risk | Name | Camp |
|:----:|------|:----:|
| **[MCP01:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp01-token-mismanagement/)** | Token Mismanagement & Secret Exposure | Base Camp, Camp 1, Camp 3 |
| **[MCP02:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp02-privilege-escalation/)** | Privilege Escalation via Scope Creep | Camp 1, Camp 2 |
| **[MCP03:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp03-tool-poisoning/)** | Tool Poisoning | Camp 2, Camp 3 |
| **[MCP04:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp04-supply-chain/)** | Software Supply Chain Attacks & Dependency Tampering | Camp 4 |
| **[MCP05:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp05-command-injection/)** | Command Injection & Execution | Camp 3 |
| **[MCP06:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp06-prompt-injection/)** | Intent Flow Subversion | Camp 2, Camp 3 |
| **[MCP07:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp07-authz/)** | Insufficient Authentication & Authorization | Base Camp, Camp 1, Camp 2 |
| **[MCP08:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp08-telemetry/)** | Lack of Audit and Telemetry | Camp 4 |
| **[MCP09:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp09-shadow-servers/)** | Shadow MCP Servers | Camp 2 |
| **[MCP10:2025](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp10-context-oversharing/)** | Context Injection & Over-Sharing | Camp 3 |

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to add new camps or improve existing content.

## Resources

- **OWASP MCP Top 10 2025:** [owasp.org/www-project-mcp-top-10](https://owasp.org/www-project-mcp-top-10/)
- **OWASP MCP Azure Security Guide:** [microsoft.github.io/mcp-azure-security-guide](https://microsoft.github.io/mcp-azure-security-guide/)
- **MCP Specification:** [modelcontextprotocol.io/specification/2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25)
- **Security Best Practices:** [modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices)
- **Azure API Management:** [learn.microsoft.com/azure/api-management](https://learn.microsoft.com/azure/api-management/)
- **Azure API Center:** [learn.microsoft.com/azure/api-center](https://learn.microsoft.com/azure/api-center/)
- **Azure Key Vault:** [learn.microsoft.com/azure/key-vault](https://learn.microsoft.com/azure/key-vault/)
- **Azure Managed Identity:** [learn.microsoft.com/entra/identity/managed-identities-azure-resources](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/)
- **Azure AI Foundry:** [learn.microsoft.com/azure/ai-foundry/what-is-azure-ai-foundry](https://learn.microsoft.com/azure/ai-foundry/what-is-azure-ai-foundry?view=foundry)
- **Azure AI Content Safety:** [learn.microsoft.com/azure/ai-services/content-safety](https://learn.microsoft.com/azure/ai-services/content-safety/)

---

**Let's begin the ascent! 🏔️**
