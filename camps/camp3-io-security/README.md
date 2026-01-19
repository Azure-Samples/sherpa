# Camp 3: I/O Security

> **Looking for the workshop?** This README is a quick reference for the codebase. For the full step-by-step workshop guide, visit: **[Camp 3: I/O Security Workshop](https://azure-samples.github.io/sherpa/camps/camp3-io-security/)**

---

> *"Test every foothold before trusting your weight to it"* - Validate inputs at every layer, and never expose sensitive data in outputs.

Implement defense-in-depth I/O security for MCP servers, including advanced injection detection, PII redaction, and credential scanning using Azure Functions and Azure AI Services.

## Overview

- **Difficulty:** Advanced
- **Prerequisites:** Azure subscription, completed Camp 2 (recommended)
- **Tech Stack:** Python, MCP, Azure Functions, Azure AI Services (Language), Azure API Management
- **Estimated Time:** 90 minutes

## Workshop Methodology

Camp 3 follows the **vulnerable -> exploit -> fix -> validate** pattern:

1. **Deploy Vulnerable**: Start with Layer 1 security only (Content Safety)
2. **Exploit**: Demonstrate advanced attacks that bypass Layer 1
3. **Fix**: Deploy Layer 2 security (Azure Functions)
4. **Validate**: Confirm the layered defense works

## What You'll Learn

- Deploy Azure Functions as security middleware for APIM
- Implement advanced injection pattern detection (prompt, shell, SQL, path traversal)
- Configure PII detection and redaction using Azure AI Language
- Add credential scanning to prevent secret leakage
- Understand defense-in-depth architecture for I/O security

## OWASP MCP Risks Addressed

| Risk | Description | How We Address It | Live Exploit? |
|------|-------------|-------------------|---------------|
| MCP-05 | Command Injection | input_check detects shell/SQL/path traversal patterns | No (detection only) |
| MCP-06 | Prompt Injection | input_check detects instruction override patterns | Yes |
| MCP-03 | Tool Poisoning | output_sanitize prevents data exfiltration via PII/cred redaction | Yes (PII leakage) |

## Quick Start

\`\`\`bash
# Clone and navigate
cd camps/camp3-io-security

# Deploy infrastructure (~15 minutes)
azd provision

# Follow the waypoint scripts
./scripts/1.1-exploit-injection.sh   # See injection bypass Layer 1
./scripts/1.1-exploit-pii.sh         # See PII leakage

./scripts/1.2-deploy-function.sh     # Deploy security function
./scripts/1.2-enable-io-security.sh  # Wire function to APIM

./scripts/1.3-validate-injection.sh  # Confirm injection blocked
./scripts/1.3-validate-pii.sh        # Confirm PII redacted
\`\`\`

## Architecture

\`\`\`
+-----------------------------------------------------------------------------+
|                              APIM Gateway                                    |
|  +------------------------------------------------------------------------+ |
|  | INBOUND                                                                 | |
|  |  1. OAuth validation (pre-configured)                                   | |
|  |  2. Rate limiting                                                       | |
|  |  3. llm-content-safety <- Layer 1: catches obvious attacks              | |
|  |  4. -> Azure Function (input_check) <- Layer 2: advanced patterns       | |
|  +------------------------------------------------------------------------+ |
|                                    |                                         |
|                                    v                                         |
|            +------------------------------------------+                      |
|            |   Sherpa MCP Server  |  Trail REST API   |                      |
|            |   (Native MCP)       |  (MCP via APIM)   |                      |
|            +------------------------------------------+                      |
|                                    |                                         |
|                                    v                                         |
|  +------------------------------------------------------------------------+ |
|  | OUTBOUND                                                                | |
|  |  1. -> Azure Function (sanitize_output) <- PII redaction                | |
|  +------------------------------------------------------------------------+ |
+-----------------------------------------------------------------------------+
\`\`\`

### Layer Responsibilities

| Layer | Component | Purpose | Pre-deployed? |
|-------|-----------|---------|---------------|
| 1 | APIM \`llm-content-safety\` | Fast broad filtering (~30ms) | Yes |
| 2 | Azure Function \`input_check\` | Advanced injection patterns | No (Camp 3 focus) |
| 2 | Azure Function \`sanitize_output\` | PII redaction, credential scanning | No (Camp 3 focus) |
| 3 | Server-side validation | Last line of defense (Pydantic) | Documentation only |

## Waypoint Summary

### Waypoint 1.1: Understand the Vulnerability (Exploit)

| Script | Description |
|--------|-------------|
| \`1.1-exploit-injection.sh\` | Send advanced injection that bypasses llm-content-safety |
| \`1.1-exploit-pii.sh\` | Call get_permit_holder, see PII in response |

### Waypoint 1.2: Deploy Security Function (Fix)

| Script | Description |
|--------|-------------|
| \`1.2-deploy-function.sh\` | Deploy Azure Function with input_check and sanitize_output |
| \`1.2-enable-io-security.sh\` | Update APIM policy to call the Function |

### Waypoint 1.3: Validate Security (Validate)

| Script | Description |
|--------|-------------|
| \`1.3-validate-injection.sh\` | Same attack, now blocked with 400 response |
| \`1.3-validate-pii.sh\` | Same call, PII now redacted |

## Project Structure

\`\`\`
camps/camp3-io-security/
├── azure.yaml                      # azd configuration
├── README.md
├── infra/
│   ├── main.bicep                  # Base infrastructure
│   ├── modules/                    # Shared Bicep modules
│   ├── policies/
│   │   ├── base-oauth-contentsafety.xml    # Initial state (Layer 1 only)
│   │   └── full-io-security.xml            # After fix (Layer 1 + 2)
│   └── waypoints/
│       └── 1.2-enable-function.bicep       # Wire Function to APIM
├── servers/
│   ├── sherpa-mcp-server/          # MCP server (FastMCP)
│   └── trail-api/                  # REST API with get_permit_holder
├── security-function/              # Azure Function App
│   ├── function_app.py
│   ├── input_check.py              # Advanced injection detection
│   ├── output_sanitize.py          # PII redaction + credential scanning
│   ├── shared/
│   │   ├── injection_patterns.py
│   │   ├── pii_detector.py
│   │   └── credential_scanner.py
│   ├── requirements.txt
│   ├── host.json
│   └── tests/
├── scripts/
│   ├── hooks/
│   │   ├── preprovision.sh
│   │   └── postprovision.sh
│   └── *.sh                        # Waypoint scripts
└── pyproject.toml
\`\`\`

## Resources Deployed

| Resource | SKU | Purpose | Est. Cost |
|----------|-----|---------|-----------|
| Azure AI Services | S0 | PII detection (Language API) | ~\$1/1K requests |
| Azure Function App | Consumption | Security functions | ~\$0.20/1M executions |
| APIM | Basic v2 | Gateway (from base deployment) | Included |
| Content Safety | S0 | llm-content-safety backend | ~\$1/1K requests |
| Container Apps | Consumption | Hosts MCP servers | ~\$0.10/hr active |

## Troubleshooting

### Common Issues

**Function deployment fails**
- Ensure Python 3.11+ is installed
- Check that \`security-function/requirements.txt\` has all dependencies

**PII detection returns empty**
- Verify Azure AI Services endpoint is set correctly
- Check managed identity has Cognitive Services User role

**Injection patterns not detected**
- Patterns are case-insensitive but may need tuning
- Check the logs in Application Insights

**APIM policy update fails**
- Ensure Function App is deployed and healthy
- Verify the function URL is accessible from APIM

## Security Function Details

### input_check Endpoint

Detects injection patterns organized by OWASP MCP risk:

- **MCP-06 Prompt Injection**: AI instruction manipulation patterns
- **MCP-05 Command Injection**: Shell metacharacters, command substitution
- **MCP-05 SQL Injection**: Quote escapes, UNION SELECT, comment terminators
- **MCP-05 Path Traversal**: \`../\`, encoded variants, sensitive file paths

### sanitize_output Endpoint

Protects against data exfiltration:

- **PII Detection**: Uses Azure AI Language to identify and redact PII
- **Credential Scanning**: Regex patterns for API keys, passwords, JWTs, secrets

## Cleanup

\`\`\`bash
# Remove all Azure resources
azd down --force --purge

# Clean up Entra ID app (optional)
az ad app delete --id \$(azd env get-value MCP_APP_CLIENT_ID)
\`\`\`

## Next Steps

After completing Camp 3:
- **Camp 4:** Monitoring & Response - Detect and respond to security incidents
