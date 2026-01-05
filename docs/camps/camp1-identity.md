---
hide:
  - toc
---

# Camp 1: Identity & Access Management

*Establishing Your Identity on the Mountain*

![Identity](../images/sherpa-identity.png)

Welcome to **Camp 1**, where you'll establish production-grade identity controls for your MCP server. In Base Camp, you learned that unauthenticated servers are dangerous. Now we'll deploy to Azure and implement enterprise security using Managed Identity, Key Vault, and OAuth 2.1 with JWT validation.

This camp demonstrates why the same vulnerabilities from Base Camp are even more dangerous in the cloud, and how Azure's identity services provide passwordless, production-grade solutions. You'll follow the same **"vulnerable → exploit → fix → validate"** methodology, but this time in a real cloud environment with real-world security controls.

**Tech Stack:** Python, FastMCP, Azure Container Apps, Entra ID, Key Vault, and Managed Identity  
**Primary Risks:** [MCP01](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp01-token-mismanagement/) (Token Mismanagement), [MCP07](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp07-authz/) (Insufficient Authentication), [MCP02](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp02-privilege-escalation/) (Privilege Escalation)

## What You'll Learn

Building on Base Camp's foundation, you'll master enterprise-grade identity and access management in Azure:

!!! info "Learning Objectives"
    - Deploy an MCP server to Azure Container Apps
    - Understand cloud-specific security vulnerabilities (tokens in Portal, no expiration)
    - Implement Azure Managed Identity for passwordless Azure resource access
    - Secure secrets with Azure Key Vault
    - Configure OAuth 2.1 with Entra ID for client authentication
    - Validate JWT tokens including audience checking to prevent confused deputy attacks
    - Apply least-privilege RBAC principles

## Prerequisites

Before starting Camp 1, ensure you have the required tools installed.

!!! info "Prerequisites Guide"
    See the **[Prerequisites page](../prerequisites.md)** for detailed installation instructions, verification steps, and troubleshooting.

**Quick checklist for Camp 1:**

:material-check: Azure subscription with Contributor access  
:material-check: Azure CLI (authenticated)  
:material-check: Azure Developer CLI - azd (authenticated)  
:material-check: Python 3.10+  
:material-check: uv (Python package installer)  
:material-check: Docker (installed and running)  
:material-check: Completed Base Camp (recommended)  

If you haven't installed these tools yet, visit the [Prerequisites page](../prerequisites.md) for detailed installation instructions and verification steps.

---

## The Ascent

Camp 1 follows six waypoints, each building on the previous one. Click each waypoint below to expand instructions and continue your ascent.

??? note "Waypoint 1: Deploy Vulnerable Server to Azure"

    ### Deploy to Azure Container Apps

    The vulnerable server uses the same `StaticTokenVerifier` pattern from Base Camp, but now deployed to Azure where the vulnerabilities become even more dangerous.

    ```bash
    cd camps/camp1-identity
    azd provision
    ```

    When prompted:
    
    - **Environment name:** Choose a name (e.g., `camp1-dev`)
    - **Subscription:** Select your Azure subscription
    - **Resource group:** Create new or select existing (e.g., `rg-camp1-dev`)
    - **Location:** Select your Azure region (e.g., `eastus` or `westus2`)

    This provisions all Azure resources:
    
    1. Resource group
    2. Container Registry with Managed Identity access
    3. Log Analytics workspace
    4. Container Apps Environment
    5. Key Vault with RBAC for Managed Identity
    6. Managed Identity with proper role assignments
    7. Both Container Apps (vulnerable-server and secure-server)

    Next, deploy the application code:

    ```bash
    azd deploy
    ```

    This builds and deploys your Python MCP servers:
    
    1. Builds Docker images for both servers
    2. Pushes images to Azure Container Registry
    3. Updates Container Apps with the new images

    ### What Just Deployed?

    The vulnerable server is now running in Azure with:

    - ❌ **Token stored in plain-text environment variables**
    - ❌ **Token never expires**
    - ❌ **No audience validation**
    - ❌ **Secrets visible in Azure Portal**

    **This demonstrates OWASP MCP01 (Token Mismanagement) and MCP07 (Insufficient Auth) in a cloud environment!**

    ### Save Your Deployment Information

    ```bash
    # Get your container app URL
    azd env get-values | grep -E "AZURE_CONTAINER_APP_URL|AZURE_RESOURCE_GROUP|AZURE_KEY_VAULT"
    ```

    Keep these values handy - you'll need them for the exploits!

