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

    ??? info "What is StaticTokenVerifier? (Optional - Skip if you completed Base Camp)"
        If you skipped Base Camp, here's what you need to know:
        
        **StaticTokenVerifier** is a simple (and insecure) authentication method that checks incoming requests against a hardcoded list of valid tokens:
        
        ```python
        # Example: How the vulnerable server "authenticates"
        auth = StaticTokenVerifier(
            tokens={
                "camp1_demo_token_INSECURE": {"client_id": "user_001"}
            }
        )
        ```
        
        **Why this is insecure:**
        
        - **Tokens are hardcoded** - Stored in plain text in environment variables
        - **No expiration** - Once issued, valid forever
        - **No rotation** - Can't change tokens without redeploying
        - **No cryptographic validation** - Just string matching
        - **No user context** - Can't tell who's actually using the token
        - **Easy to steal** - Visible in Portal, logs, and code
        
        In this camp, we'll migrate from this vulnerable pattern to **JWTVerifier** with OAuth 2.1, which solves all these problems using industry-standard authentication with Microsoft Entra ID.

    Let's start by provisioning the Azure infrastructure and deploying both servers:

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

    ❌ **Token stored in plain-text environment variables**  
    ❌ **Token never expires**  
    ❌ **No audience validation**  
    ❌ **Secrets visible in Azure Portal**

    This demonstrates **OWASP MCP01 (Token Mismanagement)** and **MCP07 (Insufficient Auth)** in a cloud environment!

    ### Save Your Deployment Information

    ```bash
    # Get your deployment info
    azd env get-values | grep -E "VULNERABLE_SERVER_URL|SECURE_SERVER_URL|AZURE_RESOURCE_GROUP|AZURE_KEY_VAULT"
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

    ??? danger "Security Impact: Double Threat"
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

    ---

    ### Step 5a: Register Entra ID Application

    This script creates and configures an Entra ID app registration with:

    - **OAuth 2.1 scope** (`access_as_user`) for delegated permissions
    - **Device Code Flow** support for CLI authentication  
    - **Authorization Code + PKCE** support for browser-based flows
    - **Protected Resource Metadata (PRM)** endpoints for OAuth discovery
    - **Pre-authorized clients:**
        - Azure CLI (`04b07795-8ddb-461a-bbee-02f9e1bf7b46`) - for Device Code Flow
        - VS Code (`aebc6443-996d-45c2-90f0-388ff96faa56`) - for future MCP client support

    This enables both authentication methods (Option A and B) with a single registration.

    ```bash
    cd camps/camp1-identity
    ./scripts/register-entra-app.sh
    ```

    **Expected output:**

    ```
    🔐 Camp 1: Register Entra ID Application
    ========================================
    Creating Entra ID app registration: sherpa-mcp-camp1-1234567890

    ✅ App ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Setting identifier URI...
    Exposing API scope...
    ✅ API scope created
    Pre-authorizing clients (Azure CLI + VS Code)...
    ✅ Clients pre-authorized
    ✅ Redirect URIs configured
       Public client: device code flow
       Web: VS Code OAuth, demo client (port 8090)
    ✅ Client type configured (confidential - supports client secrets)

    ✅ Entra ID Application Registered!
    ====================================
    App Name: sherpa-mcp-camp1-1234567890
    Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Tenant ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
    Identifier URI: api://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

    ✅ Pre-authorized clients:
       - Azure CLI (for Device Code Flow)
       - VS Code (for PRM-based authentication)
    
    ✅ Redirect URIs configured:
       - urn:ietf:wg:oauth:2.0:oob (device code flow)
       - http://127.0.0.1:33418 (VS Code)
       - https://vscode.dev/redirect (VS Code)
       - http://localhost:8090/callback (demo client)

    📝 Save these values - you'll need them for deployment!

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

    ```bash
    ./scripts/configure-secure-server.sh
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
        
        ❌ User tokens would have the wrong `aud` (audience) claim  
        ❌ JWT validation would fail with "Invalid audience"  
        ❌ Users couldn't authenticate even with valid tokens

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
    
    :material-check: `JWTVerifier` for token validation  
    :material-check: Protected Resource Metadata (PRM) endpoint at `/.well-known/oauth-protected-resource`  
    :material-check: Audience validation (checks the `aud` claim)  
    :material-check: Expiration checking (rejects expired tokens)  
    :material-check: Signature validation (ensures token not tampered)  
    :material-check: Issuer validation (confirms token from correct Entra ID tenant)

    **What's different in the code:**

    ```python
    # Before (vulnerable server):
    auth = StaticTokenVerifier(
        tokens={"camp1_demo_token_INSECURE": {"client_id": "user_001"}}
    )
    
    # After (secure server):
    auth = JWTVerifier(
        jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys",
        audience=CLIENT_ID,  # ✅ Audience validation!
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

    #### Option A: Device Code Flow (Understanding OAuth)

    **Best for:** Learning OAuth mechanics, CLI automation, headless environments

    This flow helps you understand JWT tokens by making them visible:

    ```bash
    ./scripts/get-mcp-token.sh
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

    ```bash
    # Copy the token from script output and set it
    TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIs..."
    ```

    **Test with curl:**

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

    ??? warning "Troubleshooting authentication issues"
        **Problem: No session ID received (empty response)**
        
        This usually means authentication failed. Check:
        
        1. **Is your token expired?**
           ```bash
           # Decode your token at jwt.ms or check expiration
           echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .exp
           # Compare to current time: date +%s
           ```
           
           Tokens expire after ~1 hour. Get a new token:
           ```bash
           ./scripts/get-mcp-token.sh
           TOKEN="<new-token>"
           ```
        
        2. **Is the audience correct?**
           ```bash
           # Check the 'aud' claim in your token
           echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .aud
           
           # Compare to your CLIENT_ID
           azd env get-values | grep AZURE_CLIENT_ID
           ```
           
           If they don't match, you may need to:
           - Ensure `configure-secure-server.sh` was run
           - Verify `AZURE_CLIENT_ID` is set correctly in the Container App
        
        3. **See the full error response:**
           ```bash
           # Remove the SESSION_ID extraction to see full output
           curl -v -X POST ${SECURE_URL}/mcp \
             -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             -H "Accept: application/json, text/event-stream" \
             -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl-test","version":"1.0"}},"id":1}'
           ```
           
           Look for:
           - `401 Unauthorized` - Token is invalid/expired/wrong audience
           - `403 Forbidden` - Token valid but lacks permissions
           - `500 Internal Server Error` - Server configuration issue
        
        **Problem: curl shows transfer stats but no output**
        
        This happens when the response has no body. Check:
        
        ```bash
        # Use -v flag to see headers and status code
        curl -v -X POST ${SECURE_URL}/mcp \
          -H "Authorization: Bearer $TOKEN" \
          -H "mcp-session-id: ${SESSION_ID}" \
          -H "Content-Type: application/json" \
          -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
        ```
        
        Common causes:
        - Missing or invalid `mcp-session-id` header
        - Wrong HTTP method (should be POST)
        - Incorrect endpoint URL

    **What you just did:**

    :material-check: Authenticated with a **JWT token** (expires in ~1 hour, not forever!)  
    :material-check: Server **validated the token signature** against Entra ID public keys  
    :material-check: Server **checked the audience** (token is for THIS app, not another)  
    :material-check: Server **verified expiration** (token is still valid)  
    :material-check: Successfully called MCP methods with OAuth 2.1 security!

    ---

    #### Option B: Authorization Code + PKCE Demo (Production OAuth Flow)

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
    
    ```bash
    ./scripts/generate-client-secret.sh
    ```
    
    This creates a client secret for local testing (expires in 30 days). The secret is saved to `demo-client/.env` and is git-ignored.
    
    !!! note "Client Secrets in Production"
        This demo uses a client secret for simplicity, but production public clients should use:

        - Device Code Flow (Option A) for CLI tools
        - Authorization Code + PKCE without secrets for native/mobile apps
        - Or implement backend-for-frontend (BFF) pattern
        
        Client secrets are appropriate for confidential clients (server-to-server) but not for public clients in production.
    
    **Step 3: Run the demo**
    
    ```bash
    # Get your configuration
    eval "$(azd env get-values | sed 's/^/export /')"
    
    # Run the demo (uv handles dependencies automatically)
    cd demo-client
    uv run --project .. python mcp_prm_client.py \
      "${SECURE_SERVER_URL}" \
      "${AZURE_CLIENT_ID}"
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

    :material-check: **PRM Discovery** - Server told client how to authenticate (RFC 9728)  
    :material-check: **OAuth Server Discovery** - Client found Entra ID endpoints automatically  
    :material-check: **PKCE Flow** - Secure authorization code exchange with proof key  
    :material-check: **JWT Token** - Received signed token from Entra ID (expires in ~1 hour)  
    :material-check: **Authenticated MCP** - Made MCP requests with Bearer token  

    This is exactly how production MCP clients will work once they fully implement PRM support!

    ??? tip "Explore the Demo Code"
        The demo client is fully commented and demonstrates:
        
        - PRM discovery from WWW-Authenticate header
        - OAuth server metadata parsing
        - PKCE code challenge generation
        - Local callback server for authorization code
        - Token exchange with client authentication
        - MCP JSON-RPC requests with Bearer token
        
        See `demo-client/README.md` and `demo-client/mcp_prm_client.py` in the [camp1-identity directory](https://github.com/Azure-Samples/sherpa/tree/main/camps/camp1-identity/demo-client) for implementation details.

    #### Verify PRM Endpoint Manually

    You can also check the PRM endpoint directly:

    ```bash
    SECURE_URL=$(azd env get-values | grep SECURE_SERVER_URL | cut -d= -f2 | tr -d '"')
    
    # Check WWW-Authenticate header on 401
    curl -i "${SECURE_URL}/mcp" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"initialize","id":1}'
    ```

    **Look for:**
    ```
    HTTP/2 401
    www-authenticate: Bearer resource_metadata="https://your-server/.well-known/oauth-protected-resource"
    ```

    **Fetch the PRM metadata:**
    ```bash
    curl -s "${SECURE_URL}/.well-known/oauth-protected-resource" | jq .
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
    
    :material-check: **Signature:** Token cryptographically signed by Entra ID (not tampered)  
    :material-check: **Issuer (`iss`):** Token from correct Entra ID tenant  
    :material-check: **Audience (`aud`):** Token intended for THIS server (prevents confused deputy)  
    :material-check: **Expiration (`exp`):** Token not expired  
    :material-check: **Not Before (`nbf`):** Token is valid now (not used too early)

    **Decode your JWT at [jwt.ms](https://jwt.ms) to see the claims!**

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
    | **Authentication** | Static token (`camp1_demo_token_INSECURE`) | OAuth 2.1 JWT with Entra ID |
    | **Token Storage** | Hardcoded in env var (visible in Portal) | Not applicable - JWT per request |
    | **Token Expiration** | Never | ~1 hour |
    | **Token Revocation** | Impossible | Possible via Entra ID |
    | **Token Tampering** | Possible (plain string) | Cryptographically prevented (signed JWT) |
    | **Audience Validation** | No - token works for any service | Yes - `aud` claim prevents confused deputy |
    | **User Context** | Generic `client_id` only | Rich claims (name, email, roles, tenant) |
    | **Token Rotation** | Manual, risky | Automatic via token refresh |
    | **Client Discovery** | Manual configuration | PRM (RFC 9728) enables zero-config |
    | **Azure Credentials** | Connection strings in env vars | Managed Identity (passwordless) |
    | **Secrets Management** | Environment variables | Azure Key Vault |
    | **RBAC** | Not applicable | Least-privilege (Key Vault Secrets User) |
    | **Audit Logs** | None | Azure Monitor tracks all access |
    | **Production Ready** | ❌ Security vulnerabilities | ✅ Enterprise-grade security |

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
