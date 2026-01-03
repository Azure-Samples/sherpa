# 🏔️ The MCP Security Summit Workshop

*A Sherpa's Guide to Securing Model Context Protocol Servers in Azure*

**🚀 [Start the Workshop →](https://azure-samples.github.io/sherpa/)**

<img src="docs/images/sherpa-mcp-workshop.png" alt="MCP Security Workshop" width="400">

## Overview

This workshop takes you on an expedition from Base Camp to the Summit, where you'll learn to secure Model Context Protocol (MCP) servers in Azure. Like any great mountain expedition, we'll face challenges, but with proper preparation and the right tools, we'll reach the peak together.

MCP is an open protocol that lets AI applications connect to external tools and data sources. It's becoming the standard way to extend AI capabilities—and that means security is critical. This workshop teaches you practical, hands-on security techniques you can apply immediately.

**Aligned with:** MCP Specification 2025-11-25 | OWASP MCP Top 10

## 🗺️ The Journey

Our expedition follows a proven path where each camp builds on the last, creating defense-in-depth security.

![Expedition Route](docs/images/sherpa-mcp-workshop-map.png)

| Stop | Theme | Focus |
|:----:|:-----:|:-----:|
| **Base Camp** | Understanding the Mountain | MCP fundamentals, basic authentication |
| **Camp 1** | Establishing Your Identity | OAuth, Managed Identity, Key Vault |
| **Camp 2** | Scaling the Gateway Ridge | API/MCP Gateway, Private Endpoints, API Center |
| **Camp 3** | Navigating I/O Pass | Content Safety, Input Validation, PII Detection |
| **Camp 4** | Observation Peak | Logging, Monitoring, Threat Detection |
| **Summit** | Full Integration | Red Team / Blue Team, Defense Validation |



## 📚 Reference Guide

Comprehensive security guidance is available at:  
**[microsoft.github.io/mcp-azure-security-guide](https://microsoft.github.io/mcp-azure-security-guide/)**

Throughout the workshop, we reference specific sections for deeper dives on each OWASP MCP Top 10 risk.

## Prerequisites

- **Azure subscription** with Contributor access
- **VS Code** with GitHub Copilot or MCP extension
- **Azure CLI** installed and authenticated
- **Python 3.10+** installed
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

## OWASP MCP Top 10 Coverage

| Risk | Name | Camp |
|:----:|------|:----:|
| **MCP01** | Token Mismanagement & Secret Exposure | Base Camp (primary), Camp 1 (primary) |
| **MCP02** | Privilege Escalation via Scope Creep | Base Camp (secondary), Camp 1 (secondary), Camp 2 (primary) |
| **MCP03** | Tool Poisoning | Camp 3 (secondary) |
| **MCP04** | Supply Chain Attacks | Awareness |
| **MCP05** | Command Injection & Execution | Camp 3 (primary) |
| **MCP06** | Prompt Injection via Contextual Payloads | Camp 3 (primary) |
| **MCP07** | Insufficient Authentication & Authorization | Base Camp (primary), Camp 1 (primary), Camp 2 (secondary) |
| **MCP08** | Lack of Audit and Telemetry | Camp 4 (primary) |
| **MCP09** | Shadow MCP Servers | Camp 2 (primary) |
| **MCP10** | Context Injection & Over-Sharing | Awareness |

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to add new camps or improve existing content.

## Resources

- **OWASP MCP Azure Guide:** [microsoft.github.io/mcp-azure-security-guide](https://microsoft.github.io/mcp-azure-security-guide/)
- **MCP Specification:** [modelcontextprotocol.io/specification/2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25)
- **Security Best Practices:** [modelcontextprotocol.io/.../security_best_practices](https://modelcontextprotocol.io/.../basic/security_best_practices)
- **Azure API Management:** [learn.microsoft.com/azure/api-management](https://learn.microsoft.com/azure/api-management/)
- **Azure API Center:** [learn.microsoft.com/azure/api-center](https://learn.microsoft.com/azure/api-center/)
- **Azure Key Vault:** [learn.microsoft.com/azure/key-vault](https://learn.microsoft.com/azure/key-vault/)
- **Azure Managed Identity:** [learn.microsoft.com/entra/identity/managed-identities-azure-resources](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/)
- **Microsoft Foundry:** [learn.microsoft.com/azure/ai-foundry/what-is-azure-ai-foundry](https://learn.microsoft.com/azure/ai-foundry/what-is-azure-ai-foundry?view=foundry)
- **Azure AI Content Safety:** [learn.microsoft.com/azure/ai-services/content-safety](https://learn.microsoft.com/azure/ai-services/content-safety/)

---

*"The mountain doesn't care about your excuses. Prepare well, climb smart, reach the summit."*

**Let's begin the ascent! 🏔️**
