---
hide:
  - toc
---

# Camp 3: I/O Security

*Navigating the Treacherous I/O Pass*

![Security](../images/sherpa-security.png)

Welcome to **Camp 3**, where the terrain gets treacherous. You've secured your base camp with OAuth and set up Content Safety to catch the obvious dangers, but experienced climbers know that the most dangerous hazards are the ones you don't see coming. A crevasse hidden under fresh snow. A loose handhold that looks solid. A weather pattern that shifts without warning.

In the MCP world, these hidden dangers are **technical injection attacks**—shell commands disguised as location queries, SQL payloads masquerading as search terms, path traversal attempts that look like innocent file requests. Content Safety won't catch them because they're not "harmful content" to an AI model. They're surgical strikes targeting your backend systems.

And there's another danger on this route: **data leaking out**. Your APIs might be returning SSNs, phone numbers, and addresses to any client that asks nicely. Content Safety only watches the door going *in*—it doesn't check what's walking *out*.

Camp 3 adds **Layer 2 security**: Azure Functions that perform advanced input validation and output sanitization. You'll witness these attacks succeed, then deploy the defenses that stop them cold.

This camp follows the same **"vulnerable → exploit → fix → validate"** methodology, but focuses on the data flowing through your MCP servers rather than access control.

**Tech Stack:** Python, MCP, Azure Functions, Azure AI Services (Language), Azure API Management  
**Primary Risks:** [MCP-05](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp05-command-injection/) (Command Injection), [MCP-06](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp06-prompt-injection/) (Prompt Injection), [MCP-03](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp03-tool-poisoning/) (Tool Poisoning), [MCP-10](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp10-context-oversharing/) (Context Over-Sharing)

## What You'll Learn

Building on Camp 2's gateway foundation, you'll master I/O security for MCP servers:

!!! info "Learning Objectives"
    - Understand why Layer 1 (Content Safety) isn't sufficient for technical injection attacks
    - Deploy Azure Functions as security middleware for APIM
    - Implement technical injection pattern detection (shell, SQL, path traversal)
    - Configure PII detection and redaction using Azure AI Language
    - Add credential scanning to prevent secret leakage
    - Understand defense-in-depth architecture for I/O security

## Why Layer 2 Security?

**The Problem:** Azure AI Content Safety (Layer 1) with Prompt Shields is excellent at detecting harmful content and AI-focused attacks like jailbreaks. But it's not designed for **technical injection patterns**:

- **Shell injection** — "summit; cat /etc/passwd" isn't harmful content to an AI model
- **SQL injection** — "' OR '1'='1" doesn't trigger hate/violence/jailbreak filters
- **Path traversal** — "../../etc/passwd" is just a file path, not a prompt attack
- **PII in responses** — Content Safety only checks inputs, not outputs

!!! info "What About Prompt Injection?"
    Content Safety's **Prompt Shields** (enabled via `shield-prompt="true"` in Camp 2) does catch many prompt injection attacks—especially jailbreaks that try to manipulate AI behavior. However, technical injection patterns like shell commands and SQL aren't AI manipulation attempts; they're traditional injection attacks that Prompt Shields isn't designed to detect.

**The Solution:** Add a second layer of security with specialized Azure Functions:

| Layer | Component | Purpose | Speed |
|-------|-----------|---------|-------|
| 1 | Content Safety | Harmful content, jailbreaks, prompt injection | ~30ms |
| 2 | `input_check` Function | Technical injection patterns (shell, SQL, path) | ~50ms |
| 2 | `sanitize_output` Function | PII redaction, credential scanning | ~100ms |
| 3 | Server-side validation | Last line of defense (Pydantic) | In-server |

Together, these layers provide comprehensive protection for MCP I/O operations.

---

## Prerequisites

Before starting Camp 3, ensure you have the required tools installed.

!!! info "Prerequisites Guide"
    See the **[Prerequisites page](../prerequisites.md)** for detailed installation instructions, verification steps, and troubleshooting.

**Quick checklist for Camp 3:**

:material-check: Azure subscription with Contributor access  
:material-check: Azure CLI (authenticated)  
:material-check: Azure Developer CLI - azd (authenticated)  
:material-check: Docker (installed and running)  
:material-check: Azure Functions Core Tools (for function deployment)  
:material-check: Completed Camp 2 (recommended for OAuth context)  

**Verify your setup:**
```bash
az account show && azd version && docker --version && func --version
```

---

## Getting Started

### Clone the Workshop Repository

If you haven't already cloned the repository (from a previous camp), do so now:

```bash
git clone https://github.com/Azure-Samples/sherpa.git
cd sherpa
```

Navigate to the Camp 3 directory:

```bash
cd camps/camp3-io-security
```

---

## Architecture

