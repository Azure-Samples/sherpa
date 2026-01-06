"""Camp 1 - Secure MCP Server with PRM Support

This server implements:
- JWT validation with Entra ID
- Audience (Resource Indicator) validation
- Key Vault integration via Managed Identity
- Protected Resource Metadata (PRM) for VS Code auto-auth
- Proper WWW-Authenticate header per RFC 9728

OWASP MCP Risks Addressed: MCP01, MCP02, MCP07
"""
import os
from fastmcp import FastMCP, Context
from fastmcp.server.auth.providers.jwt import JWTVerifier
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from starlette.responses import JSONResponse, Response
from starlette.routing import Route
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.cors import CORSMiddleware

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
# PRM MIDDLEWARE - Adds WWW-Authenticate header per RFC 9728
# ============================================================================

class PRMAuthenticateMiddleware(BaseHTTPMiddleware):
    """
    Middleware that ensures 401 responses include the WWW-Authenticate header
    with the resource_metadata parameter pointing to our PRM endpoint.
    
    Per RFC 9728 Section 5.1, when a protected resource returns 401,
    it MUST include a WWW-Authenticate header with the resource_metadata
    parameter so clients can discover how to authenticate.
    
    This is CRITICAL for VS Code MCP client auto-auth to work!
    """
    
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        
        # Only modify 401 responses that don't already have proper WWW-Authenticate
        if response.status_code == 401:
            # Build the PRM URL
            # Use RESOURCE_URL if set, otherwise construct from request
            if RESOURCE_URL:
                base_url = RESOURCE_URL.rstrip('/')
            else:
                # Fallback: construct from request (works for local testing)
                scheme = request.headers.get("x-forwarded-proto", request.url.scheme)
                host = request.headers.get("x-forwarded-host", request.url.netloc)
                base_url = f"{scheme}://{host}"
            
            prm_url = f"{base_url}/.well-known/oauth-protected-resource"
            
            # Set WWW-Authenticate header per RFC 9728 Section 5.1
            # Format: Bearer resource_metadata="<URL>"
            www_authenticate = f'Bearer resource_metadata="{prm_url}"'
            
            # Check if there's an existing WWW-Authenticate header
            existing_header = response.headers.get("WWW-Authenticate", "")
            if existing_header and "resource_metadata" not in existing_header:
                # Append our parameter to existing header
                www_authenticate = f'{existing_header}, resource_metadata="{prm_url}"'
            
            # We need to create a new response since headers may be immutable
            # Read the body from the original response
            body = b""
            async for chunk in response.body_iterator:
                body += chunk
            
            new_response = Response(
                content=body,
                status_code=401,
                headers=dict(response.headers),
                media_type=response.media_type
            )
            new_response.headers["WWW-Authenticate"] = www_authenticate
            
            return new_response
        
        # Also handle 403 for insufficient scope errors (per MCP spec)
        if response.status_code == 403:
            if RESOURCE_URL:
                base_url = RESOURCE_URL.rstrip('/')
            else:
                scheme = request.headers.get("x-forwarded-proto", request.url.scheme)
                host = request.headers.get("x-forwarded-host", request.url.netloc)
                base_url = f"{scheme}://{host}"
            
            prm_url = f"{base_url}/.well-known/oauth-protected-resource"
            
            body = b""
            async for chunk in response.body_iterator:
                body += chunk
            
            new_response = Response(
                content=body,
                status_code=403,
                headers=dict(response.headers),
                media_type=response.media_type
            )
            # For 403, include error type per RFC 6750 Section 3.1
            new_response.headers["WWW-Authenticate"] = (
                f'Bearer error="insufficient_scope", '
                f'resource_metadata="{prm_url}"'
            )
            
            return new_response
        
        return response

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

@mcp.tool()
async def get_secret_from_vault(ctx: Context, secret_name: str) -> dict:
    """Retrieve a secret from Azure Key Vault (demonstrates Managed Identity)."""
    value = get_keyvault_secret(secret_name)
    return {
        "secret_name": secret_name,
        "retrieved": True if not value.startswith("[") else False,
        "source": "Azure Key Vault via Managed Identity"
    }

