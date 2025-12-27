# Base Camp: Understanding the Mountain

*"Know Your Terrain Before You Climb"*

!!! info "Camp Details"
    **Duration:** 60 minutes  
    **Tech Stack:** Python, MCP SDK, VS Code  
    **Primary Risks:** MCP07 (Insufficient Authentication), MCP01 (Token Mismanagement)

## What You'll Learn

At Base Camp, you'll establish the foundation for your security expedition. This introductory camp teaches you the workshop's proven methodology through hands-on experience with MCP server vulnerabilities.

!!! tip "Learning Objectives"
    - Experience the risk of unauthenticated MCP servers firsthand
    - Master the "vulnerable → exploit → fix → validate" methodology
    - Implement basic authentication for MCP servers
    - Set up your development environment for the journey ahead

## The Challenge

You'll deploy a vulnerable MCP server that exposes sensitive user data without any authentication. Then, you'll exploit it to see how easily attackers can access private information. Finally, you'll implement proper authentication and verify the fix.

## Your Journey Through Base Camp

| Phase | Activity | Duration |
|:-----:|----------|:--------:|
| **1** | Deploy Vulnerable Server | 10 min |
| **2** | Exploit the Vulnerability | 15 min |
| **3** | Understand the Risk | 10 min |
| **4** | Implement Security | 15 min |
| **5** | Validate the Fix | 10 min |

## What You'll Build

<div class="grid cards" markdown>

- :material-server-security:{ .lg .middle } __Vulnerable System__

    ---

    Deploy an MCP server with no authentication - a common but dangerous pattern

- :material-bug:{ .lg .middle } __Live Exploitation__

    ---

    Use the MCP client to access data you shouldn't be able to see

- :material-shield-check:{ .lg .middle } __Security Implementation__

    ---

    Add authentication and authorization to protect your server

- :material-check-all:{ .lg .middle } __Validation__

    ---

    Prove your fixes work by re-attempting the exploits

</div>

## Get Started

!!! success "Ready to Begin?"
    Head over to the [Base Camp README on GitHub](https://github.com/Azure-Samples/sherpa/tree/main/camps/base-camp) for complete step-by-step instructions, setup guides, and hands-on exercises.

## Key Security Principles

By the end of Base Camp, you'll understand these critical security concepts:

- **Never trust, always verify** - Authentication is non-negotiable
- **Defense in depth** - Authentication is just the first layer
- **Exploit-driven learning** - Test your security by attempting attacks
- **Fail fast, fix quickly** - Find vulnerabilities before attackers do

!!! quote "Guide Reference"
    For deeper technical details on authentication vulnerabilities, see the [OWASP MCP Azure Security Guide: MCP07](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp07-authz/)

---

**Next Stop:** [Camp 1: Identity & Access Management](camp1-identity.md) →
