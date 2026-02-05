# Base Camp: Understanding the Mountain

> **📚 Workshop Guide:** For the full step-by-step workshop, visit: **[Base Camp](https://azure-samples.github.io/sherpa/camps/base-camp/)**

---

Experience the risk of unauthenticated MCP servers firsthand. Deploy a vulnerable server, exploit it, then implement basic authentication using FastMCP's built-in security features.

## Overview

| | |
|---|---|
| **Difficulty** | Beginner |
| **Prerequisites** | Python 3.11+, uv, node.js >=22 |
| **Tech Stack** | Python, FastMCP, MCP Inspector |

## What You'll Learn

- Understand what MCP is and why security matters
- Experience unauthorized data access in an unauthenticated server
- Implement token-based authentication with FastMCP
- Add authorization checks to protect user data

## OWASP MCP Risks Addressed

| Risk | Description | Base Camp Solution |
|------|-------------|-------------------|
| [MCP-07](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp07-authz/) | Insufficient Auth | Bearer token validation |
| [MCP-01](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp01-token-mismanagement/) | Token Exposure | Environment variables |
| [MCP-02](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp02-privilege-escalation/) | Privilege Escalation | Authorization checks |

## Quick Start

```bash
cd camps/base-camp
uv sync
```

Then follow the **[Workshop Guide](https://azure-samples.github.io/sherpa/camps/base-camp/)** for the exploit → fix → validate walkthrough.

## Project Structure

```
base-camp/
├── vulnerable-server/     # MCP server with NO authentication
│   └── src/server.py
├── secure-server/         # MCP server WITH authentication
│   └── src/server.py
├── exploits/              # Test scripts
│   ├── test_vulnerable.py
│   └── test_secure.py
└── pyproject.toml
```

## ⚠️ Not Production-Ready

Base Camp uses simple bearer tokens for learning. This is **not** production-ready:

- No token expiration or rotation
- Hardcoded user mapping
- No audit logging

**Camp 1** upgrades to production-grade OAuth 2.1 with Azure Entra ID.

## Next Steps

- **[Camp 1: Identity & Access Management](../camp1-identity/)** - Production-grade OAuth 2.1 security on Azure
