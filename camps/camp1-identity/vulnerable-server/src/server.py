"""Camp 1 - Vulnerable MCP Server

OWASP MCP Risks: MCP01, MCP07
"""
import os
from fastmcp import FastMCP, Context
from fastmcp.server.auth import StaticTokenVerifier

# VULNERABILITY: Token in environment variable
REQUIRED_TOKEN = os.getenv("REQUIRED_TOKEN", "camp1_demo_token_INSECURE")

USERS = {
    "user_001": {"name": "Alice Johnson", "email": "alice@example.com",
                 "ssn_last4": "1234", "balance": 15000.00},
    "user_002": {"name": "Bob Smith", "email": "bob@example.com",
                 "ssn_last4": "5678", "balance": 8500.00},
    "user_003": {"name": "Carol Williams", "email": "carol@example.com",
                 "ssn_last4": "9012", "balance": 22000.00}
}

auth = StaticTokenVerifier(
    tokens={REQUIRED_TOKEN: {"client_id": "user_001", "scopes": ["read", "write"]}}
)

mcp = FastMCP("Camp 1 Vulnerable Server", auth=auth)

def get_authenticated_user(ctx: Context) -> str:
    if hasattr(ctx, 'request_context') and ctx.request_context:
        if hasattr(ctx.request_context, 'access_token'):
            token_data = ctx.request_context.access_token
            if hasattr(token_data, 'client_id'):
                return token_data.client_id
    return "user_001"

@mcp.tool()
async def get_user_info(ctx: Context, user_id: str) -> dict:
    """Get user information."""
    authenticated_user = get_authenticated_user(ctx)
    if user_id != authenticated_user:
        raise PermissionError(f"Cannot access {user_id}'s data")
    
    user = USERS.get(user_id)
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    return {"user_id": user_id, **user, "server_type": "VULNERABLE"}

app = mcp.http_app(path="/mcp", transport="streamable-http")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