??? danger "Waypoint 2: Exploit Cloud Vulnerabilities"

    ### Cloud Deployment Amplifies Security Risks

    The same vulnerabilities from Base Camp are more critical in Azure because:
    
    - **Tokens are visible in Azure Portal** (not just in code)
    - **Audit logs expose tokens** (compliance violation)
    - **Wider attack surface** (anyone with read access can steal tokens)
    - **Persistent deployment** (vulnerable server runs 24/7, not just during development)

    ---

    ### Exploit 2.1: Steal Token from Portal & Use It Forever

    **The vulnerability:** Static tokens stored in environment variables are visible in the Azure Portal to anyone with read access, and they never expire.

    **Steps to exploit:**

    1. Open [Azure Portal](https://portal.azure.com)
    2. Navigate to your resource group (e.g., `rg-camp1-dev`)
    3. Click on the **vulnerable server** Container App (named `ca-vulnerable-xxxxx`)
    4. In the left menu, go to **Application** → **Containers**
    5. Click the **Environment variables** tab
    6. Find `REQUIRED_TOKEN` with value `camp1_demo_token_INSECURE` - it's right there in plain text!

    **Try it yourself:** Copy the stolen token and use it to authenticate:

    ```bash
    # Get your vulnerable server URL
    VULNERABLE_URL=$(azd env get-values | grep VULNERABLE_SERVER_URL | cut -d= -f2 | tr -d '"')
    
    # Test with the stolen token - server accepts it!
    curl -X POST ${VULNERABLE_URL}/mcp \
      -H "Authorization: Bearer camp1_demo_token_INSECURE" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"exploit-test","version":"1.0"}},"id":1}'
    ```

    **What you'll see:** The server returns a successful response. The MCP server can't tell the difference between a legitimate request and your stolen token - **it just works!**

    **Now wait an hour... or a day... or even a month...** Run the same command again - **it STILL works!** The token never expires.

    !!! danger "Security Impact: Double Threat"
        **Easy to Steal:**
        
        - Anyone with **Reader** access to the Container App can steal the token
        - Developers, operations teams, security auditors all have this access
        - Token appears in audit logs (compliance violation)
        - Compromised Azure accounts gain immediate access
        - No way to detect if token was stolen
        
        **Impossible to Revoke:**
        
        - Stolen token can be used **indefinitely** - no expiration
        - No token rotation mechanism
        - No way to revoke access without redeploying the entire application
        - Even if you discover the breach, you can't disable the token
        - A single breach = permanent compromise

    This demonstrates both **OWASP MCP01 (Token Mismanagement)** and **MCP07 (Insufficient Authentication)** - static tokens are visible to too many people AND they never expire!

    ---

    ### Exploit 2.2: No Audience Validation (Conceptual)

    Even if we were using JWTs (we're not yet), the `StaticTokenVerifier` doesn't validate the `aud` (audience) claim.

    **What this means:**
    
    - A token intended for **Service A** could be used with **Service B**
    - This is called a **confused deputy attack**
    - The server can't distinguish "is this token meant for me?"

    **Example scenario:**
    
    - Alice gets a JWT for accessing the payment service
    - She uses that same JWT to access the user data service
    - Both services accept it because neither checks audience

    We'll fix this in Waypoint 5 with proper JWT validation including audience checking.

    ---

    ### Summary of Exploits

    | Exploit | Impact | OWASP Risk |
    |---------|--------|------------|
    | Steal token from Portal & use forever | Anyone with Portal access gets permanent access | MCP01, MCP07 |
    | No audience check | Confused deputy attacks | MCP07 |

??? success "Waypoint 3: Enable Managed Identity"

    ### What is Managed Identity?

    **Azure Managed Identity** eliminates passwords and keys by having Azure automatically manage credentials for you:

    :material-check: **No secrets to store** - Azure handles authentication  
    :material-check: **No secrets to rotate** - Azure manages the lifecycle  
    :material-check: **Uses Azure RBAC** - Permissions controlled by role assignments  
    :material-check: **Works with many Azure services** - Key Vault, Storage, Cosmos DB, etc.  

    **How it works:**
    
    1. Your Container App has a **Managed Identity** (automatically created)
    2. You grant that identity **RBAC permissions** (e.g., "Key Vault Secrets User")
    3. Your code uses `DefaultAzureCredential()` - automatically picks up the identity
    4. No passwords, no keys, no secrets!

    ---

    ### Verify Managed Identity Setup

    Your infrastructure already created the Managed Identity during the provision process. Let's verify it:

    ```bash
    cd camps/camp1-identity
    ./scripts/enable-managed-identity.sh
    ```

    This script:
    
    - Loads your azd environment variables
    - Verifies the Managed Identity exists
    - Confirms RBAC role assignments to Key Vault

    **Expected output:**

    ```
    🔐 Camp 1: Enable Managed Identity
    ==================================
    📦 Loading azd environment...
    ✅ Managed Identity Principal ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

    🔍 Verifying Key Vault role assignment...
    Role                        Scope
    --------------------------  --------------------------------------------------
    Key Vault Secrets User      /subscriptions/.../providers/Microsoft.KeyVault/...

    ✅ Managed Identity setup complete!
    The Container App can now access Key Vault secrets without passwords.
    ```

    ---

    ### Understanding the Security Improvement

    **Before (vulnerable):**
    ```python
    # Hardcoded connection string - BAD!
    CONNECTION_STRING = "DefaultEndpointsProtocol=https;AccountName=...;AccountKey=EXPOSED_KEY..."
    client = BlobServiceClient.from_connection_string(CONNECTION_STRING)
    ```

    **After (secure with Managed Identity):**
    ```python
    from azure.identity import DefaultAzureCredential
    
    # No secrets! Managed Identity authenticates automatically
    credential = DefaultAzureCredential()
    client = BlobServiceClient(account_url="https://storage.blob.core.windows.net", credential=credential)
    ```

    ---

    ### How This Protects You

    | Threat | Before | After |
    |--------|--------|-------|
    | Credential theft | Keys in env vars | No keys to steal |
    | Rotation burden | Manual rotation | Azure auto-rotates |
    | Portal exposure | Visible to readers | Not visible (identity reference only) |
    | Code leaks | Keys in repo | No keys in code |
    | Over-privileged | Often admin keys | Least-privilege RBAC |

    ---

    ### Next Step

    Managed Identity is configured! Now let's use it to access Key Vault in Waypoint 4.

??? success "Waypoint 4: Migrate Secrets to Key Vault"

    ### What is Azure Key Vault?

    **Azure Key Vault** is a cloud service for securely storing and accessing:

    - **Secrets:** API keys, connection strings, passwords
    - **Keys:** Encryption keys for cryptographic operations
    - **Certificates:** SSL/TLS certificates

    **Benefits:**
    
    - **Centralized secret management** - One place for all secrets  
    - **Access auditing** - Who accessed what, when  
    - **Secret rotation** - Update secrets without redeploying  
    - **RBAC-based access** - Fine-grained permissions  
    - **Versioning** - Keep history of secret changes

    ---

    ### Create Secrets in Key Vault

    Let's migrate demo secrets from environment variables to Key Vault:

    ```bash
    cd camps/camp1-identity
    ./scripts/migrate-to-keyvault.sh
    ```

    This script:
    
    - Creates sample secrets in your Key Vault
    - `demo-api-key` - Example API key
    - `external-service-secret` - Example service credential

    **Expected output:**

    ```
    🔑 Camp 1: Migrate Secrets to Key Vault
    =======================================
    📦 Loading azd environment...
    Creating demo secrets in Key Vault: kv-sherpa-camp1-xxxxx

    📝 Creating demo-api-key...
    📝 Creating external-service-secret...

    ✅ Secrets created in Key Vault!

    📋 Current secrets:
    Name                        Enabled
    --------------------------  ---------
    demo-api-key               True
    external-service-secret    True
    ```

    ---

    ### How the Secure Server Accesses Key Vault

    The secure server (which we'll deploy in Waypoint 5) uses Managed Identity to access Key Vault:

    ```python
    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient

    def get_keyvault_secret(secret_name: str) -> str:
        # Managed Identity authenticates automatically!
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
        return client.get_secret(secret_name).value
    
    # Usage - no hardcoded secrets!
    api_key = get_keyvault_secret("demo-api-key")
    ```

    ---

    ### Verify Secrets in Azure Portal

    1. Open [Azure Portal](https://portal.azure.com)
    2. Navigate to your Key Vault (e.g., `kv-sherpa-camp1-xxxxx`)
    3. Go to **Objects** → **Secrets**
    4. You'll see your secrets listed, but **values are hidden**
    5. Click a secret → Click current version → Click "Show Secret Value"
    6. Notice: You need **explicit permission** to view secret values!

    ---

    ### Security Improvements

    | Aspect | Before (Env Vars) | After (Key Vault) |
    |--------|-------------------|-------------------|
    | **Visibility** | Anyone with read access sees values | Values hidden, audit logged |
    | **Rotation** | Requires redeployment | Update in Key Vault, no redeploy |
    | **Access Control** | All-or-nothing (Portal access) | Fine-grained RBAC per secret |
    | **Audit** | No audit trail | Every access logged |
    | **Versioning** | No history | Full version history |

    ---

    ### Best Practices Applied

    :material-check: **Separation of Concerns:** Secrets managed separately from application code  
    :material-check: **Least Privilege:** Managed Identity has only "Key Vault Secrets User" role  
    :material-check: **Defense in Depth:** RBAC + audit logs + encryption at rest  
    :material-check: **Compliance Ready:** Audit logs for SOC 2, ISO 27001, etc.

??? success "Waypoint 5: Upgrade to OAuth 2.1 with JWT Validation"

    ### What is OAuth 2.1?

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

    ---

    ### Step 5a: Register Entra ID Application

    First, we need to register an application in Entra ID that represents our MCP server:

    ```bash
    cd camps/camp1-identity
    ./scripts/register-entra-app.sh
    ```

    This script:
    
    - Creates an Entra ID app registration
    - Configures it for device code flow
    - Sets the identifier URI (the "audience")
    - Outputs the Client ID and Tenant ID

    **Expected output:**

    ```
    🔐 Camp 1: Register Entra ID Application
    ========================================
    Creating Entra ID app registration: sherpa-mcp-camp1-1234567890

    ✅ App ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Setting identifier URI...
    Configuring public client (device code flow)...

    ✅ Entra ID Application Registered!
    ====================================
    App Name: sherpa-mcp-camp1-1234567890
    Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Tenant ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Identifier URI: api://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

    📝 Save these values - you'll need them for deployment!
    ```

    **Save these values!** You'll need them for deployment.

    ---

    ### Step 5b: Update Environment and Deploy Secure Server

    Update your azd environment with the Entra ID values:

    ```bash
    # Replace with your actual values from the script output
    azd env set AZURE_CLIENT_ID "<your-client-id>"
    azd env set AZURE_TENANT_ID "<your-tenant-id>"
    ```

    Now deploy the secure server:

    ```bash
    azd deploy --service secure-server
    ```

    Configure the secure server with your Entra ID application client ID:

    ```bash
    ./scripts/configure-secure-server.sh
    ```

    This updates the Container App to use your Entra ID application client ID for JWT validation (instead of the Managed Identity client ID).

    This deploys the secure version with:
    
    :material-check: `JWTVerifier` instead of `StaticTokenVerifier`  
    :material-check: Audience validation (checks the `aud` claim)  
    :material-check: Expiration checking (rejects expired tokens)  
    :material-check: Signature validation (ensures token not tampered)  
    :material-check: Issuer validation (confirms token from correct Entra ID tenant)

    **What's different in the code:**

    ```python
    # Before (vulnerable):
    auth = StaticTokenVerifier(
        tokens={"camp1_demo_token_INSECURE": {"client_id": "user_001"}}
    )
    
    # After (secure):
    auth = JWTVerifier(
        jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys",
        audience=CLIENT_ID,  # ✅ Audience validation!
        issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"
    )
    ```

    ---

    ### Step 5c: Get Access Token

    Now you need to authenticate to get a JWT token. Choose your preferred method:

    #### Option A: Device Code Flow (Easier)

    ```bash
    ./scripts/get-mcp-token.sh
    ```

    This will:
    
    1. Prompt you to authenticate in a browser
    2. You'll sign in with your Azure account
    3. The script receives a JWT token
    4. Token is valid for ~1 hour

    ??? info "What's happening behind the scenes?"
        **OAuth Delegated Permissions Flow**
        
        When you run the token script, here's what happens:
        
        1. **Azure CLI requests a token** with scope `api://{YOUR_CLIENT_ID}/access_as_user`
        2. **You authenticate** with your Azure credentials (browser popup)
        3. **Entra ID issues a JWT token** containing:
            - `aud` (audience): Your Entra ID application client ID (`7a9024ef...`)
            - `iss` (issuer): Your Entra ID tenant (`https://login.microsoftonline.com/{TENANT_ID}/v2.0`)
            - `scp` (scope): `access_as_user` (delegated permission)
            - `exp` (expiration): ~1 hour from now
            - Your identity claims (`name`, `email`, etc.)
        
        **Why this works:**
        
        - Your Entra ID app **exposes an API** with the `access_as_user` scope
        - Azure CLI is **pre-authorized** to request tokens for this app
        - No admin consent needed - users can self-consent
        - Tokens are **cryptographically signed** by Entra ID
        
        **Token validation on the server:**
        
        ```python
        # The secure server validates:
        verifier = JWTVerifier(
            issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0",
            audience=CLIENT_ID,  # Must match token's 'aud' claim
            jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys"
        )
        # Checks: signature, expiration, audience, issuer
        claims = verifier.verify(token)
        ```
        
        **This is dramatically more secure than static tokens because:**
        
        - Tokens **expire automatically** (can't be used forever)
        - Tokens are **tied to user identity** (audit trail)
        - Tokens can be **revoked** (via Azure Portal)
        - No secrets stored in environment variables

    #### Option B: Authorization Code + PKCE (Advanced - For Learning)

    !!! note "For Learning Purposes"
        **Recommendation: Use Option A for this workshop** - it's simpler and automated.
        
        Option B demonstrates PKCE for educational purposes. In production:
        
        - **Native/mobile apps** → Use PKCE (Option B pattern)
        - **Server-to-server** → Use client credentials
        - **CLI tools** → Use device code flow (Option A)
        
        **Steps for Option B:**
        
        1. Run the script below - browser opens for authentication
        2. After login, you'll see a 404 page (expected - no callback server)
        3. Copy the `code` parameter from the URL in your browser
        4. Follow the script's instructions to exchange code for token
        
        This is more complex but shows how real-world apps (like mobile apps) would implement OAuth.

    ```bash
    ./scripts/get-mcp-token-pkce.sh
    ```

    This uses **PKCE (Proof Key for Code Exchange)** for enhanced security against token interception. This is the most secure OAuth flow for public clients (like native apps or SPAs).

    ??? info "What's happening behind the scenes?"
        **PKCE (Proof Key for Code Exchange) Flow**
        
        PKCE solves a critical security problem: **how do you safely get OAuth tokens in apps that can't keep secrets?** Native mobile apps and single-page apps can't securely store client secrets because users can inspect the code.
        
        **The high-level flow:**
        
        1. **App generates two related values:**

            - **Code verifier** - A random secret string (kept private)
            - **Code challenge** - A cryptographic hash of the verifier (sent publicly)
        
        2. **Authorization request with code challenge:**
            - Browser redirects to Entra ID with the code challenge
            - User authenticates and consents
            - Entra ID stores the code challenge
            - Entra ID redirects back with an authorization code
        
        3. **Token exchange with code verifier:**
            - App sends: authorization code + code verifier
            - Entra ID verifies: hash(code_verifier) matches stored code_challenge
            - If they match → issues JWT token
            - If they don't match → rejects the request
        
        **Why this is secure:**
        
        Even if an attacker intercepts the authorization code (from the browser redirect), they can't use it because:
        
        - The code challenge was sent publicly, but it's just a hash
        - The code verifier is kept secret by the app
        - Without the original code verifier, they can't exchange the code for a token
        - This proves that whoever exchanges the code is the same party who started the flow
        
        **Authorization code characteristics:**
        
        - **Single-use only** - Can't be reused (security feature)
        - **Short-lived** - Expires in minutes
        - **Tied to code challenge** - Must match original request
        
        **When to use PKCE:**
        
        ✅ **Mobile apps** - No way to keep client secret safe  
        ✅ **Single-page apps (SPAs)** - JavaScript code is visible  
        ✅ **Desktop apps** - Can be decompiled  
        ❌ **Server-to-server** - Use client credentials instead  
        ❌ **CLI tools** - Device code flow is simpler (Option A)

    ---

    ### Step 5d: Set the TOKEN Variable

    Before testing, you need to set the `TOKEN` variable with the JWT you obtained in Step 5c.

    **If you used Option A (Device Code Flow):**

    The script printed your token. Copy it and set the variable:

    ```bash
    # Replace with the actual token from the script output
    TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIs..."
    ```

    **If you used Option B (PKCE):**

    The token was already set when you ran the code exchange command in step 6:

    ```bash
    TOKEN=$(curl -X POST ... | jq -r '.access_token')
    ```

    Verify your token is set:

    ```bash
    echo "Token length: ${#TOKEN}"
    # Should show a number > 1000 (JWT tokens are long!)
    ```

    ---

    ### Step 5e: Test with the JWT Token

    Now test the secure server with your JWT token:

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

    **Success!** You should see a list of available tools returned, proving JWT authentication works!

    ---

    ### Understanding JWT Validation

    The secure server validates **every request**:

    ```python
    auth = JWTVerifier(
        jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys",
        audience=CLIENT_ID,  # Checks 'aud' claim
        issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"  # Checks 'iss' claim
    )
    ```

    **What's checked:**
    
    :material-check: **Signature:** Token cryptographically signed by Entra ID (not tampered)  
    :material-check: **Issuer (`iss`):** Token from correct Entra ID tenant  
    :material-check: **Audience (`aud`):** Token intended for THIS server (prevents confused deputy)  
    :material-check: **Expiration (`exp`):** Token not expired  
    :material-check: **Not Before (`nbf`):** Token is valid now (not used too early)

    **Decode your JWT at [jwt.ms](https://jwt.ms) to see the claims!**

    ---

    ### Security Improvements

    | Aspect | Before (Static Token) | After (OAuth 2.1 JWT) |
    |--------|----------------------|----------------------|
    | **Expiration** | Never | ~1 hour |
    | **Revocation** | Impossible | Possible via Entra ID |
    | **Audience** | Not validated | Validated (prevents confused deputy) |
    | **Tampering** | Possible | Cryptographically prevented |
    | **Rotation** | Manual, risky | Automatic via token refresh |
    | **User Context** | Generic | Rich user claims (name, email, roles) |

??? note "Waypoint 6: Validate Security"

    ### Comprehensive Security Validation

    Let's verify all security controls are properly configured:

    ```bash
    cd camps/camp1-identity
    ./scripts/verify-security.sh
    ```

    This script performs comprehensive checks:

    **Expected output:**

    ```
    ✅ Camp 1: Security Validation
    ==============================
    📦 Loading azd environment...

    🔍 Running security checks...

    Check 1: Secrets in Key Vault
    ------------------------------
    ✅ Found 2 secrets in Key Vault
    Name                        Enabled
    --------------------------  ---------
    demo-api-key               True
    external-service-secret    True

    Check 2: Managed Identity RBAC
    -------------------------------
    ✅ Managed Identity has Key Vault Secrets User role
    Role                        Scope
    --------------------------  --------------------------------------------------
    Key Vault Secrets User      /subscriptions/.../resourceGroups/.../providers/...

    Check 3: Container App Identity
    --------------------------------
    ✅ Checking if container apps have managed identity assigned...
    Name                        Identity
    --------------------------  -----------
    ca-sherpa-camp1-xxxxx      UserAssigned

    ==============================
    🎉 Security Validation Complete!
    ==============================

    ✅ Verified:
      - Secrets stored in Key Vault (not env vars)
      - Managed Identity has RBAC permissions
      - Container Apps use Managed Identity

    🔒 Security posture: SECURE
       Ready for production!
    ```

    ---

    ### Manual Verification Steps (Optional - Extra Credit)

    !!! tip "Extra Credit - Not Required"
        The automated script above validates all the essential security controls. The steps below are **optional** and provide hands-on experience with testing authentication and authorization failures. Great for deeper learning, but feel free to skip ahead to the Security Checklist!

    #### 1. Verify Token Expiration

    Try using an old/expired token:

    ```bash
    # This should FAIL with "Token expired" or "Invalid token"
    curl -X POST ${SECURE_URL}/mcp \
      -H "Authorization: Bearer expired_or_old_token" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
    ```

    **Expected:** 401 Unauthorized or similar error

    #### 2. Verify Audience Validation

    Try using a token with wrong audience:

    ```bash
    # Get a token for a different resource (e.g., Microsoft Graph)
    WRONG_TOKEN=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)
    
    # This should FAIL because audience is wrong
    curl -X POST ${SECURE_URL}/mcp \
      -H "Authorization: Bearer $WRONG_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
    ```

    **Expected:** 401 Unauthorized - audience validation failed

    #### 3. Verify No Secrets in Environment Variables

    1. Open [Azure Portal](https://portal.azure.com)
    2. Navigate to your **secure** Container App
    3. Go to **Settings** → **Environment variables**
    4. Verify: No `REQUIRED_TOKEN` variable!
    5. Only configuration: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `KEY_VAULT_URL`

    **Expected:** No secret values visible, only configuration references

    ---

    ### Security Checklist

    Review what we've accomplished:

    :material-check: **No hardcoded secrets in code**  
    :material-check: **No secrets in environment variables** (moved to Key Vault)  
    :material-check: **Managed Identity for Azure resource access** (no passwords)  
    :material-check: **OAuth 2.1 authentication with Entra ID**  
    :material-check: **JWT validation** (signature, issuer, audience, expiration)  
    :material-check: **Least-privilege RBAC** (Key Vault Secrets User only)  
    :material-check: **Audit logs enabled** (Azure Monitor tracks all access)  
    :material-check: **Token expiration** (tokens expire after ~1 hour)  
    :material-check: **Audience validation** (prevents confused deputy attacks)

    ---

    ### Compare: Before vs. After

    | Security Control | Vulnerable Server | Secure Server |
    |------------------|-------------------|---------------|
    | **Authentication** | Static token | OAuth 2.1 JWT |
    | **Token Storage** | Env var (Portal visible) | Not applicable (JWT per request) |
    | **Token Expiration** | Never | ~1 hour |
    | **Azure Credentials** | Connection strings | Managed Identity |
    | **Secrets Management** | Env vars | Key Vault |
    | **Audience Validation** | No | Yes |
    | **RBAC** | Not applicable | Least-privilege |
    | **Audit Logs** | None | Azure Monitor |

---

## Key Concepts Mastered

### 1. Managed Identity
**Passwordless authentication** for Azure services. Azure automatically manages credentials - no secrets to store, rotate, or protect!

### 2. Azure Key Vault
**Centralized secret management** with RBAC, versioning, and audit logs. Secrets are encrypted at rest and in transit, with fine-grained access control.

### 3. OAuth 2.1 with PKCE
**Modern authentication** with short-lived tokens, cryptographic proof, and enhanced security against interception attacks.

### 4. JWT Validation
**Comprehensive token validation** including signature, issuer, audience, and expiration. Prevents tampering, token reuse, and confused deputy attacks.

### 5. Least-Privilege RBAC
**Grant only necessary permissions.** Managed Identity has "Key Vault Secrets User" role - can read secrets but not manage vault, create secrets, or delete.

---

## Summit View: What We Fixed

| Vulnerability | Solution | OWASP Risk Mitigated |
|---------------|----------|---------------------|
| **Hardcoded tokens** | OAuth 2.1 with Entra ID | MCP01, MCP07 |
| **Tokens never expire** | JWT with expiration (~1 hour) | MCP01 |
| **Secrets in env vars** | Azure Key Vault | MCP01 |
| **No audience validation** | JWTVerifier with `aud` check | MCP07 |
| **Password-based auth** | Managed Identity | MCP01, MCP02 |
| **Over-privileged access** | Least-privilege RBAC | MCP02 |

---

## Next Steps

### Immediate Actions

- Review your own MCP servers for token exposure
- Migrate hardcoded secrets to Key Vault
- Implement OAuth 2.1 for production servers
- Apply least-privilege RBAC everywhere

### Continue the Journey

Ready for the next challenge? Proceed to:

**[Camp 2: Gateway & Network Security →](camp2-gateway.md)**

Learn about:

- Gateway patterns for MCP
- Rate limiting and throttling
- Network security controls
- DDoS protection
- Traffic monitoring

---

## Additional Resources

- [Azure Managed Identity Documentation](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/azure/key-vault/general/best-practices)
- [OAuth 2.1 Specification](https://oauth.net/2.1/)
- [OWASP MCP Azure Security Guide](https://microsoft.github.io/mcp-azure-security-guide/)
- [FastMCP Authentication Documentation](https://github.com/jlowin/fastmcp)

---

## Troubleshooting

??? question "Issue: azd up fails with subscription access error"
    **Solution:** Ensure you're logged in with correct subscription:
    ```bash
    az login
    az account set --subscription "<your-subscription-id>"
    azd auth login
    ```

??? question "Issue: Token acquisition fails"
    **Solution:** Ensure you're logged in with `az login` and have correct app registration:
    ```bash
    az login
    # Verify tenant
    az account show --query tenantId -o tsv
    # Re-run registration if needed
    ./scripts/register-entra-app.sh
    ```

??? question "Issue: Key Vault access denied"
    **Solution:** Verify Managed Identity has "Key Vault Secrets User" role:
    ```bash
    ./scripts/enable-managed-identity.sh
    # Check role assignments
    azd env get-values | grep AZURE_MANAGED_IDENTITY_PRINCIPAL_ID
    ```

??? question "Issue: JWT validation fails with 'Invalid audience'"
    **Solution:** Ensure AZURE_CLIENT_ID matches your Entra ID app:
    ```bash
    azd env get-values | grep -E "AZURE_CLIENT_ID|AZURE_TENANT_ID"
    # Verify these match your app registration in Azure Portal
    ```

??? question "Issue: Can't find deployed container app URL"
    **Solution:** Get deployment information:
    ```bash
    azd env get-values | grep URL
    # Or check in Azure Portal:
    # Resource Group → Container App → Overview → Application Url
    ```

---

---

← [Base Camp](base-camp.md) | [Camp 2: Gateway Security](camp2-gateway.md) →