Camp 3 deploys a layered security architecture where APIM orchestrates inbound security checks, while output sanitization strategy varies by backend type.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              APIM Gateway                                   │
│                                                                             │
│     ┌─────────────────────────────┐       ┌─────────────────────────────┐   │
│     │      sherpa-mcp             │       │      trail-mcp              │   │
│     │   (real MCP proxy)          │       │   (synthesized MCP)         │   │
│     │                             │       │                             │   │
│     │  INBOUND:                   │       │  INBOUND:                   │   │
│     │   • OAuth validation        │       │   • OAuth validation        │   │
│     │   • Content Safety (L1)     │       │   • Content Safety (L1)     │   │
│     │   • input_check (L2)        │       │   • input_check (L2)        │   │
│     │                             │       │                             │   │
│     │  OUTBOUND:                  │       │  OUTBOUND:                  │   │
│     │   • (none - server-side)    │       │   • (none - see trail-api)  │   │
│     └──────────────┬──────────────┘       └──────────────┬──────────────┘   │
│                    │                                     │                  │
│                    │                      ┌──────────────┴──────────────┐   │
│                    │                      │      trail-api              │   │
│                    │                      │   (REST API backend)        │   │
│                    │                      │                             │   │
│                    │                      │  OUTBOUND:                  │   │
│                    │                      │   • sanitize_output         │   │
│                    │                      └──────────────┬──────────────┘   │
│                    │                                     │                  │
└────────────────────┼─────────────────────────────────────┼──────────────────┘
                     │                                     ▼
                     ▼                          ┌─────────────────────┐
          ┌─────────────────────┐               │  Trail Container    │
          │  Sherpa Container   │               │  App (REST API)     │
          │  App (Python MCP)   │               └─────────────────────┘
          │                     │
          │  SERVER-SIDE:       │
          │   • sanitize_output │
          └─────────────────────┘
```

**Two MCP Server Patterns with Different Sanitization Strategies:**

| Server | Type | Output Sanitization | Where | Why |
|--------|------|---------------------|-------|-----|
| Sherpa MCP | Native passthrough | ✓ Server-side | In MCP server | Streamable HTTP uses SSE format |
| Trail MCP | APIM-synthesized | ✗ Not possible | N/A | APIM controls SSE stream |
| Trail API | REST backend | ✓ APIM outbound | APIM policy | JSON response, then wrapped in SSE |

!!! info "Why Server-Side Sanitization for Sherpa MCP?"
    **The Challenge:** FastMCP's Streamable HTTP transport always returns `Content-Type: text/event-stream`, even for instant, complete responses. APIM outbound policies cannot reliably distinguish between:
    
    - A complete response delivered as an SSE event (can be sanitized)
    - A long-running stream that will timeout (should pass through)
    
    **The Solution:** Move sanitization **inside the MCP server**. The `get_guide_contact` tool calls the sanitize-output Azure Function directly before returning data, ensuring PII is always redacted regardless of transport format.
    
    **For trail-api:** Standard REST responses use `application/json`, so APIM outbound sanitization works normally. The sanitized JSON is then wrapped in SSE events by the trail-mcp API.

---

## Understanding MCP Transports

Before implementing I/O security, it's important to understand how MCP traffic flows through APIM. This affects **what you can inspect** and **where security checks can run**.

### Streamable HTTP: The MCP Transport

The MCP specification defines **Streamable HTTP** as the standard transport for remote MCP servers:

| Aspect | How It Works |
|--------|--------------|
| **Request** | Standard HTTP POST to `/mcp` endpoint |
| **Request Body** | JSON-RPC 2.0 payload |
| **Response** | Either single JSON **or** SSE stream (server decides) |

```
Client                                                     MCP Server
   │                                                            │
   │  POST /mcp                                                 │
   │  Content-Type: application/json                            │
   │  {"jsonrpc": "2.0", ...}                                   │
   │ ──────────────────────────────────────────────────────────>│
   │                                                            │
   │  Response (one of):                                        │
   │  A) Content-Type: application/json     ← Single response   │
   │  B) Content-Type: text/event-stream    ← SSE stream        │
   │ <──────────────────────────────────────────────────────────│
```

### Two MCP Patterns in This Workshop

This workshop demonstrates two ways to expose MCP functionality through APIM:

| Pattern | Backend | APIM Role | Streaming Handled By |
|---------|---------|-----------|---------------------|
| **Native MCP** | sherpa-mcp-server (FastMCP) | Passthrough proxy | Backend server |
| **Synthesized MCP** | trail-api (REST) | Protocol translator | APIM |

**Native MCP (sherpa-mcp-server):**
```
Client ─── POST /mcp ───► APIM ───► sherpa-mcp-server
                          │              │
                    Proxies MCP    Handles MCP protocol
                    traffic        Returns JSON or SSE
```

**Synthesized MCP (trail-api):**
```
Client ─── POST /mcp ───► APIM ───► trail-api (REST)
                          │              │
                    Translates      Standard REST API
                    MCP ↔ REST      No MCP awareness
