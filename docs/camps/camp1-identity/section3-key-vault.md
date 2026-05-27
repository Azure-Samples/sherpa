---
hide:
  - toc
---

<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">Camp 1 · Key Vault</div>
      <h1>Migrate Secrets to Key Vault</h1>
      <p>Move every secret out of environment variables into Azure Key Vault with least-privilege RBAC.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">vpn_key</span></span>
    </div>
  </div>
</div>

With Managed Identity in place, your secure server has a passwordless way to talk to Azure. Now we'll move every demo secret out of environment variables and into Key Vault, fetched at runtime via that Managed Identity.

??? info "What is Azure Key Vault?"
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

## Waypoint 4: Migrate Secrets to Key Vault

### How It All Fits Together

In Waypoint 3, you enabled Managed Identity. Now let's see how it connects to Key Vault:

```
 ___ ___ ___ ___  ___ ___      ← Vulnerable: secrets in env vars
| _ ) __| __/ _ \| _ \ __|
| _ \ _|| _| (_) |   / _|
|___/___|_| \___/|_|_\___|

      ┌──────────────────────────────────────────────┐
      │                Container App                 │
      │   env:  REQUIRED_TOKEN = "camp1_demo_…"      │
      └────────────────────┬─────────────────────────┘
                           │  exposed in
                           ▼
               ┌────────────────────────┐
               │      Azure Portal      │
               │  Anyone with "Reader"  │
               │   on the resource      │
               │   group sees it 🙈     │
               └────────────────────────┘


   _   ___ _____ ___ ___        ← Secure: passwordless via Managed Identity
  /_\ | __|_   _| __| _ \
 / _ \| _|  | | | _||   /
/_/ \_\_|   |_| |___|_|_\

      ┌──────────────────────────────────────────────┐
      │                Container App                 │
      │           (no secrets in env vars)           │
      └────────────────────┬─────────────────────────┘
                           │ ① present Managed Identity  ("I am app X")
                           ▼
               ┌────────────────────────┐
               │     Microsoft Entra    │
               │   issues short-lived   │
               │      AAD token         │
               └───────────┬────────────┘
                           │ ② present token to Key Vault
                           ▼
               ┌────────────────────────┐
               │       Key Vault        │
               │  ③ RBAC check passes   │
               │  (Secrets User role)   │
               └───────────┬────────────┘
                           │ ④ secret returned over TLS,
                           ▼    held only in app memory
               ┌────────────────────────┐
               │   Container App now    │
               │   has the secret —     │
               │   nothing on disk      │
               └────────────────────────┘
```

**The passwordless flow:**

1. **Container App presents its Managed Identity** — "I am app X"
2. **Microsoft Entra issues a short-lived AAD token** — scoped to Key Vault
3. **Key Vault validates the token via RBAC** — "App X has the Key Vault Secrets User role"
4. **Secret returned over TLS** — never persisted to env vars or disk

**Key insight:** Your application code never sees a password, key, or connection string for Azure authentication. The Managed Identity handles everything automatically through `DefaultAzureCredential()`.

---

### Create Secrets in Key Vault

Let's migrate demo secrets from environment variables to Key Vault:

=== "Bash"
    ```bash
    cd camps/camp1-identity
    ./scripts/migrate-to-keyvault.sh
    ```

=== "PowerShell"
    ```powershell
    cd camps/camp1-identity
    ./scripts/migrate-to-keyvault.ps1
    ```

This script:

- Creates sample secrets in your Key Vault
- `demo-api-key` - Example API key
- `external-service-secret` - Example service credential

**Expected output:**

```
Camp 1: Migrate Secrets to Key Vault
=======================================
Loading azd environment...
Creating demo secrets in Key Vault: kv-sherpa-camp1-xxxxx

Creating demo-api-key...
Creating external-service-secret...

Secrets created in Key Vault!

Current secrets:
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

---

[Continue: OAuth & JWT →](section4-oauth-jwt.md){ .md-button .md-button--primary }

← [Managed Identity](section2-managed-identity.md) | [OAuth & JWT →](section4-oauth-jwt.md)
