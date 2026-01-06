# Camp 1 - PRM Demo Client

This Python application demonstrates the complete PRM (Protected Resource Metadata) + OAuth 2.1 flow with your MCP server.

## What It Demonstrates

✅ **PRM Discovery** - Fetches `WWW-Authenticate` header and discovers PRM endpoint  
✅ **Authorization Server Discovery** - Reads OAuth metadata from Entra ID  
✅ **PKCE Authorization Code Flow** - Complete OAuth 2.1 flow with PKCE  
✅ **JWT Token Acquisition** - Exchanges authorization code for access token  
✅ **Authenticated MCP Requests** - Makes MCP calls with Bearer token  

This proves your server's PRM implementation is RFC 9728 compliant and demonstrates the complete OAuth flow end-to-end.

## Prerequisites

1. Deployed secure server from Camp 1
2. Entra ID app registration with redirect URI `http://localhost:8090/callback`
3. (Optional) Client secret for complete end-to-end flow

## Setup

### Option A: PRM Discovery Only (No Client Secret)

Shows that PRM discovery works correctly:

```bash
cd camps/camp1-identity

# Get your server URL and client ID
eval "$(azd env get-values | sed 's/^/export /')"

# Run the demo (uv handles dependencies automatically)
cd demo-client
uv run --project .. python mcp_prm_client.py \
  "${SECURE_SERVER_URL}" \
  "${AZURE_CLIENT_ID}"
```

The demo will successfully complete Steps 1-2 (PRM discovery), but fail at token exchange because Entra ID requires client authentication.

### Option B: Complete End-to-End Flow (With Client Secret)

For a full demo including token acquisition and authenticated MCP requests:

```bash
cd camps/camp1-identity

# Generate client secret and save to .env
./scripts/generate-client-secret.sh

# Run the demo
cd demo-client
eval "$(azd env get-values | sed 's/^/export /')"
uv run --project .. python mcp_prm_client.py \
  "${SECURE_SERVER_URL}" \
  "${AZURE_CLIENT_ID}"
```

⚠️ **Security Note**: The client secret is for LOCAL TESTING ONLY. Never use client secrets in production public clients. For production, use Device Code Flow or other passwordless flows.

## What Happens

1. **PRM Discovery**: Client connects without auth → gets 401 with `WWW-Authenticate` header
2. **Server Metadata**: Fetches `/.well-known/oauth-protected-resource`
3. **Auth Server Metadata**: Discovers Entra ID endpoints
4. **OAuth Flow**: Opens browser, you authenticate, callback receives code
5. **Token Exchange**: Exchanges authorization code for JWT (with PKCE)
6. **MCP Requests**: Makes authenticated MCP calls

## Example Output

```
======================================================================
Camp 1: PRM-Enabled MCP Client Demo
======================================================================

Server URL: https://your-server.azurecontainerapps.io
Client ID: d1db4c8f-dd4f-44c4-9245-8c2e25f7f61c

======================================================================
Step 1: Discovering Protected Resource Metadata (PRM)
======================================================================
✓ Received WWW-Authenticate header
✓ Found PRM endpoint: https://your-server/.well-known/oauth-protected-resource
✓ Fetched PRM metadata:
  Resource: https://your-server.azurecontainerapps.io
  Authorization Server: https://login.microsoftonline.com/.../v2.0
  Scopes: api://d1db4c8f-dd4f-44c4-9245-8c2e25f7f61c/access_as_user

======================================================================
Step 2: Discovering Authorization Server Metadata
======================================================================
✓ Fetching: https://login.microsoftonline.com/.../.well-known/openid-configuration
✓ Authorization endpoint: https://login.microsoftonline.com/.../oauth2/v2.0/authorize
✓ Token endpoint: https://login.microsoftonline.com/.../oauth2/v2.0/token

======================================================================
Step 3: Performing OAuth Authorization Code + PKCE Flow
======================================================================
✓ Generated PKCE code_challenge
✓ State: abc123...
✓ Redirect URI: http://localhost:8080/callback

✓ Opening browser for authentication...
✓ Waiting for callback...
✓ Received authorization code
✓ State validated

✓ Exchanging authorization code for access token...
✓ Access token acquired
  Token type: Bearer
  Expires in: 3599 seconds

======================================================================
Step 4: Making Authenticated MCP Request: initialize
======================================================================
✓ Sending request to: https://your-server/mcp
  Method: initialize
✓ Request successful!

... (more MCP requests)

======================================================================
✓ Demo Complete!
======================================================================

What we demonstrated:
  ✓ PRM discovery from WWW-Authenticate header (RFC 9728)
  ✓ Authorization server metadata discovery
  ✓ PKCE authorization code flow
  ✓ Authenticated MCP requests with JWT

This proves your server's PRM implementation is correct!
```

## Why This Matters

This demo proves:

- ✅ Your server correctly implements RFC 9728 (PRM)
- ✅ The `WWW-Authenticate` header is properly formatted
- ✅ PRM metadata is correct and discoverable
- ✅ OAuth flow works with pre-registered apps
- ✅ JWT validation is working correctly

Once MCP clients (VS Code, MCP Inspector) add support for pre-registered OAuth clients with enterprise identity providers, they'll work exactly like this demo!