```

!!! tip "When to Use Each Pattern"
    - **Native MCP**: Building new AI-first services with full MCP protocol support
    - **Synthesized MCP**: Exposing existing REST APIs to AI agents without code changes

### Why This Matters for Output Sanitization

The outbound policy we'll implement reads the response body:

```xml
<set-body>@(context.Response.Body.As<string>(preserveContent: true))</set-body>
```

This works **only when the response is complete before the outbound policy runs**.

| Response Type | `Body.As<string>()` | Outbound Sanitization |
|---------------|---------------------|----------------------|
| **Single JSON** | Returns complete body | Works |
| **SSE Stream** | May timeout or get partial data | Unreliable |

??? info "Deep Dive: Why Server-Side Sanitization for MCP Servers"

    ### The FastMCP Content-Type Challenge
    
    FastMCP's Streamable HTTP transport **always returns `Content-Type: text/event-stream`**, even for instant, complete responses like `get_weather`. This creates a problem for APIM outbound policies:
    
    ```xml
    <!-- This approach is UNRELIABLE for MCP servers -->
    <choose>
        <when condition="@(!context.Response.Headers.GetValueOrDefault('Content-Type','').Contains('event-stream'))">
            <!-- Sanitize JSON responses -->
        </when>
        <!-- Skip SSE streams -->
    </choose>
    ```
    
    The Content-Type check skips sanitization for **all** MCP responses, even ones that complete instantly and could be sanitized.
    
    !!! warning "Timeout-Based Approach Also Has Issues"
        An alternative is to attempt sanitization with a timeout, letting true streams fail gracefully. However, this adds latency to every request and the timeout tuning is fragile.

    ---

    ### The Server-Side Solution
    
    For native MCP servers (sherpa-mcp), we move sanitization **inside the server itself**:
    
    ```python
    @mcp.tool()
    async def get_guide_contact(guide_id: str) -> str:
        guide = get_guide_data(guide_id)
        raw_json = json.dumps(guide)
        
        # Sanitize PII before returning (server-side Layer 2)
        sanitized = await sanitize_output(raw_json)
        return sanitized
    ```
    
    The `sanitize_output()` function calls the same Azure Function that APIM would call, but from inside the server:
    
    - Works regardless of transport format (JSON or SSE)
    - No timeout tuning required
    - PII is redacted before it ever leaves the server
    - Fail-open strategy maintains availability

    ---

    ### Why trail-api Uses APIM Outbound Sanitization
    
    For synthesized MCP (trail-mcp → trail-api), the situation is different:
    
    - **trail-api** is a standard REST API returning `application/json`
    - APIM outbound policies can read and modify JSON responses
    - The sanitized JSON is then wrapped in SSE events by trail-mcp
    
    This works because APIM sees a complete JSON response **before** generating the SSE stream.

    ---

    ### Summary: Choose the Right Approach
    
    | Backend Type | Transport | Output Sanitization |
    |--------------|-----------|--------------------|
    | Native MCP (FastMCP) | Streamable HTTP (SSE) | Server-side |
    | REST API | JSON | APIM outbound policy |
    | Synthesized MCP | Streamable HTTP (SSE) | Sanitize the REST backend |

    ---

    ### Workshop Scripts Use Simple HTTP
    
    The workshop scripts use `curl` with synchronous HTTP POST requests:
    
    ```bash
    curl -X POST "$MCP_ENDPOINT/mcp" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc": "2.0", ...}'
    ```
    
    This works because **Streamable HTTP accepts standard POST requests** and can respond with either:
    
    - **Single JSON** (what the workshop scripts receive)
    - **SSE stream** (what a full MCP client like VS Code can handle)
    
    The server decides based on the operation. Simple tool calls return JSON; long-running operations could stream progress updates.

---

## The Ascent

Camp 3 follows a streamlined waypoint structure. Each waypoint demonstrates the vulnerability, applies the fix, and validates the result.

### Establish Camp

Before climbing through the waypoints, let's establish camp by deploying all Azure infrastructure and application code.

??? note "Deploy Camp 3"

    ### Full Deployment (Infrastructure + Code)

    This creates all the infrastructure and deploys the application code for Camp 3:

    ```bash
    cd camps/camp3-io-security
    azd up
    ```

    When prompted:

    - **Environment name:** Choose a name (e.g., `camp3-dev`)
    - **Subscription:** Select your Azure subscription
    - **Location:** Select your Azure region (e.g., `westus2`, `eastus`)

    ??? info "What gets deployed?"
        The `azd up` command provisions infrastructure AND deploys application code:

        **Infrastructure (~15 minutes):**

        - **API Management (Basic v2)** — MCP gateway with OAuth + Content Safety
        - **Container Registry** — For container images
        - **Container Apps Environment** — Hosts the MCP servers
        - **Azure Function App (Flex Consumption)** — For security functions
        - **Azure AI Services** — PII detection via Language API
        - **Content Safety (S0)** — Layer 1 content filtering
        - **Storage Account** — For Function App state
        - **Log Analytics** — Monitoring and diagnostics
        - **Managed Identities** — For APIM, Container Apps, and Functions

        **Application Code (~5 minutes):**

        - **Sherpa MCP Server** — Python MCP server deployed to Container Apps
        - **Trail API** — REST API with permit endpoints deployed to Container Apps
        - **Security Function** — Input check and output sanitization functions

        **Post-Provision Configuration:**

        - **Sherpa MCP API** — Native MCP passthrough to Container App
        - **Trail MCP API** — APIM-synthesized MCP from Trail REST API
        - **Trail REST API** — Backend for Trail MCP
        - **OAuth validation** — JWT validation with `mcp.access` scope on all MCP endpoints
        - **RFC 9728 PRM discovery** — Enables VS Code OAuth autodiscovery (see Camp 2 for details)
        - **Content Safety** — Layer 1 filtering on all APIs

        Note: The security function is deployed but **not yet wired** to APIM. You'll do that in Waypoint 1.2 after seeing why it's needed.

    **Expected time:** ~20 minutes

    When provisioning completes, save these values:

    ```bash
    # Display your deployment info
    azd env get-values | grep -E "APIM_GATEWAY_URL|FUNCTION_APP_URL|MCP_APP_CLIENT_ID"
    ```

---

## Waypoint 1.1: Understand the Vulnerabilities

In this waypoint, you'll see two critical I/O security gaps that Layer 1 (Content Safety) doesn't catch, then review the security function code that will fix them.

!!! tip "Working Directory"
    All commands should be run from the `camps/camp3-io-security` directory:
    ```bash
    cd camps/camp3-io-security
    ```

??? danger "Exploit 1: Technical Injection Bypass"

    ### The Problem: Content Safety Doesn't Catch Technical Injection Patterns

    Azure AI Content Safety with Prompt Shields catches harmful content and AI-focused attacks like jailbreaks. But technical injection patterns—shell commands, SQL, path traversal—aren't AI manipulation attempts. Let's prove they pass through APIM.

    The exploit script accepts either `sherpa` or `trails` as a parameter—try both to see that neither MCP server is protected:

    ```bash
    # Test the Sherpa MCP server (native MCP passthrough)
    ./scripts/1.1-exploit-injection.sh sherpa

    # Test the Trail MCP server (APIM-synthesized MCP)
    ./scripts/1.1-exploit-injection.sh trails
    ```

    The script sends technical injection attacks. Here's what you'll see when testing the Sherpa MCP server:

    **Test 1: Shell Injection**
    ```
    Location: "summit; cat /etc/passwd"
    ```
    Result: **200 OK** — Shell metacharacters pass through!

    **Test 2: Path Traversal**
    ```
    trail_id: "../../etc/passwd"
    ```
    Result: **200 OK** — Directory traversal isn't blocked!

    **Test 3: SQL Injection**
    ```
    query: "' OR '1'='1"
    ```
    Result: **200 OK** — SQL injection patterns aren't detected!

    All attacks succeed on both servers. Content Safety isn't stopping them.

    ??? info "Why Content Safety Misses These"
        Azure AI Content Safety has two detection capabilities:

        **Category Detection** (hate, violence, sexual, self-harm):
        Catches harmful content directed at humans.

        **Prompt Shields** (jailbreak, prompt injection):
        Catches AI manipulation attempts—instructions designed to make an AI behave differently.

        **What it doesn't catch:**

        - **Shell injection** — `; cat /etc/passwd` isn't trying to manipulate an AI
        - **SQL injection** — `' OR '1'='1` is a database attack, not a prompt attack
        - **Path traversal** — `../../etc/passwd` is a file system attack

        These are **traditional injection attacks** targeting backend systems, not AI models. They require **pattern-based detection** with regex and heuristics—which is exactly what Layer 2 provides.

??? danger "Exploit 2: PII Leakage in Responses"

    ### The Problem: Sensitive Data in API Responses

    Both MCP servers have tools that return sensitive PII:

    - **Trail MCP**: `get-permit-holder` returns permit holder details
    - **Sherpa MCP**: `get_guide_contact` returns mountain guide contact info

    ```bash
    # Test both MCP servers (default)
    ./scripts/1.1-exploit-pii.sh

    # Or test individually
    ./scripts/1.1-exploit-pii.sh trails
    ./scripts/1.1-exploit-pii.sh sherpa
    ```

    For Trail MCP, this calls the `get-permit-holder` tool via MCP:

    **Response (unredacted):**
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

    **This is MCP-03: Tool Poisoning (Data Exfiltration)**

    Without output sanitization, this PII passes directly to the client!

    ??? warning "Compliance Implications"
        Exposing PII violates:

        - **GDPR** — EU data protection regulation
        - **CCPA** — California privacy law
        - **HIPAA** — Healthcare data protection
        - **SOC 2** — Trust service criteria

---

## Waypoint 1.2: Enable Layer 2 Security

Now that you've seen the vulnerabilities, let's review the security function code and wire it into APIM.

??? success "Step 1: Review the Security Function Code"

    ### How We'll Fix It

    The security function was deployed during provisioning but isn't wired to APIM yet. Before we flip the switch, let's understand what it actually does, because the *how* matters as much as the *what*.

    **Function Location:** `camps/camp3-io-security/security-function/`

    #### Input Check Function (`/api/input-check`)

    The input check function uses a **hybrid detection approach**, and understanding why is key to building effective security.

    **The Problem with Single-Layer Detection:**

    - **Regex alone** catches known patterns fast (~1ms) but misses creative attacks. An attacker who writes "Disregard your previous directives" slips past a pattern matching "ignore.*instructions".
    - **AI alone** (like Prompt Shields) catches sophisticated semantic attacks but costs money per call and adds latency (~50ms).

    **The Hybrid Solution:** Check regex patterns *first*. If no known attack patterns are found, *then* call Prompt Shields for deeper analysis. This gives you speed for obvious attacks and intelligence for subtle ones.

    ```python
    # The two-phase detection flow in injection_patterns.py

    # Phase 1: Fast regex check (instant, free)
    result = check_patterns(text)
    if not result.is_safe:
        return result  # Known attack pattern - block immediately

    # Phase 2: AI-powered check (only if regex passed)
    result = await check_with_prompt_shields(texts)
    if not result.is_safe:
        return result  # Sophisticated attack detected by AI
    ```

    The regex patterns are organized by OWASP MCP risk category:

    ```python
    INJECTION_PATTERNS: dict[str, list[tuple[str, str]]] = {
        # MCP-05: Shell Injection - stops "summit; cat /etc/passwd"
        "shell_injection": [
            (r"[;&|`]", "Shell metacharacter detected"),
            (r"\$\([^)]+\)", "Command substitution pattern detected"),
            # ...
        ],

        # MCP-05: SQL Injection - stops "' OR '1'='1"
        "sql_injection": [
            (r"'\s*(OR|AND)\s+['\d]", "SQL boolean injection detected"),
            (r"UNION\s+(ALL\s+)?SELECT", "UNION-based SQL injection"),
            # ...
        ],

        # MCP-05: Path Traversal - stops "../../etc/passwd"
        "path_traversal": [
            (r"\.\./", "Directory traversal (../) detected"),
            (r"%2e%2e[%2f/\\]", "URL-encoded directory traversal"),
            # ...
        ],
    }
    ```

    Notice there's no `prompt_injection` category in the regex patterns—that's intentional! Prompt injection attacks are too creative for regex. They're handled entirely by Prompt Shields, which uses AI to understand *intent*, not just patterns.

    **Prompt Shields** calls the Azure AI Content Safety API to detect jailbreak attempts:

    ```python
    # From check_with_prompt_shields() - calls the REST API
    request_body = {
        "userPrompt": user_prompt,  # The text to analyze
        "documents": []              # Could include RAG context too
    }
    # Returns: { "userPromptAnalysis": { "attackDetected": true/false } }
    ```

    The function recursively extracts all string values from the MCP request body (tool arguments, resource URIs, prompt content) and returns:

    - `{"allowed": true}` — Safe to proceed
    - `{"allowed": false, "reason": "...", "category": "..."}` — Block with explanation

    #### Output Sanitization Function (`/api/sanitize-output`)

    While input checking stops attacks coming *in*, output sanitization protects sensitive data going *out*. This function chains two complementary techniques:

    **Step 1: PII Detection via Azure AI Language**

    Azure AI Language uses machine learning models trained on millions of documents to recognize PII in context. It knows that "John Smith" in "Dear John Smith" is a name, but "John Smith" in "John Smith & Sons Hardware" is probably a business.

    ```python
    def detect_and_redact_pii(text: str) -> PIIResult:
        """
        Calls Azure AI Language's PII detection endpoint.
        
        Detects: PersonName, Email, PhoneNumber, USSocialSecurityNumber,
                 Address, CreditCardNumber, DateOfBirth, and 40+ more...
        
        Returns text with entities replaced: "John Smith" → "[REDACTED-PersonName]"
        """
        result = client.recognize_pii_entities([text])[0]
        
        # Redact in reverse order to preserve character positions
        for entity in sorted(result.entities, key=lambda e: e.offset, reverse=True):
            redaction = f"[REDACTED-{entity.category}]"
            text = text[:entity.offset] + redaction + text[entity.offset + entity.length:]
    ```

    **Step 2: Credential Scanning via Regex**

    AI models aren't trained to recognize API keys or connection strings—those are arbitrary strings. So we use pattern matching for secrets:

    ```python
    def scan_and_redact(text: str) -> CredentialResult:
        """
        Pattern-based scanning for secrets that AI might miss:
        - API keys (Azure, AWS, GCP patterns)
        - Bearer tokens and JWTs
        - Connection strings with passwords
        - Private keys (RSA, SSH)
        """
    ```

    The two techniques complement each other: AI finds human-readable PII, regex finds machine-generated secrets.

    ??? tip "Explore the Code"
        Take a moment to explore the full implementation:

        ```bash
        # View the main function app
        security-function/function_app.py

        # View the hybrid detection logic
        security-function/shared/injection_patterns.py

        # View PII detection with Azure AI Language
        security-function/shared/pii_detector.py

        # View credential pattern scanning
        security-function/shared/credential_scanner.py
        ```

??? success "Step 2: Wire the Function to APIM"

    The security function is already deployed. Now connect it to APIM and enable server-side sanitization:

    ```bash
    ./scripts/1.2-enable-io-security.sh
    ```

    This script does **six things**:

    1. **Named Value** — Adds the function URL for policy use
    2. **Sherpa MCP Policy** — Input security (OAuth + Content Safety + input_check)
    3. **Trail MCP Policy** — Input security only (OAuth + Content Safety + input_check)
    4. **Trail API Policy** — Output sanitization (sanitize_output before SSE wrapping)
    5. **Enable Server-Side Sanitization** — Sets `SANITIZE_ENABLED=true` on sherpa-mcp-server
    6. **Wait for Deployment** — Polls until the new Container App revision is running

    !!! info "Why the Environment Variable Toggle?"
        The sherpa-mcp-server has server-side PII sanitization built in, but it's **disabled by default** (`SANITIZE_ENABLED=false`). This allows you to see the vulnerability in Section 1.1 before enabling the fix here. The script flips the toggle and waits for the Container App to redeploy.

    **Expected output:**
    ```
    ==========================================
    I/O Security Enabled!
    ==========================================
    
    Security Architecture:
    
      ┌─────────────────┐     ┌─────────────────┐
      │   sherpa-mcp    │     │   trail-mcp     │
      │ (real MCP proxy)│     │ (synthesized)   │
      │                 │     │                 │
      │  • OAuth        │     │  • OAuth        │
      │  • ContentSafety│     │  • ContentSafety│
      │  • Input Check  │     │  • Input Check  │
      │  • Output Sanit.│     │  (no outbound)  │
      │   (server-side) │     │                 │
      └────────┬────────┘     └────────┬────────┘
               │                       │
               │              ┌────────┴────────┐
               │              │   trail-api     │
               │              │  • Output Sanit.│
               │              │   (APIM policy) │
               │              └────────┬────────┘
               ▼                       ▼
         Container App          Container App
    ```

    !!! tip "Why the Split Architecture?"
        Synthesized MCP servers (trail-mcp) have APIM-controlled SSE streams that block outbound `Body.As<string>()` calls. By applying output sanitization to the underlying REST API (trail-api), we sanitize the response *before* APIM wraps it in SSE events.

    ??? info "What the APIM Policy Looks Like"

        **Inbound Policy (Layer 2 Input Check):**

        ```xml
        <inbound>
            <!-- Layer 1: Prompt Shields via Policy Fragment -->
            <include-fragment fragment-id="mcp-content-safety" />

            <!-- Layer 2: Advanced Input Check (NEW) -->
            <send-request mode="new" response-variable-name="inputCheck">
                <set-url>{{function-app-url}}/api/input-check</set-url>
                <set-method>POST</set-method>
                <set-body>@(context.Request.Body.As<string>())</set-body>
            </send-request>
            <choose>
                <when condition="@(!((JObject)inputCheck.Body.As<JObject>())["allowed"].Value<bool>())">
                    <return-response>
                        <set-status code="400" reason="Security Check Failed" />
                        <set-body>@{
                            var result = inputCheck.Body.As<JObject>();
                            return new JObject(
                                new JProperty("error", "Request blocked by security filter"),
                                new JProperty("reason", result["reason"]),
                                new JProperty("category", result["category"])
                            ).ToString();
                        }</set-body>
                    </return-response>
                </when>
            </choose>
        </inbound>
        ```

        **Outbound Policy (for trail-api only):**

        This policy is applied to `trail-api` (REST backend for synthesized MCP). It sanitizes PII in REST responses before APIM wraps them in SSE events:

        ```xml
        <outbound>
            <!-- Layer 2: PII Redaction -->
            <send-request mode="new" response-variable-name="sanitized" timeout="10" ignore-error="true">
                <set-url>{{function-app-url}}/api/sanitize-output</set-url>
                <set-method>POST</set-method>
                <set-body>@(context.Response.Body.As<string>(preserveContent: true))</set-body>
            </send-request>
            <choose>
                <when condition="@(context.Variables.ContainsKey(\"sanitized\") && ((IResponse)context.Variables[\"sanitized\"]).StatusCode == 200)">
                    <set-body>@(((IResponse)context.Variables["sanitized"]).Body.As<string>())</set-body>
                </when>
                <!-- On failure, pass through original (fail open) -->
            </choose>
        </outbound>
        ```

        !!! info "sherpa-mcp uses Server-Side Sanitization"
            For `sherpa-mcp` (native MCP server), output sanitization happens **inside the server**, not in APIM. The `get_guide_contact` tool calls the sanitize-output Azure Function directly before returning data.
            
            This approach is necessary because FastMCP's Streamable HTTP transport always uses `Content-Type: text/event-stream`, making APIM outbound policies unreliable.

        !!! warning "trail-mcp has NO outbound policy"
            For `trail-mcp` (synthesized MCP), there is no outbound sanitization policy. APIM controls the SSE stream lifecycle, causing `Body.As<string>()` to block indefinitely.
            
            Instead, output sanitization is applied to `trail-api`, which processes the REST response *before* APIM wraps it in SSE events.

---

## Waypoint 1.3: Validate the Security

Confirm that both vulnerabilities are now fixed by running the same exploits from Waypoint 1.1.

??? note "Validate 1: Injection Attacks Blocked"

    Run the same injection attacks from Waypoint 1.1:

    ```bash
    ./scripts/1.3-validate-injection.sh sherpa
    ```

    **Expected results:**

    **Test 1: Shell Injection**
    ```
    Status: 400 Bad Request
    Response: {
      "error": "Request blocked by security filter",
      "reason": "Shell metacharacter detected",
      "category": "shell_injection"
    }
    ```

    **Test 2: Path Traversal**
    ```
    Status: 400 Bad Request
    Response: {
      "error": "Request blocked by security filter",
      "reason": "Directory traversal (../) detected",
      "category": "path_traversal"
    }
    ```

    **Test 3: SQL Injection**
    ```
    Status: 400 Bad Request
    Response: {
      "error": "Request blocked by security filter",
      "reason": "SQL boolean injection detected",
      "category": "sql_injection"
    }
    ```

    **Test 4: Safe Request (should pass)**
    ```
    Status: 200 OK
    ```

    You can also validate the Trail MCP server:

    ```bash
    ./scripts/1.3-validate-injection.sh trails
    ```

    Layer 2 is successfully detecting and blocking injection attacks!

??? note "Validate 2: PII Redacted in Responses"

    The validation script tests PII redaction on **both** MCP servers:

    ```bash
    ./scripts/1.3-validate-pii.sh
    ```

    **Test 1: Trail API (trail-mcp → trail-api sanitization)**
    ```json
    {
      "permit_id": "TRAIL-2024-001",
      "holder_name": "[REDACTED-PersonName]",
      "email": "[REDACTED-Email]",
      "phone": "[REDACTED-PhoneNumber]",
      "ssn": "[REDACTED-USSocialSecurityNumber]",
      "address": "[REDACTED-Address]"
    }
    ```

    **Test 2: Sherpa MCP (direct outbound sanitization)**
    ```json
    {
      "guide_id": "guide-002",
      "name": "[REDACTED-PersonName]",
      "email": "[REDACTED-Email]",
      "phone": "[REDACTED-PhoneNumber]",
      "ssn": "[REDACTED-USSocialSecurityNumber]",
      "address": "[REDACTED-Address]"
    }
    ```

    Both responses have the same structure, but all PII is redacted! This validates that:
    
    - **sherpa-mcp**: Output sanitization works in the MCP policy (real MCP proxy)
    - **trail-mcp**: Output sanitization works via trail-api (synthesized MCP)

    ??? tip "How PII Detection Works"
        Azure AI Language's PII detection identifies:

        | Category | Examples |
        |----------|----------|
        | PersonName | John Smith, Jane Doe |
        | Email | john@example.com |
        | PhoneNumber | 555-123-4567, (555) 123-4567 |
        | USSocialSecurityNumber | 123-45-6789 |
        | Address | 123 Main St, Denver, CO 80202 |
        | CreditCardNumber | 4111-1111-1111-1111 |
        | And many more... | DateOfBirth, IPAddress, etc. |

        The `sanitize_output` function calls Azure AI Language, then replaces each detected entity with `[REDACTED-Category]`.

---

## What You Built

Congratulations! You've implemented defense-in-depth I/O security for MCP servers with a **split architecture** that handles both real and synthesized MCP patterns:

```
                   Request Flow
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
┌───────────────────┐           ┌───────────────────┐
│   sherpa-mcp      │           │   trail-mcp       │
│ (real MCP proxy)  │           │ (synthesized)     │
├───────────────────┤           ├───────────────────┤
│ INBOUND:          │           │ INBOUND:          │
│  • Content Safety │           │  • Content Safety │
│  • input_check    │           │  • input_check    │
├───────────────────┤           ├───────────────────┤
│ SERVER-SIDE:      │           │ OUTBOUND:         │
│  • sanitize_output│           │  (none)           │
│   (SANITIZE_      │           │                   │
│    ENABLED=true)  │           │                   │
└─────────┬─────────┘           └─────────┬─────────┘
          │                               │
          │                     ┌─────────┴─────────┐
          │                     │   trail-api       │
          │                     │ (REST backend)    │
          │                     ├───────────────────┤
          │                     │ OUTBOUND:         │
          │                     │  • sanitize_output│
          │                     │   (APIM policy)   │
          │                     └─────────┬─────────┘
          ▼                               ▼
    Container App                   Container App
