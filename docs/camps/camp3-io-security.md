---
hide:
  - toc
---

# Camp 3: I/O Security

*Navigating the Treacherous I/O Pass*

![Security](../images/sherpa-security.png)

!!! info "Camp Details"
    **Duration:** 90 minutes  
    **Azure Services:** Content Safety, AI Services  
    **Primary Risks:** [MCP06](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp06-prompt-injection/) (Prompt Injection), [MCP05](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp05-command-injection/) (Command Injection), [MCP03](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp03-tool-poisoning/) (Tool Poisoning)

## What You'll Learn

The most dangerous attacks against MCP servers come through their inputs and outputs. At Camp 3, you'll learn to validate, sanitize, and protect every byte of data flowing through your servers.

!!! tip "Learning Objectives"
    - Integrate Azure Content Safety for harmful content detection
    - Implement robust input validation and sanitization
    - Detect and redact PII in real-time
    - Prevent prompt injection attacks
    - Mitigate command injection vulnerabilities

## The Challenge

MCP servers act as bridges between AI and your systems. Without proper I/O security, attackers can inject malicious prompts, execute arbitrary commands, or exfiltrate sensitive data. You'll experience these attacks firsthand, then build comprehensive defenses.

## What You'll Build

<div class="grid cards" markdown>

- :material-shield-alert:{ .lg .middle } __Content Safety__

    ---

    Block harmful, toxic, or malicious content using Azure AI

- :material-form-textbox-password:{ .lg .middle } __Input Validation__

    ---

    Sanitize and validate all inputs before processing

- :material-eye-off:{ .lg .middle } __PII Detection__

    ---

    Automatically detect and redact sensitive personal information

- :material-shield-bug:{ .lg .middle } __Injection Prevention__

    ---

    Stop prompt and command injection attacks in their tracks

</div>

## Coming Soon

!!! warning "Under Development"
    This critical camp is in active development! Soon you'll master:
    
    - Exploiting prompt injection and command execution flaws
    - Azure Content Safety API integration and configuration
    - Building robust validation frameworks
    - PII detection patterns and redaction strategies
    - Defense-in-depth for MCP I/O operations

---

← [Camp 2: Gateway](camp2-gateway.md) | [Camp 4: Monitoring](camp4-monitoring.md) →
