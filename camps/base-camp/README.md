# Base Camp: Understanding the Mountain

> **Looking for the workshop?** This README is a quick reference for the codebase. For the full step-by-step workshop guide, visit: **[Base Camp Workshop](https://azure-samples.github.io/sherpa/camps/base-camp/)**

---

> *"Know Your Terrain Before You Climb"* - Before securing MCP servers, you must understand how they work and what can go wrong.

Experience the risk of unauthenticated MCP servers firsthand. Deploy a vulnerable server, exploit it, then implement basic authentication using FastMCP's built-in security features.

## Overview

- **Difficulty:** Beginner
- **Prerequisites:** Python 3.11+, VS Code (optional)
- **Tech Stack:** Python, FastMCP, MCP Inspector
- **Estimated Time:** 60 minutes

## Workshop Methodology

Base Camp introduces the **vulnerable → exploit → fix → validate** pattern used throughout all camps:

1. **Deploy Vulnerable**: Start with an insecure MCP server
2. **Exploit**: Demonstrate the real-world risk
3. **Fix**: Apply basic authentication
4. **Validate**: Confirm the fix works

## What You'll Learn

- Understand what MCP is and why security matters
- Experience unauthorized data access in an unauthenticated MCP server
- Implement token-based authentication with FastMCP
- Add authorization checks to protect user data
- Set up your workshop environment for future camps

## OWASP MCP Risks Addressed

| Risk | Description | Vulnerability | Fix |
|------|-------------|---------------|-----|
| MCP-07 | Insufficient Auth | No authentication required | Bearer token validation |
| MCP-01 | Token Exposure | Hardcoded secrets | Environment variables |
| MCP-02 | Privilege Escalation | Access any user's data | Authorization checks |

## Quick Start

```bash
# Navigate to Base Camp
cd camps/base-camp

# Install dependencies
uv sync

# Start vulnerable server
cd vulnerable-server
uv run --project .. python -m src.server
```

Then follow the [workshop guide](https://azure-samples.github.io/sherpa/camps/base-camp/) for exploitation and fixing steps.

## Directory Structure

```
base-camp/
├── vulnerable-server/     # MCP server with NO authentication
│   └── src/server.py      # Demonstrates MCP-07 vulnerability
├── secure-server/         # MCP server WITH authentication
│   └── src/server.py      # Shows proper auth implementation
├── exploits/              # Test scripts for both servers
│   ├── test_vulnerable.py # Automated exploit demonstration
│   ├── test_secure.py     # Validates security fixes
│   └── launch-inspector-http.sh
└── pyproject.toml         # Shared dependencies
```

## Key Code Comparison

**Vulnerable (no auth):**
```python
mcp = FastMCP("Vulnerable Server")

@mcp.tool()
async def get_user_info(user_id: str) -> dict:
    # 🚨 Anyone can access ANY user's data!
    return USERS.get(user_id)
```

**Secure (with auth):**
```python
from fastmcp.auth import StaticTokenVerifier

auth = StaticTokenVerifier(tokens={
    REQUIRED_TOKEN: {"client_id": "user_001"}
})
mcp = FastMCP("Secure Server", auth=auth)

@mcp.tool()
async def get_user_info(ctx: Context, user_id: str) -> dict:
    # ✅ Check authorization
    if user_id != get_authenticated_user(ctx):
        raise PermissionError("Cannot access other user's data")
    return USERS.get(user_id)
```

## Important: Not Production-Ready!

Base Camp uses simple bearer tokens for learning. This is **NOT** production-ready:

❌ No token expiration  
❌ No token rotation  
❌ Hardcoded user mapping  
❌ No audit logging

**Camp 1** upgrades to production-grade security with OAuth 2.1, Azure Entra ID, and Key Vault.

## Testing

```bash
# Test vulnerable server (all exploits should succeed)
cd exploits
uv run --project .. python test_vulnerable.py

# Test secure server (all security checks should pass)
uv run --project .. python test_secure.py
```

## Next Steps

After completing Base Camp, continue to **[Camp 1: Identity & Access Management](../camp1-identity/)** for production-grade OAuth 2.1 security.

---

*Base Camp complete! You've learned the fundamentals. Now let's climb higher.* 🏔️