```

**Key Insight**: Native MCP servers using Streamable HTTP (like sherpa-mcp with FastMCP) always return `Content-Type: text/event-stream`, making APIM outbound policies unreliable. The solution is **server-side sanitization**, where the MCP server calls the sanitize-output Function directly before returning data, controlled by the `SANITIZE_ENABLED` environment variable. For REST APIs (like trail-api), APIM outbound policies work normally because the response is `application/json`.

---

## Security Controls Summary

| Control | What It Does | Applied To | OWASP Risk Mitigated |
|---------|--------------|------------|----------------------|
| **OAuth (mcp.access scope)** | Token validation with scope check | All APIs | MCP-01 (Authentication) |
| **Content Safety (L1)** | Harmful content detection | All APIs | MCP-06 (partial) |
| **input_check (L2)** | Prompt/shell/SQL/path injection | All APIs | MCP-05, MCP-06 |
| **sanitize_output (L2)** | PII redaction, credential scanning | sherpa-mcp (server-side), trail-api (APIM) | MCP-03, MCP-10 |
| **Server validation (L3)** | Pydantic schemas, regex patterns | MCP servers | Defense in depth |

---

## Key Learnings

!!! success "Defense in Depth"
    **No single layer catches everything:**

    - **Content Safety** — Great for hate/violence, misses injection
    - **Regex patterns** — Great for injection, misses semantic attacks
    - **AI detection** — Great for PII, needs training data
    - **Server validation** — Last resort, but attackers are inside

    **Layer them together** for comprehensive protection.

!!! success "MCP Architecture Matters"
    **Real vs Synthesized MCP servers require different sanitization strategies:**

    - **Real MCP** (sherpa-mcp): FastMCP always uses `text/event-stream` → **server-side sanitization**
    - **Synthesized MCP** (trail-mcp): APIM controls SSE stream → sanitize the REST backend instead
    - **REST API** (trail-api): Standard JSON responses → **APIM outbound sanitization**

    **Key Insight**: Don't assume APIM outbound policies can modify all response types. Streamable HTTP's SSE format requires sanitization to happen before the response enters the transport layer.

!!! success "Fail Open vs Fail Closed"
    The `sanitize_output` function **fails open** — if Azure AI Language is unavailable, the original response passes through. This prioritizes availability over security.

    In high-security environments, consider **failing closed** instead:

    ```python
    if pii_result.error:
        # Fail closed: return error instead of original
        return func.HttpResponse(
            '{"error": "PII check unavailable"}',
            status_code=503
        )
    ```

??? info "Understanding Fail-Open: A Security Trade-off"

    When the `sanitize_output` function can't reach Azure AI Language (network issue, quota exceeded, service outage), it has two choices:

    **Fail Open (current behavior):**
    - Return the original response unchanged
    - Users get their data, but PII might slip through
    - Prioritizes **availability** over security

    **Fail Closed (alternative):**
    - Return an error (503 Service Unavailable)
    - Users can't proceed until the service recovers
    - Prioritizes **security** over availability

    **Which should you choose?**

    It depends on your threat model and business requirements:

    | Scenario | Recommendation |
    |----------|----------------|
    | Public API with sensitive data | Fail closed - block unknown responses |
    | Internal tool with low PII risk | Fail open - prioritize uptime |
    | Healthcare/Financial data | Fail closed - compliance requires it |
    | Demo/Workshop environment | Fail open - learning trumps security |

    The Camp 3 function fails open because we're in a learning environment. In production, you'd likely want fail-closed for endpoints that handle sensitive data.

    **To implement fail-closed**, change the exception handler:

    ```python
    except Exception as e:
        logging.error(f"Sanitization failed: {e}")
        # Fail closed: return error instead of original
        return func.HttpResponse(
            json.dumps({"error": "Security check unavailable", "retry": True}),
            status_code=503,
            mimetype="application/json"
        )
    ```

!!! success "Pattern Maintenance"
    Injection patterns evolve. The `injection_patterns.py` file should be:

    - **Regularly updated** with new attack patterns
    - **Tested** against known bypass techniques
    - **Tuned** to minimize false positives
    - **Documented** with OWASP risk mappings

---

## Server-Side Validation (Layer 3)

The MCP servers in Camp 3 include Pydantic validation as the last line of defense:

```python
from pydantic import BaseModel, Field

