"""
Base Camp Vulnerable MCP Server

This server demonstrates OWASP MCP07 (Insufficient Authentication & Authorization)
and MCP01 (Token Mismanagement & Secret Exposure).

VULNERABILITIES PRESENT (for educational purposes):
1. No authentication - anyone can connect via HTTP
2. No authorization - anyone can access any user's data
3. No audit logging - no record of who accessed what

This is intentionally insecure for workshop demonstration!
Runs as HTTP server with SSE transport for production-like testing.
"""

from fastmcp import FastMCP
from .data import USERS

# Create FastMCP server instance
mcp = FastMCP("Base Camp Vulnerable Server")


# VULNERABILITY: No authentication check!
# Any client can request ANY user's data over HTTP
@mcp.resource("user://{user_id}")
async def get_user_resource(user_id: str) -> str:
    """
    Get user data as a resource.
    
    🚨 VULNERABILITY: No authentication check!
    Anyone on the network can access this HTTP endpoint
    and retrieve any user's sensitive data.
    """
    user = USERS.get(user_id)
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    return f"""Name: {user['name']}
Email: {user['email']}
SSN: ***-**-{user['ssn_last4']}
Balance: ${user['balance']:,.2f}

⚠️  WARNING: This data was accessed without authentication via HTTP!"""


# VULNERABILITY: Tool also has no auth check
@mcp.tool()
async def get_user_info(user_id: str) -> dict:
    """
    Get detailed user information.
    
    🚨 VULNERABILITY: Anyone can call this tool via HTTP POST!
    No authorization or authentication checks.
    
    Args:
        user_id: The user ID (e.g., user_001, user_002, user_003)
    
    Returns:
        User information dictionary
    """
    user = USERS.get(user_id)
    if not user:
        raise ValueError(f"User {user_id} not found")
    
    return {
        "user_id": user_id,
        "name": user["name"],
        "email": user["email"],
        "ssn_last4": user["ssn_last4"],
        "balance": user["balance"],
        "warning": "⚠️ This data was accessed without authentication via HTTP!"
    }


# Run as HTTP server
if __name__ == "__main__":
    import uvicorn
    
    print("=" * 70)
    print("🏔️  Base Camp - Vulnerable MCP Server (HTTP/SSE)")
    print("=" * 70)
    print(f"Server Name: {mcp.name}")
    print(f"Available Resources: {len(USERS)} user records")
    print("Listening on: http://0.0.0.0:8000")
    print("")
    print("⚠️  WARNING: This server has NO AUTHENTICATION!")
    print("   Anyone on the network can access ANY user's sensitive data via HTTP.")
    print("   This is intentionally insecure for workshop demonstration.")
    print("")
    print("🚨 OWASP MCP07: Insufficient Authentication & Authorization")
    print("🚨 OWASP MCP01: Token Mismanagement & Secret Exposure")
    print("=" * 70)
    print("")
    print("Connect via MCP Inspector:")
    print("  Transport: Streamable HTTP")
    print("  URL: http://localhost:8000/mcp")
    print("=" * 70)
    print("")
    
    # Create ASGI app
    app = mcp.http_app(path="/mcp")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
