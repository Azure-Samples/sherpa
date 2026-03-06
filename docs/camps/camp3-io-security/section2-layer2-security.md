---
hide:
  - toc
---

# Section 2: Enable Layer 2 Security

Now that you've seen the vulnerabilities, let's wire the security function into APIM and then look under the hood at how it works.

## Step 1: Wire the Function to APIM

The security function was deployed during provisioning but isn't connected to APIM yet. Let's flip the switch. Run the enable script to wire everything together:

```bash
./scripts/1.2-enable-io-security.sh
```

This script connects the security function to both MCP servers in APIM. After it runs, **sherpa-mcp** and **trail-mcp** both get inbound input checking (injection detection + Prompt Shields), and outbound responses are sanitized for PII and credentials before reaching the client.

Once complete, every request and response flows through the security function:

```
  Client
    │
    ▼
  APIM (inbound) ──▶ /api/input-check
    │                  • Regex patterns (instant, free)
    │                  • Prompt Shields AI (if regex passes)
    │ ✓ allowed        ✗ Block unsafe requests
    ▼
  MCP Server
    │
    │ response
    ▼
  (outbound) ───────▶ /api/sanitize-output
    │                  • PII redaction (Azure AI Language)
    │ sanitized        • Credential scanning (regex)
    ▼
  Client
```

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

    ??? info "sherpa-mcp uses Server-Side Sanitization"
        For `sherpa-mcp` (native MCP server), output sanitization happens **inside the server**, not in APIM. The `get_guide_contact` tool calls the sanitize-output Azure Function directly before returning data.
        
        This approach is necessary because FastMCP's Streamable HTTP transport always uses `Content-Type: text/event-stream`, making APIM outbound policies unreliable.

    ??? warning "trail-mcp has NO outbound policy"
        For `trail-mcp` (synthesized MCP), there is no outbound sanitization policy. APIM controls the SSE stream lifecycle, causing `Body.As<string>()` to block indefinitely.
        
        Instead, output sanitization is applied to `trail-api`, which processes the REST response *before* APIM wraps it in SSE events.

---

## Step 2: Under the Hood -- How the Security Function Works

The security function is now wired up, and you'll validate it in the next section. But if you're curious about *how* it actually detects attacks and redacts PII, this is the deep dive.

**Function location:** `camps/camp3-io-security/security-function/`

### Input Check (`/api/input-check`)

The input check function uses a **hybrid detection approach**. Why hybrid? Because no single technique covers everything:

| Approach | Strength | Weakness |
|----------|----------|----------|
| Regex alone | Fast (~1ms), free | Misses creative attacks |
| AI alone (Prompt Shields) | Catches sophisticated semantic attacks | Costs per call, adds latency (~50ms) |
| **Hybrid (this function)** | **Fast for known patterns, smart for novel ones** | **Best of both** |

The function checks regex patterns *first*. If no known attack patterns are found, *then* it calls Prompt Shields for deeper analysis.

??? note "Two-phase detection flow"
    ```python
    # Phase 1: Fast regex check (instant, free)
    result = check_patterns(text)
    if not result.is_safe:
        return result  # Known attack pattern - block immediately

    # Phase 2: AI-powered check (only if regex passed)
    result = await check_with_prompt_shields(texts)
    if not result.is_safe:
        return result  # Sophisticated attack detected by AI
    ```

??? note "Injection pattern categories"
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

Notice there's no `prompt_injection` category in the regex patterns. That's intentional! Prompt injection attacks are too creative for regex. They're handled entirely by Prompt Shields, which uses AI to understand *intent*, not just patterns.

**Prompt Shields** calls the Azure AI Content Safety API to detect jailbreak attempts:

??? note "Prompt Shields API call"
    ```python
    # From check_with_prompt_shields() - calls the REST API
    request_body = {
        "userPrompt": user_prompt,  # The text to analyze
        "documents": []              # Could include RAG context too
    }
    # Returns: { "userPromptAnalysis": { "attackDetected": true/false } }
    ```

The function recursively extracts all string values from the MCP request body (tool arguments, resource URIs, prompt content) and returns:

- `{"allowed": true}` -- Safe to proceed
- `{"allowed": false, "reason": "...", "category": "..."}` -- Block with explanation

### Output Sanitization (`/api/sanitize-output`)

While input checking stops attacks coming *in*, output sanitization protects sensitive data going *out*. This function chains two complementary techniques:

**PII Detection via Azure AI Language** -- Azure AI Language uses machine learning models trained on millions of documents to recognize PII in context. It knows that "John Smith" in "Dear John Smith" is a name, but "John Smith" in "John Smith & Sons Hardware" is probably a business.

??? note "PII detection and redaction"
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

**Credential Scanning via Regex** -- AI models aren't trained to recognize API keys or connection strings. Those are arbitrary strings, so we use pattern matching for secrets:

??? note "Credential scanning patterns"
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

??? tip "Explore the Full Implementation"
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

---

[Continue: Validate Security →](section3-validation.md){ .md-button .md-button--primary }

← [Vulnerabilities](section1-vulnerabilities.md) | [Validation →](section3-validation.md)
