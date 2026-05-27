---
hide:
  - toc
---

<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">Camp 1 · Validate</div>
      <h1>Validate Security</h1>
      <p>Run automated checks, exercise manual verification steps, and review the full before/after security posture before moving on to Camp 2.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">verified</span></span>
    </div>
  </div>
</div>

You've migrated secrets to Key Vault, enabled Managed Identity, and replaced the static token with OAuth 2.1 + JWT validation. Now it's time to prove all those security controls are actually in place. This waypoint runs an automated verification, walks through optional manual checks, and compares your secure server against the original vulnerable deployment.

## Waypoint 6: Validate Security

### Comprehensive Security Validation

Let's verify all security controls are properly configured:

=== "Bash"
    ```bash
    cd camps/camp1-identity
    ./scripts/verify-security.sh
    ```

=== "PowerShell"
    ```powershell
    cd camps/camp1-identity
    ./scripts/verify-security.ps1
    ```

This script performs comprehensive checks:

**Expected output:**

```
Camp 1: Security Validation
==============================
Loading azd environment...

Running security checks...

Check 1: Secrets in Key Vault
------------------------------
Found 2 secrets in Key Vault
Name                        Enabled
--------------------------  ---------
demo-api-key               True
external-service-secret    True

Check 2: Managed Identity RBAC
-------------------------------
Managed Identity has Key Vault Secrets User role
Role                        Scope
--------------------------  --------------------------------------------------
Key Vault Secrets User      /subscriptions/.../resourceGroups/.../providers/...

Check 3: Container App Identity
--------------------------------
Checking if container apps have managed identity assigned...
Name                        Identity
--------------------------  -----------
ca-sherpa-camp1-xxxxx      UserAssigned

==============================
Security Validation Complete!
==============================

Verified:
  - Secrets stored in Key Vault (not env vars)
  - Managed Identity has RBAC permissions
  - Container Apps use Managed Identity

Security posture: SECURE
   Ready for production!
```

---

### Manual Verification Steps (Optional - Extra Credit)

!!! tip "Extra Credit - Not Required"
    The automated script above validates all the essential security controls. The steps below are **optional** and provide hands-on experience with testing authentication and authorization failures. Great for deeper learning, but feel free to skip ahead to the Security Checklist!

??? example "Verify Token Expiration"

    Try using an old/expired token:

    === "Bash"
        ```bash
        # This should FAIL with "Token expired" or "Invalid token"
        curl -X POST ${SECURE_URL}/mcp \
        -H "Authorization: Bearer expired_or_old_token" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
        ```

    === "PowerShell"
        ```powershell
        # This should FAIL with "Token expired" or "Invalid token"
        curl.exe -X POST "$SECURE_URL/mcp" `
        -H "Authorization: Bearer expired_or_old_token" `
        -H "Content-Type: application/json" `
        -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
        ```

    **Expected:** 401 Unauthorized or similar error

??? example "Verify Audience Validation"

    Try using a token with wrong audience:

    === "Bash"
        ```bash
        # Get a token for a different resource (e.g., Microsoft Graph)
        WRONG_TOKEN=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)

        # This should FAIL because audience is wrong
        curl -X POST ${SECURE_URL}/mcp \
        -H "Authorization: Bearer $WRONG_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
        ```

    === "PowerShell"
        ```powershell
        # Get a token for a different resource (e.g., Microsoft Graph)
        $WRONG_TOKEN = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv

        # This should FAIL because audience is wrong
        curl.exe -X POST "$SECURE_URL/mcp" `
        -H "Authorization: Bearer $WRONG_TOKEN" `
        -H "Content-Type: application/json" `
        -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
        ```

    **Expected:** 401 Unauthorized - audience validation failed

??? example "Verify No Secrets in Environment Variables"

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
| **Production Ready** | :material-close: Security vulnerabilities | :material-check: Enterprise-grade security |

---

## Summit View: What We Fixed

| Vulnerability | Solution | OWASP Risk Mitigated |
|---------------|----------|---------------------|
| **Hardcoded tokens** | OAuth 2.1 with Entra ID | MCP01 (Token Mismanagement & Secret Exposure), MCP07 (Insufficient Authentication & Authorization) |
| **Tokens never expire** | JWT with expiration (~1 hour) | MCP01 (Token Mismanagement & Secret Exposure) |
| **Secrets in env vars** | Azure Key Vault | MCP01 (Token Mismanagement & Secret Exposure) |
| **No audience validation** | JWTVerifier with `aud` check | MCP07 (Insufficient Authentication & Authorization) |
| **Password-based auth** | Managed Identity | MCP01 (Token Mismanagement & Secret Exposure), MCP02 (Privilege Escalation via Scope Creep) |
| **Over-privileged access** | Least-privilege RBAC | MCP02 (Privilege Escalation via Scope Creep) |

---

## Cleanup

When you're done with Camp 1, remove all Azure resources:

```bash
# Delete all resources
azd down --force --purge
```

**Optional:** Delete the Entra ID application:

=== "Bash"
    ```bash
    # Get app ID
    APP_ID=$(azd env get-value AZURE_CLIENT_ID)

    # Delete app
    az ad app delete --id $APP_ID
    ```

=== "PowerShell"
    ```powershell
    # Get app ID
    $APP_ID = azd env get-value AZURE_CLIENT_ID

    # Delete app
    az ad app delete --id $APP_ID
    ```

---

[Continue: Camp 2 Gateway Security →](../camp2-gateway/index.md){ .md-button .md-button--primary }

← [OAuth & JWT](section4-oauth-jwt.md) | [Camp 2: Gateway Security →](../camp2-gateway/index.md)