class PermitRequest(BaseModel):
    trail_id: str = Field(..., pattern=r'^[a-z]+-[a-z]+$')
    hiker_name: str = Field(..., min_length=2, max_length=100)
    hiker_email: str = Field(..., pattern=r'^[a-zA-Z0-9._%+-]+@...')
    planned_date: str = Field(..., pattern=r'^\d{4}-\d{2}-\d{2}$')
    group_size: int = Field(default=1, ge=1, le=12)
```

This validation runs **inside the MCP server** — if an attacker bypasses Layers 1 and 2, Pydantic still rejects malformed input.

---

## Cleanup

When you're done with Camp 3, remove all Azure resources:

```bash
# Delete all resources
azd down --force --purge
```

**Optional:** Delete the Entra ID applications:

```bash
# Get app IDs
MCP_APP_ID=$(azd env get-value MCP_APP_CLIENT_ID)
APIM_APP_ID=$(azd env get-value APIM_CLIENT_APP_ID)

# Delete apps
az ad app delete --id $MCP_APP_ID
az ad app delete --id $APIM_APP_ID
```

---

## What's Next?

!!! success "Camp 3 Complete!"
    You've implemented comprehensive I/O security for MCP servers!

**Continue your ascent:**

- **[Camp 4: Monitoring & Response](camp4-monitoring.md)** — Detect and respond to security incidents with Azure Monitor

**Or dive deeper:**

- [Azure AI Language PII Detection](https://learn.microsoft.com/azure/ai-services/language-service/personally-identifiable-information/overview)
- [OWASP Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Injection_Prevention_Cheat_Sheet.html)
- [Azure Functions Python Developer Guide](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)

---

← [Camp 2: Gateway](camp2-gateway.md) | [Camp 4: Monitoring](camp4-monitoring.md) →
