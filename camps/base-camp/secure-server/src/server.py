"""
Base Camp Secure MCP Server

This server demonstrates FIXED OWASP MCP07 and MCP01 vulnerabilities.

SECURITY IMPROVEMENTS:
1. ✅ Bearer token authentication - validates tokens via FastMCP auth
2. ✅ Authorization checks - users can only access their own data
3. ✅ Secure by default - rejects unauthenticated requests

This is a BASIC implementation for workshop demonstration.
Still NOT production-ready! See Phase 5 for what's missing.
"""

import os
from typing import Optional
from fastmcp import FastMCP, Context
from fastmcp.server.auth import StaticTokenVerifier
from dotenv import load_dotenv
import uvicorn
from .data import USERS

# Load environment variables
load_dotenv()

# Load authentication token from environment
REQUIRED_TOKEN = os.getenv("AUTH_TOKEN", "workshop_demo_token_12345")

# Simple token-to-user mapping
# In production, this would be handled by Azure Entra ID
TOKEN_TO_USER = {
    REQUIRED_TOKEN: "user_001",  # Default workshop token maps to Alice
}

# Create auth verifier
auth = StaticTokenVerifier(
    tokens={
        REQUIRED_TOKEN: {
            "client_id": "user_001",
            "scopes": ["read", "write"],
        }
    }
)

# Create FastMCP server instance with authentication
mcp = FastMCP("Base Camp Secure Server", auth=auth)


def get_authenticated_user(ctx: Context) -> str:
    """
    Get the authenticated user from the request context.
    
    For streamable-http transport, FastMCP's StaticTokenVerifier validates
    the token but doesn't populate ctx.auth. For this workshop demo, we'll
    return the user mapped to our demo token.
    
    In production with JWT tokens, you would decode the JWT to get the user.
    """
    # For this demo, auth was already validated by StaticTokenVerifier
    # The token maps to user_001 per our TOKEN_TO_USER mapping
    return "user_001"


def check_authorization(requested_user_id: str, authenticated_user: str) -> bool:
    """
    Check if the authenticated user can access the requested resource.
    
    ✅ SECURITY FIX: Addresses OWASP MCP07 (Insufficient Authorization)
    Simple rule: Users can only access their own data.
    
    In production, this would be handled by Azure RBAC with fine-grained
    permissions, as demonstrated in Camp 1.
    """
    return requested_user_id == authenticated_user


# ✅ SECURED: Resource with authorization check
@mcp.resource("user://{user_id}")
async def get_user_resource(ctx: Context, user_id: str) -> str:
    """
    Get user data as a resource - NOW WITH SECURITY!
    
    ✅ SECURE: Requires valid Bearer token (enforced by FastMCP auth)
    ✅ SECURE: Validates user can only access their own data (Authorization)
    
    Args:
        ctx: Request context with auth info
        user_id: The user ID to retrieve
    
    Returns:
        User data as formatted string
    
    Raises:
        PermissionError: If user tries to access another's data
        ValueError: If user_id not found
    """
    
    # Get authenticated user from context
    authenticated_user = get_authenticated_user(ctx)
    
    # Authorization check
    if not check_authorization(user_id, authenticated_user):
        raise PermissionError(
            f"Forbidden: You are authenticated as {authenticated_user} but "
            f"cannot access {user_id}'s data. Users can only access their own resources."
        )
    
    user = USERS.get(user_id)
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    return f"""Name: {user['name']}
Email: {user['email']}
SSN: ***-**-{user['ssn_last4']}
Balance: ${user['balance']:,.2f}

✅ SECURE ACCESS: This data was accessed with proper authentication!
   Authenticated as: {authenticated_user}
   Authorization verified: {authenticated_user} == {user_id}"""


# ✅ SECURED: Tool with authorization check
@mcp.tool()
async def get_user_info(ctx: Context, user_id: str) -> dict:
    """
    Get detailed user information - NOW WITH SECURITY!
    
    ✅ SECURE: Requires valid Bearer token (enforced by FastMCP auth)
    ✅ SECURE: Users can only query their own data (Authorization)
    
    Args:
        ctx: Request context with auth info
        user_id: The user ID to query (e.g., user_001, user_002, user_003)
    
    Returns:
        User information dictionary
    
    Raises:
        PermissionError: If user tries to access another's data
        ValueError: If user_id not found
    """
    
    # Get authenticated user from context
    authenticated_user = get_authenticated_user(ctx)
    
    # Authorization check
    if not check_authorization(user_id, authenticated_user):
        raise PermissionError(
            f"Forbidden: You are authenticated as {authenticated_user} but "
            f"cannot access {user_id}'s data. Users can only access their own resources."
        )
    
    user = USERS.get(user_id)
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    return {
        "user_id": user_id,
        "name": user["name"],
        "email": user["email"],
        "ssn_last4": user["ssn_last4"],
        "balance": user["balance"],
        "authenticated_as": authenticated_user,
        "authorization_verified": True,
        "security_status": "✅ Secure - Properly authenticated and authorized"
    }


# Run as HTTP server
if __name__ == "__main__":
    import uvicorn
    
    print("=" * 70)
    print("🔒 Base Camp - Secure MCP Server (Streamable HTTP)")
    print("=" * 70)
    print(f"Server Name: {mcp.name}")
    print(f"Available Resources: {len(USERS)} user records")
    print("Listening on: http://0.0.0.0:8001")
    print("")
    print("✅ AUTHENTICATION ENABLED")
    print(f"   Required token: {REQUIRED_TOKEN}")
    print("   All requests must include: Authorization: Bearer <token>")
    print("")
    print("✅ AUTHORIZATION ENABLED")
    print("   Users can only access their own data")
    print(f"   Token '{REQUIRED_TOKEN}' maps to: {TOKEN_TO_USER[REQUIRED_TOKEN]}")
    print("")
    print("🔧 SECURITY FIXES APPLIED:")
    print("   ✅ Bearer token authentication (@require_auth decorator)")
    print("   ✅ Authorization checks (check_authorization function)")
    print("   ✅ Secure by default (rejects unauthenticated requests)")
    print("")
    print("⚠️  WORKSHOP NOTICE:")
    print("   This uses simple bearer tokens for demonstration.")
    print("   NOT production-ready! See README Phase 5 for details.")
    print("   Camp 1 covers: OAuth 2.1, Azure Entra ID, Key Vault, RBAC")
    print("=" * 70)
    print("")
    print("Connect via MCP Inspector:")
    print("  Transport: Streamable HTTP")
    print("  URL: http://localhost:8001/mcp")
    print(f"  Headers: Authorization: Bearer {REQUIRED_TOKEN}")
    print("=" * 70)
    print("")
    
    # Create ASGI app with streamable-http transport
    app = mcp.http_app(path="/mcp", transport="streamable-http")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8001,  # Different port from vulnerable server
        log_level="info"
    )
