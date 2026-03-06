---
hide:
  - toc
---

# Section 1: Understand the Vulnerabilities

You've deployed Camp 3's infrastructure and your MCP servers are running behind APIM with OAuth and Content Safety. Everything looks secure, right?

Not quite. In this section, you'll run two exploit scripts that reveal critical I/O security gaps hiding in plain sight -- attacks that Layer 1 (Content Safety) was never designed to catch.

!!! tip "Working Directory"
    All commands should be run from the `camps/camp3-io-security` directory:
    ```bash
    cd camps/camp3-io-security
    ```

## Exploit 1: Technical Injection Bypass

Azure AI Content Safety with Prompt Shields catches harmful content and AI-focused attacks like jailbreaks. But technical injection patterns (shell commands, SQL, path traversal) aren't AI manipulation attempts. Let's prove they pass through APIM.

The exploit script accepts either `sherpa` or `trails` as a parameter. Run both to see that neither MCP server is protected:

```bash
# Test the Sherpa MCP server (native MCP passthrough)
./scripts/1.1-exploit-injection.sh sherpa

# Test the Trail MCP server (APIM-synthesized MCP)
./scripts/1.1-exploit-injection.sh trails
```

The script sends three technical injection attacks against the MCP servers. Every one succeeds:

| Attack | Payload | Result |
|--------|---------|--------|
| Shell injection | `summit; cat /etc/passwd` | :material-alert: **200 OK** -- passes through |
| Path traversal | `../../etc/passwd` | :material-alert: **200 OK** -- not blocked |
| SQL injection | `' OR '1'='1` | :material-alert: **200 OK** -- not detected |

All attacks succeed on both servers. Content Safety isn't stopping them.

??? info "Why Content Safety misses these"
    Azure AI Content Safety has two detection capabilities:

    - **Category Detection** (hate, violence, sexual, self-harm) catches harmful content directed at humans.
    - **Prompt Shields** (jailbreak, prompt injection) catches AI manipulation attempts.

    What it doesn't catch:

    - **Shell injection** -- `; cat /etc/passwd` isn't trying to manipulate an AI
    - **SQL injection** -- `' OR '1'='1` is a database attack, not a prompt attack
    - **Path traversal** -- `../../etc/passwd` is a file system attack

    These are **traditional injection attacks** targeting backend systems, not AI models. They require **pattern-based detection** with regex and heuristics, which is exactly what Layer 2 provides.

## Exploit 2: PII Leakage in Responses

Both MCP servers have tools that return sensitive PII:

- **Trail MCP**: `get-permit-holder` returns permit holder details
- **Sherpa MCP**: `get_guide_contact` returns mountain guide contact info

Let's see what happens when you request this data. Run the PII exploit against both servers:

```bash
# Test both MCP servers (default)
./scripts/1.1-exploit-pii.sh

# Or test individually
./scripts/1.1-exploit-pii.sh trails
./scripts/1.1-exploit-pii.sh sherpa
```

??? example "Expected output: unredacted PII"
    For Trail MCP, this calls the `get-permit-holder` tool via MCP and returns:

    ```json
    {
      "permit_id": "TRAIL-2024-001",
      "holder_name": "John Smith",
      "email": "john.smith@example.com",
      "phone": "555-123-4567",
      "ssn": "123-45-6789",
      "address": "123 Mountain View Dr, Denver, CO 80202"
    }
    ```

    SSNs, email addresses, phone numbers, and physical addresses, all returned directly to the client with no redaction.

This is **MCP-03: Tool Poisoning (Data Exfiltration)**. Without output sanitization, PII passes directly to the client.

??? warning "Compliance implications"
    Exposing PII violates:

    - **GDPR** -- EU data protection regulation
    - **CCPA** -- California privacy law
    - **HIPAA** -- Healthcare data protection
    - **SOC 2** -- Trust service criteria

---

[Continue: Enable Layer 2 Security →](section2-layer2-security.md){ .md-button .md-button--primary }

← [Overview](index.md) | [Layer 2 Security →](section2-layer2-security.md)
