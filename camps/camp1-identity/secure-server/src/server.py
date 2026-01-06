"""Camp 1 - Secure MCP Server with PRM Support

This server implements:
- JWT validation with Entra ID
- Audience (Resource Indicator) validation
- Key Vault integration via Managed Identity
- Protected Resource Metadata (PRM) for VS Code auto-auth

OWASP MCP Risks Addressed: MCP01, MCP02, MCP07
"""
import os
from fastmcp import FastMCP, Context
from fastmcp.server.auth.providers.jwt import JWTVerifier
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from starlette.responses import JSONResponse
from starlette.routing import Route

# Configuration
TENANT_ID = os.getenv("AZURE_TENANT_ID")
CLIENT_ID = os.getenv("AZURE_CLIENT_ID")
KEY_VAULT_URL = os.getenv("KEY_VAULT_URL")
RESOURCE_URL = os.getenv("RESOURCE_URL")  # Public HTTPS URL for PRM

# Validate critical configuration
if not all([TENANT_ID, CLIENT_ID]):
    raise ValueError(
        "Missing required environment variables: AZURE_TENANT_ID and/or AZURE_CLIENT_ID. "
        "These must be set for OAuth authentication."
    )

# ============================================================================
# KEY VAULT INTEGRATION
# ============================================================================

def get_keyvault_secret(secret_name: str) -> str:
    """Retrieve secret from Key Vault via Managed Identity."""
    if not KEY_VAULT_URL:
        return f"[NOT_CONFIGURED:{secret_name}]"
    try:
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
        return client.get_secret(secret_name).value
    except Exception as e:
        print(f"Key Vault error: {e}")
        return f"[ERROR:{secret_name}]"

# ============================================================================
# MCP SERVER WITH JWT VALIDATION
# ============================================================================

# Create JWT verifier for Entra ID tokens
auth = JWTVerifier(
    jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys",
    audience=CLIENT_ID,  # Resource Indicator validation!
    issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"
)

mcp = FastMCP("Camp 1 Secure Server", auth=auth)

# User data (same as vulnerable server for comparison)
USERS = {
    "user_001": {"name": "Alice Johnson", "email": "alice@example.com",
                 "ssn_last4": "1234", "balance": 15000.00},
    "user_002": {"name": "Bob Smith", "email": "bob@example.com",
                 "ssn_last4": "5678", "balance": 8500.00},
    "user_003": {"name": "Carol Williams", "email": "carol@example.com",
                 "ssn_last4": "9012", "balance": 22000.00}
}

@mcp.tool()
async def get_user_info(ctx: Context, user_id: str) -> dict:
    """Get user information (secure version with JWT auth)."""
    user = USERS.get(user_id)
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    return {
        "user_id": user_id,
        **user,
        "server_type": "SECURE",
        "security": ["JWT validated", "Audience checked", "PRM enabled"]
    }

# ============================================================================
# COMBINED APPLICATION WITH PRM ENDPOINT
# ============================================================================

# Protected Resource Metadata endpoint (RFC 9728)
async def prm_endpoint(request):
    """Return Protected Resource Metadata for OAuth discovery."""
    return JSONResponse({
        "resource": RESOURCE_URL or "https://localhost",
        "authorization_servers": [f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"],
        "scopes_supported": [f"api://{CLIENT_ID}/access_as_user"],
        "bearer_methods_supported": ["header"]
    })

# Create the MCP app at /mcp path
app = mcp.http_app(path="/mcp", transport="streamable-http")

# Add PRM route to the app
from starlette.routing import Mount
app.routes.insert(0, Route("/.well-known/oauth-protected-resource", prm_endpoint))

if __name__ == "__main__":
    import uvicorn
    print("=" * 60)
    print("Camp 1 Secure Server with PRM")
    print("=" * 60)
    print(f"PRM Endpoint: /.well-known/oauth-protected-resource")
    print(f"MCP Endpoint: /mcp")
    print("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=8000)