# ============================================================================
# PROTECTED RESOURCE METADATA ENDPOINT (RFC 9728)
# ============================================================================

async def prm_endpoint(request):
    """
    Return Protected Resource Metadata for OAuth discovery.
    
    Per RFC 9728, this endpoint tells MCP clients:
    - What resource this server protects
    - Which authorization server(s) can issue valid tokens
    - What scopes are supported
    - How to present bearer tokens
    
    VS Code will fetch this endpoint after receiving a 401 with
    the resource_metadata parameter in WWW-Authenticate header.
    """
    # Build the resource URL
    if RESOURCE_URL:
        resource = RESOURCE_URL.rstrip('/')
    else:
        scheme = request.headers.get("x-forwarded-proto", request.url.scheme)
        host = request.headers.get("x-forwarded-host", request.url.netloc)
        resource = f"{scheme}://{host}"
    
    return JSONResponse({
        # The resource identifier (RFC 8707) - this is the audience for tokens
        "resource": resource,
        
        # Authorization server(s) that can issue valid tokens for this resource
        # VS Code will use this to initiate the OAuth flow
        "authorization_servers": [
            f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"
        ],
        
        # Scopes this resource server supports
        # The client should request these scopes from the authorization server
        "scopes_supported": [
            f"api://{CLIENT_ID}/access_as_user"
        ],
        
        # How the client should present the bearer token
        # "header" means Authorization: Bearer <token>
        "bearer_methods_supported": ["header"],
        
        # Optional: Token formats we accept (helps clients understand what to expect)
        "token_formats_supported": ["jwt"],
        
        # Optional: Documentation URL for developers
        "service_documentation": "https://azure-samples.github.io/sherpa/camps/camp1-identity/"
    })

# ============================================================================
# HEALTH CHECK ENDPOINT (Unauthenticated)
# ============================================================================

async def health_endpoint(request):
    """Health check endpoint - does not require authentication."""
    return JSONResponse({
        "status": "healthy",
        "server": "Camp 1 Secure Server",
        "features": ["JWT auth", "PRM", "Key Vault"],
        "prm_endpoint": "/.well-known/oauth-protected-resource"
    })

# Create the MCP app at /mcp path
app = mcp.http_app(path="/mcp", transport="streamable-http")

# Add CORS middleware for PRM discovery (must be first)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for PRM discovery
    allow_credentials=False,  # PRM endpoint is public metadata
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# Add PRM middleware so it wraps all 401 responses
app.add_middleware(PRMAuthenticateMiddleware)

# Add routes (insert at beginning so they take precedence)
app.routes.insert(0, Route("/.well-known/oauth-protected-resource", prm_endpoint))
app.routes.insert(0, Route("/health", health_endpoint))

if __name__ == "__main__":
    import uvicorn
    
    print("=" * 70)
    print("Camp 1 Secure Server with PRM (RFC 9728)")
    print("=" * 70)
    print()
    print("Endpoints:")
    print(f"  Health:     /health (unauthenticated)")
    print(f"  PRM:        /.well-known/oauth-protected-resource")
    print(f"  MCP:        /mcp (requires JWT)")
    print()
    print("Configuration:")
    print(f"  Tenant ID:  {TENANT_ID}")
    print(f"  Client ID:  {CLIENT_ID}")
    print(f"  Resource:   {RESOURCE_URL or '(will use request host)'}")
    print()
    print("OAuth Flow (for VS Code auto-auth):")
    print("  1. Client connects to /mcp without token")
    print("  2. Server returns 401 with WWW-Authenticate header")
    print("  3. Header includes: resource_metadata=\".../.well-known/oauth-protected-resource\"")
    print("  4. Client fetches PRM, discovers Entra ID as authorization server")
    print("  5. Client authenticates with Entra ID using its pre-registered client ID")
    print("  6. Client receives JWT with audience = this server's resource URL")
    print("  7. Client retries /mcp with Bearer token")
    print("  8. Server validates JWT and grants access")
    print()
    print("=" * 70)
    
    uvicorn.run(app, host="0.0.0.0", port=8000)
