---
hide:
  - toc
---

<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">Camp 1 · OAuth & JWT</div>
      <h1>Upgrade to OAuth 2.1 with JWT Validation</h1>
      <p>Issue real OAuth tokens from Entra ID, validate JWT audience + signature, and pick between Device Code and Authorization Code + PKCE.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">token</span></span>
    </div>
  </div>
</div>

Static tokens served us well in Waypoint 4, but they have a fatal flaw: they never expire. If someone gets hold of `camp1_demo_token_INSECURE`, they have permanent access—and there's no way to revoke it. Time to upgrade to OAuth 2.1 with Microsoft Entra ID.

In this waypoint, you'll replace static token authentication with cryptographically-signed JWT tokens (RFC 7519) that expire after an hour. Your secure server will validate every token's signature, audience, issuer, and expiration - eliminating the risks of hardcoded credentials. You'll test two OAuth flows: Device Code Flow (perfect for CLI tools) and Authorization Code + PKCE (the production-ready browser flow).

As a bonus, you'll implement Protected Resource Metadata (RFC 9728)—a standard that lets OAuth clients automatically discover your server's authentication requirements. No more manual configuration. Just give a client your URL, and PRM handles the rest. This is how modern MCP clients like VS Code, Claude Desktop, and GitHub Copilot will connect to your server in the future.

