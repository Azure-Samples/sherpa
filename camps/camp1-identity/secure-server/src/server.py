"""Camp 1 - Secure MCP Server

OWASP MCP Risks Addressed: MCP01, MCP02, MCP07
"""
import os
from fastmcp import FastMCP, Context
from fastmcp.server.auth.providers.jwt import JWTVerifier
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

TENANT_ID = os.getenv("AZURE_TENANT_ID")
CLIENT_ID = os.getenv("AZURE_CLIENT_ID")
KEY_VAULT_URL = os.getenv("KEY_VAULT_URL")

def get_keyvault_secret(secret_name: str) -> str:
    if not KEY_VAULT_URL:
        return f"[NOT_CONFIGURED:{secret_name}]"
    try:
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
        return client.get_secret(secret_name).value
    except Exception as e:
        return f"[ERROR:{secret_name}]"

USERS = {
    "user_001": {"name": "Alice Johnson", "email": "alice@example.com",
                 "ssn_last4": "1234", "balance": 15000.00},
    "user_002": {"name": "Bob Smith", "email": "bob@example.com",
                 "ssn_last4": "5678", "balance": 8500.00},
    "user_003": {"name": "Carol Williams", "email": "carol@example.com",
                 "ssn_last4": "9012", "balance": 22000.00}
}

auth = JWTVerifier(
    jwks_uri=f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys",
    audience=CLIENT_ID,  # Resource Indicator - rejects wrong audience!
    issuer=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"
)

mcp = FastMCP("Camp 1 Secure Server", auth=auth)

@mcp.tool()
async def get_user_info(ctx: Context, user_id: str) -> dict:
    """Get user information (SECURE)."""
    # In production, extract user from JWT claims
    authenticated_user = "user_001"
    if user_id != authenticated_user:
        raise PermissionError(f"Cannot access {user_id}'s data")
    
    user = USERS.get(user_id)
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    return {"user_id": user_id, **user, "server_type": "SECURE",
            "security": ["JWT validated", "Audience checked", "Key Vault secrets"]}

app = mcp.http_app(path="/mcp", transport="streamable-http")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
