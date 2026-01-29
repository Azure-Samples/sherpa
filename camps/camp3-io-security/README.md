# Camp 3: I/O Security

> **📚 Workshop Guide:** For the full step-by-step workshop, visit: **[Camp 3: I/O Security](https://azure-samples.github.io/sherpa/camps/camp3-io-security/)**

---

Implement defense-in-depth I/O security for MCP servers using Azure Functions and Azure AI Services. Learn to detect technical injection patterns (shell, SQL, path traversal), redact PII from responses, and scan for credential leakage.

## Overview

| | |
|---|---|
| **Difficulty** | Advanced |
| **Prerequisites** | Azure subscription, Camp 2 recommended |
| **Tech Stack** | Python, MCP, Azure Functions, Azure AI Language, APIM |

## What You'll Learn

- Why Content Safety alone isn't sufficient for technical injection attacks
- Deploy Azure Functions as security middleware for APIM
- Implement injection pattern detection (shell, SQL, path traversal)
- Configure PII detection and redaction using Azure AI Language
- Understand defense-in-depth architecture for I/O security

## OWASP MCP Risks Addressed

| Risk | Description | Camp 3 Solution |
|------|-------------|-----------------|
| [MCP-05](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp05-command-injection/) | Command Injection | `input_check` function detects shell/SQL/path traversal |
| [MCP-03](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp03-tool-poisoning/) | Tool Poisoning | `sanitize_output` function redacts PII and credentials |
| [MCP-10](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp10-context-oversharing/) | Context Over-Sharing | Output sanitization prevents data leakage |

## Quick Start

```bash
cd camps/camp3-io-security
azd up
```

Then follow the **[Workshop Guide](https://azure-samples.github.io/sherpa/camps/camp3-io-security/)** for the exploit → fix → validate walkthrough.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         APIM Gateway                            │
│                                                                 │
│  INBOUND:                                                       │
│    1. OAuth validation                                          │
│    2. Content Safety (Layer 1) - harmful content, jailbreaks    │
│    3. input_check Function (Layer 2) - technical injections     │
│                                                                 │
│  OUTBOUND:                                                      │
│    1. sanitize_output Function - PII redaction, cred scanning   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  MCP Servers (Container Apps) │
              └───────────────────────────────┘
```

## Project Structure

```
camps/camp3-io-security/
├── azure.yaml                 # azd configuration
├── infra/                     # Bicep infrastructure
│   ├── main.bicep
│   ├── modules/
│   └── policies/              # APIM policy files
├── servers/
│   ├── sherpa-mcp-server/     # Native MCP server
│   └── trail-api/             # REST API backend
├── security-function/         # Azure Function App
│   ├── function_app.py
│   └── shared/
│       ├── injection_patterns.py
│       ├── pii_detector.py
│       └── credential_scanner.py
└── scripts/                   # Workshop scripts
```

## Cleanup

```bash
azd down --force --purge
```

## Next Steps

- **[Camp 4: Monitoring](../camp4-monitoring/)** - Detect and respond to security incidents