??? info "What is OAuth 2.1?"
    **OAuth 2.1** is the modern authentication standard that fixes the security issues of static tokens:

    - **Tokens expire** - Short-lived tokens reduce breach impact
    - **PKCE (Proof Key for Code Exchange)** - Prevents token interception
    - **Audience validation** - Tokens are tied to specific services
    - **JWT (JSON Web Tokens)** - Cryptographically signed, tamper-proof
    - **Integration with Entra ID** - Enterprise identity provider

    **How it works:**

    1. Client authenticates with Entra ID (Microsoft's identity platform)
    2. Entra ID issues a JWT token (valid for ~1 hour)
    3. Client sends JWT to MCP server
    4. Server validates: signature, issuer, audience, expiration
    5. If valid, server processes request

    **OAuth Flows (Grant Types)**

    OAuth defines several "flows" (also called grant types) for different scenarios. Each flow is optimized for a specific use case:

    | Flow | Best For | How It Works |
    |------|----------|--------------|
    | **Authorization Code + PKCE** | Web apps, SPAs, mobile apps | User logs in via browser, app receives authorization code, exchanges it for tokens |
    | **Device Code** | CLI tools, IoT devices, TVs | User enters a code on another device, app polls for token completion |
    | **Client Credentials** | Server-to-server (no user) | App authenticates with its own identity, no user involved |

    **In this camp, you'll use two flows:**

    - **Device Code Flow (Option A)** — Perfect for command-line tools. You run a script, it shows a code, you authenticate in a browser, and the script receives the token. Great for understanding what's inside a JWT.

    - **Authorization Code + PKCE (Option B)** — The production-standard flow for interactive applications. A browser opens, you log in, and the app securely receives tokens. PKCE (Proof Key for Code Exchange) prevents attackers from intercepting the authorization code.

    **Why PKCE matters:** Without PKCE, an attacker who intercepts the authorization code could exchange it for tokens. PKCE adds a cryptographic challenge that only the original client can complete—even if someone steals the code, they can't use it.

## Waypoint 5: Upgrade to OAuth 2.1 with JWT Validation

### Step 5a: Register Entra ID Application

This script creates and configures an Entra ID app registration with:

- **OAuth 2.1 scope** (`access_as_user`) for delegated permissions. This is Microsoft's standard naming convention for scopes that allow an app to act on behalf of the signed-in user. The app gets *your* permissions, not its own elevated access.
- **Device Code Flow** support for CLI authentication
- **Authorization Code + PKCE** support for browser-based flows
- **Protected Resource Metadata (PRM)** endpoints for OAuth discovery
- **Pre-authorized clients:**
    - Azure CLI (`04b07795-8ddb-461a-bbee-02f9e1bf7b46`) - for Device Code Flow
    - VS Code (`aebc6443-996d-45c2-90f0-388ff96faa56`) - for future MCP client support

This enables both authentication methods (Option A and B) with a single registration.

=== "Bash"
    ```bash
    cd camps/camp1-identity
    ./scripts/register-entra-app.sh
    ```

=== "PowerShell"
    ```powershell
    cd camps/camp1-identity
    ./scripts/register-entra-app.ps1
    ```

**Expected output:**

```
Camp 1: Register Entra ID Application
========================================
Creating Entra ID app registration: sherpa-mcp-camp1-1234567890

App ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Setting identifier URI...

Exposing API scope...
API scope created

Pre-authorizing clients (Azure CLI + VS Code)...
Clients pre-authorized
Redirect URIs configured
Public client: device code flow
Web: VS Code OAuth, demo client (port 8090)
Client type configured (confidential - supports client secrets)

Entra ID Application Registered!
====================================
App Name: sherpa-mcp-camp1-1234567890
Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Tenant ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
Identifier URI: api://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Pre-authorized clients:
   - Azure CLI (for Device Code Flow)
   - VS Code (for PRM-based authentication)

Redirect URIs configured:
   - urn:ietf:wg:oauth:2.0:oob (device code flow)
   - http://127.0.0.1:33418 (VS Code)
   - https://vscode.dev/redirect (VS Code)
   - http://localhost:8090/callback (demo client)

Save these values - you'll need them for deployment!

Add to your .env file:
AZURE_TENANT_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Save these values!** You'll need them for deployment.

??? info "What's happening behind the scenes?"
    **Creating a "Doorman" for Your Server**

    Think of your MCP server as a building that needs security. This script creates a "doorman" (Entra ID app registration) who knows:

    1. **Who's allowed in** (Azure CLI, VS Code, and your demo client)
    2. **What they can do** (access the MCP server on your behalf)
    3. **How to verify their ID** (checking OAuth tokens)

    **Step-by-step breakdown:**

    **1. Create the app registration**
    ```
    App Name: sherpa-mcp-camp1-1234567890
    Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    ```
    This creates a unique identity for your MCP server in Azure. The Client ID is like a serial number - it uniquely identifies your app in Microsoft's identity system. *Your actual Client ID will be different - a unique GUID generated just for you.*

    **2. Set identifier URI**
    ```
    Identifier URI: api://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    ```
    This creates a globally unique "address" for your server. When clients request access, they say "I want to access `api://xxxxxxxx...`" - this prevents confusion with other apps.

    **3. Expose API scope**
    ```
    ✅ API scope created
    Scope: access_as_user
    ```
    This defines what permission clients are asking for: "access the MCP server as the currently signed-in user". It's like saying "I'm not asking for admin access, just let me do what the logged-in user is allowed to do."

    **4. Pre-authorize trusted clients**
    ```
    ✅ Clients pre-authorized
       - Azure CLI (04b07795-8ddb-461a-bbee-02f9e1bf7b46)
       - VS Code (aebc6443-996d-45c2-90f0-388ff96faa56)
    ```
    These are Microsoft's official client IDs for Azure CLI and VS Code (these IDs are the same for everyone). Pre-authorizing them means users won't see a consent prompt - Microsoft already trusts these clients, and now your app does too.

    **5. Configure redirect URIs**
    ```
    ✅ Redirect URIs configured
       Public client: urn:ietf:wg:oauth:2.0:oob (device code flow)
       Web: localhost:8090/callback (demo client), VS Code endpoints
    ```
    These define where OAuth responses get sent after authentication:

    - **Device code flow**: Special "out of band" URI for CLI tools
    - **Demo client**: Local server on port 8090 for authorization code flow
    - **VS Code**: Standard VS Code OAuth redirect URIs (for future use)

    **6. Configure client type**
    ```
    ✅ Client type configured (confidential)
       isFallbackPublicClient: false
       Supports: Client secrets, Authorization Code flow
    ```
    This sets the app as a **confidential client**, which means it can securely store and use client secrets. This is required for the demo client's authorization code flow.

    - **Confidential client** (what we have): Can use secrets for token exchange, suitable for backend apps
    - **Public client**: Cannot store secrets securely, used for mobile/desktop apps

    !!! note "Production Consideration"
        While this demo uses client secrets for simplicity, production environments should prefer:

        - **Device Code Flow** (Option A) - No secrets needed, great for CLI tools
        - **Managed Identity** - For Azure-hosted services (no secrets to manage)
        - **Certificate-based authentication** - More secure than client secrets

    **Why this matters:**

    - **No more hardcoded passwords!** Instead of storing a static token like `camp1_demo_token_INSECURE`, your server will validate cryptographically signed tokens from Microsoft.
    - **Tokens expire automatically** - even if someone steals a token, it only works for about an hour.
    - **You can revoke access** - if something goes wrong, you can disable the app registration and all tokens immediately stop working.
    - **Full audit trail** - Microsoft logs every authentication, so you know who accessed what and when.

    **Real-world analogy:**

    **Before (static token):** Like having one key that everyone shares, never changes, and works forever. If anyone copies it, they have permanent access.

    **After (OAuth with Entra ID):** Like having a security badge system where:

    - Each person gets their own temporary badge
    - Badges expire daily
    - The security desk (Entra ID) keeps a log of who came in
    - Lost badges can be deactivated instantly
    - Only approved badge readers (Azure CLI, demo client, VS Code) work with your doors

---

### Step 5b: Configure Secure Server with Entra ID

Update your azd environment with the Entra ID values:

```bash
# Replace with your actual values from the script output
azd env set AZURE_CLIENT_ID "<your-client-id>"
azd env set AZURE_TENANT_ID "<your-tenant-id>"
```

Now configure the secure server to use these values for JWT validation:

=== "Bash"
    ```bash
    ./scripts/configure-secure-server.sh
    ```

=== "PowerShell"
    ```powershell
    ./scripts/configure-secure-server.ps1
    ```

**What this script does:**

This updates the Container App's environment variables to use your Entra ID application client ID for JWT validation (instead of the Managed Identity client ID). The container automatically restarts to pick up the new configuration—no redeploy needed!

??? info "Why do we need two different Client IDs?"
    **Understanding the Two Identities**

    Your deployment actually has **two separate identities** in Azure:

    1. **Managed Identity Client ID** - The identity of your Container App itself
        - Created automatically when you provisioned infrastructure
        - Used by the Container App to authenticate TO other Azure services (like Key Vault)
        - Think of it as "who the app is" when talking to Azure

    2. **Entra ID App Registration Client ID** - The identity users authenticate WITH
        - Created by the `register-entra-app.sh` script
        - Used to validate JWT tokens FROM users
        - Think of it as "who the app represents" when users sign in

    **The Key Difference:**

    - **Managed Identity (app → Azure):** "I'm Container App XYZ, let me read secrets from Key Vault"
    - **App Registration (user → app):** "I'm a user with a token for App ABC, let me access the MCP server"

    **What happens without this configuration:**

    If you skip this step, the Container App would try to validate JWT tokens against the Managed Identity Client ID instead of your App Registration Client ID. This means:

    - +mdi:close+ User tokens would have the wrong `aud` (audience) claim
    - +mdi:close+ JWT validation would fail with "Invalid audience"
    - +mdi:close+ Users couldn't authenticate even with valid tokens

    **Real-world analogy:**

    - **Managed Identity** = Your company badge (authenticates you TO the building)
    - **App Registration** = Your customer portal (authenticates customers TO you)

    You wouldn't use your company badge to verify customer identities - same principle here!

    **What the script sets:**

    ```bash
    # Sets AZURE_CLIENT_ID to your App Registration ID
    # This tells JWTVerifier: "Expect tokens with aud=<app-registration-client-id>"
    ```

    This ensures the server validates tokens against the correct identity.

The secure server now includes:

- +mdi:check+ `JWTVerifier` for token validation
- +mdi:check+ Protected Resource Metadata (PRM) endpoint at `/.well-known/oauth-protected-resource`
- +mdi:check+ Audience validation (checks the `aud` claim)
- +mdi:check+ Expiration checking (rejects expired tokens)
- +mdi:check+ Signature validation (ensures token not tampered)
- +mdi:check+ Issuer validation (confirms token from correct Entra ID tenant)

**What's different in the code:**

```python
# Before (vulnerable server):
auth = StaticTokenVerifier(
    tokens={"camp1_demo_token_INSECURE": {"client_id": "user_001"}}
)

# After (secure server):
auth = JWTVerifier(
    jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys",
    audience=CLIENT_ID,  #Audience validation!
    issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"
)
```

---

### Step 5c: Authenticate (Choose Your Path)

This camp offers **two authentication methods**. Both demonstrate OAuth 2.1 security - choose based on your needs:

| Method | Best For | What You'll Learn |
|--------|----------|-------------------|
| **Option A: Device Code Flow** | CLI tools, understanding OAuth mechanics | See the token, decode it, understand JWT claims |
| **Option B: Authorization Code + PKCE Demo** | Browser-based flows, production patterns | Complete OAuth flow with PRM discovery |

!!! tip "Recommendation"
    Try **both paths** to understand different OAuth grant types:

    - Start with **Option A** to understand what's inside a JWT token
    - Then try **Option B** to see PRM discovery and authorization code flow in action

---

### Understanding the Two Paths

| Aspect | Option A: Device Code Flow | Option B: Authorization Code + PKCE Demo |
|--------|----------------------------|-------------------------------------------|
| **Token visibility** | You see and decode the JWT | Token displayed in terminal output |
| **Learning value** | High - understand JWT claims | High - see PRM discovery and production OAuth patterns |
| **Setup complexity** | Low - run script, copy token | Medium - generate secret, run demo |
| **Ongoing friction** | High - copy token every ~1 hour | Medium - demo restart after ~1 hour |
| **Use in production** | CLI tools, automation, headless environments | Browser-based apps, native clients |
| **OAuth flow** | Device Code Grant | Authorization Code Grant with PKCE |
| **PRM demonstration** | Manual configuration needed | Automatic discovery via PRM |

**Key insight:** Both methods result in the **same JWT validation** on the server. The server doesn't know (or care) which flow was used - it just validates the token.

---

??? example "Option A: Device Code Flow (Understanding OAuth)"

    **Best for:** Learning OAuth mechanics, CLI automation, headless environments

    This flow helps you understand JWT tokens by making them visible:

    === "Bash"
        ```bash
        ./scripts/get-mcp-token.sh
        ```

    === "PowerShell"
        ```powershell
        ./scripts/get-mcp-token.ps1
        ```

    **What happens:**

    1. Script opens browser for authentication
    2. You sign in with your Azure account
    3. Azure CLI receives a JWT token
    4. Token is printed to terminal (you can decode it at [jwt.ms](https://jwt.ms))

    ??? info "What's happening behind the scenes?"
        **OAuth Delegated Permissions Flow**

        When you run the token script:

        1. **Azure CLI requests a token** with scope `api://{YOUR_CLIENT_ID}/access_as_user`
        2. **You authenticate** with your Azure credentials (browser popup)
        3. **Entra ID issues a JWT token** containing:
            - `aud` (audience): Your app's client ID
            - `iss` (issuer): Your Entra ID tenant
            - `scp` (scope): `access_as_user`
            - `exp` (expiration): ~1 hour from now
            - Your identity claims (`name`, `email`, etc.)

        **Token validation on the server:**

        ```python
        verifier = JWTVerifier(
            issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0",
            audience=CLIENT_ID,
            jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys"
        )
        # Validates: signature, expiration, audience, issuer
        ```

        **Why this is more secure:**

        - Tokens **expire automatically** (can't be used forever)
        - Tokens are **tied to user identity** (audit trail)
        - Tokens can be **revoked** via Entra ID
        - No secrets stored in environment variables

    **Save your token for testing:**

    === "Bash"
        ```bash
        # Copy the token from script output and set it
        TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIs..."
        ```

    === "PowerShell"
        ```powershell
        # Copy the token from script output and set it
        $TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIs..."
        ```

    **Test with curl:**

    === "Bash"
        ```bash
        # Get secure server URL (strip quotes)
        SECURE_URL=$(azd env get-values | grep SECURE_SERVER_URL | cut -d= -f2 | tr -d '"')

        # Step 1: Initialize MCP session and capture session ID from response headers
        RESPONSE=$(curl -i -X POST ${SECURE_URL}/mcp \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl-test","version":"1.0"}},"id":1}')

        SESSION_ID=$(echo "$RESPONSE" | grep -i "mcp-session-id:" | awk '{print $2}' | tr -d '\r')
        echo "Session ID: $SESSION_ID"

        # Step 2: List available tools using the session ID
        curl -s -X POST ${SECURE_URL}/mcp \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -H "mcp-session-id: ${SESSION_ID}" \
        -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
        ```

    === "PowerShell"
        ```powershell
        # Get secure server URL
        $SECURE_URL = azd env get-value SECURE_SERVER_URL

        # Step 1: Initialize MCP session and capture session ID from response headers
        $RESPONSE = curl.exe -i -X POST "$SECURE_URL/mcp" `
        -H "Authorization: Bearer $TOKEN" `
        -H "Content-Type: application/json" `
        -H "Accept: application/json, text/event-stream" `
        -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl-test","version":"1.0"}},"id":1}'

        $SESSION_ID = ($RESPONSE -split "`n" | Select-String -Pattern "mcp-session-id:" | Select-Object -First 1).ToString() -replace '.*:\s*', '' | ForEach-Object { $_.Trim() }
        Write-Host "Session ID: $SESSION_ID"

        # Step 2: List available tools using the session ID
        curl.exe -s -X POST "$SECURE_URL/mcp" `
        -H "Authorization: Bearer $TOKEN" `
        -H "Content-Type: application/json" `
        -H "Accept: application/json, text/event-stream" `
        -H "mcp-session-id: $SESSION_ID" `
        -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
        ```

    **Success!** You should see a list of available tools returned, proving JWT authentication works!

    ??? warning "Troubleshooting authentication issues"
        **Problem: No session ID received (empty response)**

        This usually means authentication failed. Check:

        1. **Is your token expired?**

        === "Bash"
            ```bash
            # Decode your token at jwt.ms or check expiration
            echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .exp
            # Compare to current time: date +%s
            ```

        === "PowerShell"
            ```powershell
            # Decode your token at jwt.ms or check expiration
            # Copy the middle portion of the token (between the two dots) and decode at https://jwt.ms
            ```

        Tokens expire after ~1 hour. Get a new token:

        === "Bash"
            ```bash
            ./scripts/get-mcp-token.sh
            TOKEN="<new-token>"
            ```

        === "PowerShell"
            ```powershell
            ./scripts/get-mcp-token.ps1
            $TOKEN = "<new-token>"
            ```

        2. **Is the audience correct?**

        === "Bash"
            ```bash
            # Check the 'aud' claim in your token
            echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .aud

            # Compare to your CLIENT_ID
            azd env get-values | grep AZURE_CLIENT_ID
            ```

        === "PowerShell"
            ```powershell
            # Check the 'aud' claim in your token
            # Decode at https://jwt.ms and check the 'aud' field

            # Compare to your CLIENT_ID
            azd env get-value AZURE_CLIENT_ID
            ```

        If they don't match, you may need to:
        - Ensure `configure-secure-server.sh` was run
        - Verify `AZURE_CLIENT_ID` is set correctly in the Container App

        3. **See the full error response:**

        === "Bash"
            ```bash
            # Remove the SESSION_ID extraction to see full output
            curl -v -X POST ${SECURE_URL}/mcp \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -H "Accept: application/json, text/event-stream" \
                -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl-test","version":"1.0"}},"id":1}'
            ```

        === "PowerShell"
            ```powershell
            # Remove the SESSION_ID extraction to see full output
            curl.exe -v -X POST "$SECURE_URL/mcp" `
                -H "Authorization: Bearer $TOKEN" `
                -H "Content-Type: application/json" `
                -H "Accept: application/json, text/event-stream" `
                -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl-test","version":"1.0"}},"id":1}'
            ```

        Look for:
        - `401 Unauthorized` - Token is invalid/expired/wrong audience
        - `403 Forbidden` - Token valid but lacks permissions
        - `500 Internal Server Error` - Server configuration issue

        **Problem: curl shows transfer stats but no output**

        This happens when the response has no body. Check:

        === "Bash"
            ```bash
            # Use -v flag to see headers and status code
            curl -v -X POST ${SECURE_URL}/mcp \
            -H "Authorization: Bearer $TOKEN" \
            -H "mcp-session-id: ${SESSION_ID}" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
            ```

        === "PowerShell"
            ```powershell
            # Use -v flag to see headers and status code
            curl.exe -v -X POST "$SECURE_URL/mcp" `
            -H "Authorization: Bearer $TOKEN" `
            -H "mcp-session-id: $SESSION_ID" `
            -H "Content-Type: application/json" `
            -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
            ```

        Common causes:
        - Missing or invalid `mcp-session-id` header
        - Wrong HTTP method (should be POST)
        - Incorrect endpoint URL

    **What you just did:**

    - +mdi:check+ Authenticated with a **JWT token** (expires in ~1 hour, not forever!)
    - +mdi:check+ Server **validated the token signature** against Entra ID public keys
    - +mdi:check+ Server **checked the audience** (token is for THIS app, not another)
    - +mdi:check+ Server **verified expiration** (token is still valid)
    - +mdi:check+ Successfully called MCP methods with OAuth 2.1 security!

??? example "Option B: Authorization Code + PKCE Demo (Production OAuth Flow)"

    **Best for:** Understanding browser-based OAuth, PRM discovery, production authentication patterns

    This demo shows how modern MCP clients discover OAuth configuration and perform the complete authorization code + PKCE flow with Entra ID.

    ??? info "What is Protected Resource Metadata (PRM)?"
        **Protected Resource Metadata (PRM)** is a standardized way for OAuth resource servers to advertise their authentication requirements. It's defined in RFC 9728 and enables automatic OAuth discovery.

        **The Problem It Solves:**

        Without PRM, every time you want to connect to a protected API, you need to manually configure:

        - Which authorization server to use (e.g., Entra ID, Auth0, Okta)
        - What scope to request (e.g., `api://my-app/access_as_user`)
        - How to send the token (header, query param, etc.)

        This is tedious and error-prone. Users have to read documentation, copy-paste URLs, and manually configure clients.

        **How PRM Works:**

        When a client connects to your protected resource without authentication:

        1. Server returns `401 Unauthorized` with a special header:
        ```
        WWW-Authenticate: Bearer resource_metadata="https://server/.well-known/oauth-protected-resource"
        ```

        2. Client fetches the PRM endpoint and gets:
        ```json
        {
            "resource": "https://your-server.com",
            "authorization_servers": ["https://login.microsoftonline.com/.../v2.0"],
            "scopes_supported": ["api://your-client-id/access_as_user"],
            "bearer_methods_supported": ["header"]
        }
        ```

        3. Client automatically knows:

            - Which OAuth server to use
            - What scope to request
            - How to send the access token

        **Real-world analogy:**

        - **Without PRM:** "Here's a restaurant. Go figure out their menu, hours, and payment methods yourself."
        - **With PRM:** "Here's a restaurant with a sign outside that lists everything you need to know."

        **Why It Matters for MCP:**

        Future MCP clients (like VS Code with MCP, Claude Desktop, GitHub Copilot) can connect to your server with **zero manual configuration**. Users just provide the URL, and everything else happens automatically.

        **RFC 9728:** PRM is an official IETF standard that's part of the modern OAuth ecosystem. By implementing it, your MCP server follows industry best practices.

    #### Run the PRM Demo Client

    We've built a Python client that demonstrates the complete PRM + PKCE flow:

    **Step 1: Navigate to camp1-identity**

    ```bash
    cd camps/camp1-identity
    ```

    **Step 2: Generate client secret for token exchange**

    === "Bash"
        ```bash
        ./scripts/generate-client-secret.sh
        ```

    === "PowerShell"
        ```powershell
        ./scripts/generate-client-secret.ps1
        ```

    This creates a client secret for local testing (expires in 30 days). The secret is saved to `demo-client/.env` and is git-ignored.

    !!! note "Client Secrets in Production"
        This demo uses a client secret for simplicity, but production public clients should use:

        - Device Code Flow (Option A) for CLI tools
        - Authorization Code + PKCE without secrets for native/mobile apps
        - Or implement backend-for-frontend (BFF) pattern

        Client secrets are appropriate for confidential clients (server-to-server) but not for public clients in production.

    **Step 3: Run the demo**

    === "Bash"
        ```bash
        # Get your configuration
        eval "$(azd env get-values | sed 's/^/export /')"

        # Run the demo (uv handles dependencies automatically)
        cd demo-client
        uv run --project .. python mcp_prm_client.py \
        "${SECURE_SERVER_URL}" \
        "${AZURE_CLIENT_ID}"
        ```

    === "PowerShell"
        ```powershell
        # Get your configuration
        $SECURE_SERVER_URL = azd env get-value SECURE_SERVER_URL
        $AZURE_CLIENT_ID = azd env get-value AZURE_CLIENT_ID

        # Run the demo (uv handles dependencies automatically)
        cd demo-client
        uv run --project .. python mcp_prm_client.py `
        "$SECURE_SERVER_URL" `
        "$AZURE_CLIENT_ID"
        ```

    #### What Happens

    The demo will walk through each phase of the OAuth flow:

    **Phase 1: PRM Discovery**
    ```
    ✓ Received WWW-Authenticate header
    Bearer resource_metadata="https://your-server/.well-known/oauth-protected-resource"
    ✓ Found PRM endpoint
    ✓ Fetched PRM metadata:
    Resource: https://your-server.azurecontainerapps.io
    Authorization Server: https://login.microsoftonline.com/.../v2.0
    Scopes: api://your-client-id/access_as_user
    ```

    **Phase 2: Authorization Server Discovery**
    ```
    ✓ Fetching: https://login.microsoftonline.com/.../.well-known/openid-configuration
    ✓ Authorization endpoint discovered
    ✓ Token endpoint discovered
    ```

    **Phase 3: PKCE Authorization Code Flow**
    ```
    ✓ Generated PKCE code_challenge
    ✓ Opening browser for authentication...
    ✓ Received authorization code
    ✓ State validated
    ✓ Exchanging authorization code for access token...
    Using client secret from .env file
    ✓ Access token acquired
    Token type: Bearer
    Expires in: 3894 seconds
    ```

    **Phase 4: Authenticated MCP Requests**
    ```
    ✓ Sending request to: https://your-server/mcp
    Method: tools/list
    ✓ Success! Tools listed with JWT authentication
    ```

    #### What You Just Did

    - +mdi:check+ **PRM Discovery** - Server told client how to authenticate (RFC 9728)
    - +mdi:check+ **OAuth Server Discovery** - Client found Entra ID endpoints automatically
    - +mdi:check+ **PKCE Flow** - Secure authorization code exchange with proof key
    - +mdi:check+ **JWT Token** - Received signed token from Entra ID (expires in ~1 hour)
    - +mdi:check+ **Authenticated MCP** - Made MCP requests with Bearer token

    This is exactly how production MCP clients will work once they fully implement PRM support!

    #### Verify PRM Endpoint Manually

    You can also check the PRM endpoint directly:

    === "Bash"
        ```bash
        SECURE_URL=$(azd env get-values | grep SECURE_SERVER_URL | cut -d= -f2 | tr -d '"')

        # Check WWW-Authenticate header on 401
        curl -i "${SECURE_URL}/mcp" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"initialize","id":1}'
        ```

    === "PowerShell"
        ```powershell
        $SECURE_URL = azd env get-value SECURE_SERVER_URL

        # Check WWW-Authenticate header on 401
        curl.exe -i "$SECURE_URL/mcp" `
        -H "Content-Type: application/json" `
        -d '{"jsonrpc":"2.0","method":"initialize","id":1}'
        ```

    **Look for:**
    ```
    HTTP/2 401
    www-authenticate: Bearer resource_metadata="https://your-server/.well-known/oauth-protected-resource"
    ```

    **Fetch the PRM metadata:**

    === "Bash"
        ```bash
        curl -s "${SECURE_URL}/.well-known/oauth-protected-resource" | jq .
        ```

    === "PowerShell"
        ```powershell
        curl.exe -s "$SECURE_URL/.well-known/oauth-protected-resource" | ConvertFrom-Json | ConvertTo-Json -Depth 10
        ```

    **Expected output:**
    ```json
    {
    "resource": "https://your-app.azurecontainerapps.io",
    "authorization_servers": [
        "https://login.microsoftonline.com/{tenant-id}/v2.0"
    ],
    "scopes_supported": [
        "api://{client-id}/access_as_user"
    ],
    "bearer_methods_supported": ["header"],
    "token_formats_supported": ["jwt"]
    }
    ```

    !!! success "PRM Implementation Complete!"
        Your server now implements RFC 9728 Protected Resource Metadata. When MCP clients (VS Code, Claude Desktop, etc.) add full PRM support for pre-registered OAuth apps, they'll be able to connect to your server automatically with zero configuration!

    ??? tip "Explore the Demo Code"
        The demo client (`demo-client/mcp_prm_client.py`) is fully commented and demonstrates the complete OAuth flow:

        - **PRM discovery** from WWW-Authenticate header
        - **OAuth server metadata parsing** (.well-known/openid-configuration)
        - **PKCE code challenge generation** (SHA256 hash of verifier)
        - **Local callback server** for authorization code (port 8090)
        - **Token exchange** with client authentication
        - **MCP JSON-RPC requests** with Bearer token

        See the [camp1-identity/demo-client directory](https://github.com/Azure-Samples/sherpa/tree/main/camps/camp1-identity/demo-client) on GitHub for the complete implementation with `README.md` and full source code.

---

### Understanding JWT Validation

Regardless of which authentication path you chose, the secure server validates **every request** the same way:

```python
auth = JWTVerifier(
    jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys",
    audience=CLIENT_ID,  # Checks 'aud' claim
    issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"  # Checks 'iss' claim
)
```

**What's checked:**

- +mdi:check+ **Signature:** Token cryptographically signed by Entra ID (not tampered)
- +mdi:check+ **Issuer (`iss`):** Token from correct Entra ID tenant
- +mdi:check+ **Audience (`aud`):** Token intended for THIS server (prevents confused deputy)
- +mdi:check+ **Expiration (`exp`):** Token not expired
- +mdi:check+ **Not Before (`nbf`):** Token is valid now (not used too early)

**Decode your JWT at [jwt.ms](https://jwt.ms) to see the claims!**
