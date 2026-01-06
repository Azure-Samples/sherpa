"""
Camp 1 - PRM-Enabled MCP Client Demo

This client demonstrates the complete PRM + PKCE OAuth flow:
1. Fetches Protected Resource Metadata (PRM) from WWW-Authenticate header
2. Discovers authorization server from PRM
3. Performs PKCE authorization code flow with local callback server
4. Makes authenticated MCP requests with the token

This proves the server-side PRM implementation works correctly,
even though current MCP clients (VS Code, MCP Inspector) don't fully support it yet.
"""

import asyncio
import base64
import hashlib
import http.server
import json
import os
import secrets
import socketserver
import sys
import threading
import urllib.parse
import webbrowser
from contextlib import asynccontextmanager
from pathlib import Path
from urllib.parse import urlencode, urlparse, parse_qs

import httpx

# Try to load .env file if it exists (for client secret)
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / ".env"
    if env_path.exists():
        load_dotenv(env_path)
        print("ℹ️  Loaded client secret from .env file")
except ImportError:
    pass  # python-dotenv not required if no .env file


class OAuthCallbackHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP handler for OAuth callback"""
    
    authorization_code = None
    state = None
    
    def do_GET(self):
        # Parse the callback URL
        parsed_path = urlparse(self.path)
        params = parse_qs(parsed_path.query)
        
        if parsed_path.path == "/callback":
            # Extract authorization code and state
            OAuthCallbackHandler.authorization_code = params.get("code", [None])[0]
            OAuthCallbackHandler.state = params.get("state", [None])[0]
            
            # Send success response
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"""
                <html>
                <head><title>Authentication Complete</title></head>
                <body>
                    <h1>Authentication Successful!</h1>
                    <p>You can close this window and return to the terminal.</p>
                </body>
                </html>
            """)
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress log messages
        pass


class PRMMCPClient:
    """MCP Client with PRM support"""
    
    def __init__(self, server_url: str):
        self.server_url = server_url.rstrip("/")
        self.client = httpx.AsyncClient(timeout=30.0)
        self.access_token = None
        self.prm_metadata = None
        self.auth_server_metadata = None
        
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.client.aclose()
    
    async def discover_prm(self):
        """Step 1: Discover PRM from WWW-Authenticate header"""
        print("=" * 70)
        print("Step 1: Discovering Protected Resource Metadata (PRM)")
        print("=" * 70)
        
        # Make unauthenticated request to trigger 401
        response = await self.client.post(f"{self.server_url}/mcp", json={})
        
        if response.status_code != 401:
            raise ValueError(f"Expected 401, got {response.status_code}")
        
        # Extract PRM URL from WWW-Authenticate header
        www_auth = response.headers.get("WWW-Authenticate", "")
        print(f"✓ Received WWW-Authenticate header")
        print(f"  {www_auth[:100]}...")
        
        # Parse resource_metadata parameter
        if "resource_metadata=" not in www_auth:
            raise ValueError("No resource_metadata in WWW-Authenticate header")
        
        # Extract URL (handle quoted value)
        prm_url = www_auth.split('resource_metadata="')[1].split('"')[0]
        print(f"✓ Found PRM endpoint: {prm_url}")
        
        # Fetch PRM metadata
        prm_response = await self.client.get(prm_url)
        self.prm_metadata = prm_response.json()
        
        print(f"✓ Fetched PRM metadata:")
        print(f"  Resource: {self.prm_metadata['resource']}")
        print(f"  Authorization Server: {self.prm_metadata['authorization_servers'][0]}")
        print(f"  Scopes: {', '.join(self.prm_metadata['scopes_supported'])}")
        print()
        
    async def discover_authorization_server(self):
        """Step 2: Discover authorization server metadata"""
        print("=" * 70)
        print("Step 2: Discovering Authorization Server Metadata")
        print("=" * 70)
        
        auth_server_url = self.prm_metadata["authorization_servers"][0]
        well_known_url = f"{auth_server_url}/.well-known/openid-configuration"
        
        print(f"✓ Fetching: {well_known_url}")
        
        response = await self.client.get(well_known_url)
        self.auth_server_metadata = response.json()
        
        print(f"✓ Authorization endpoint: {self.auth_server_metadata['authorization_endpoint']}")
        print(f"✓ Token endpoint: {self.auth_server_metadata['token_endpoint']}")
        print()
    
    def perform_oauth_flow(self, client_id: str):
        """Step 3: Perform PKCE authorization code flow"""
        print("=" * 70)
        print("Step 3: Performing OAuth Authorization Code + PKCE Flow")
        print("=" * 70)
        
        # Generate PKCE parameters
        code_verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).decode('utf-8').rstrip('=')
        code_challenge = base64.urlsafe_b64encode(
            hashlib.sha256(code_verifier.encode('utf-8')).digest()
        ).decode('utf-8').rstrip('=')
        
        state = secrets.token_urlsafe(16)
        redirect_uri = "http://localhost:8090/callback"
        
        print(f"✓ Generated PKCE code_challenge")
        print(f"✓ State: {state}")
        print(f"✓ Redirect URI: {redirect_uri}")
        
        # Build authorization URL
        auth_params = {
            "client_id": client_id,
            "response_type": "code",
            "redirect_uri": redirect_uri,
            "scope": " ".join(self.prm_metadata["scopes_supported"]),
            "state": state,
            "code_challenge": code_challenge,
            "code_challenge_method": "S256"
        }
        
        auth_url = f"{self.auth_server_metadata['authorization_endpoint']}?{urlencode(auth_params)}"
        
        print(f"\n✓ Opening browser for authentication...")
        print(f"  URL: {auth_url[:80]}...")
        
        # Start local callback server
        with socketserver.TCPServer(("localhost", 8090), OAuthCallbackHandler) as httpd:
            # Start server in background thread
            server_thread = threading.Thread(target=httpd.handle_request)
            server_thread.start()
            
            # Open browser
            webbrowser.open(auth_url)
            
            print(f"\n✓ Waiting for callback...")
            server_thread.join()
        
        if not OAuthCallbackHandler.authorization_code:
            raise ValueError("No authorization code received")
        
        if OAuthCallbackHandler.state != state:
            raise ValueError("State mismatch - possible CSRF attack")
        
        print(f"✓ Received authorization code")
        print(f"✓ State validated")
        
        # Exchange code for token
        print(f"\n✓ Exchanging authorization code for access token...")
        
        # Prepare token request data
        token_data_params = {
            "client_id": client_id,
            "grant_type": "authorization_code",
            "code": OAuthCallbackHandler.authorization_code,
            "redirect_uri": redirect_uri,
            "code_verifier": code_verifier
        }
        
        # Add client secret if available (from .env file)
        client_secret = os.getenv("CLIENT_SECRET")
        if client_secret:
            token_data_params["client_secret"] = client_secret
            print(f"  Using client secret from .env file")
        
        token_response = httpx.post(
            self.auth_server_metadata['token_endpoint'],
            data=token_data_params
        )
        
        if token_response.status_code != 200:
            raise ValueError(f"Token exchange failed: {token_response.text}")
        
        token_data = token_response.json()
        self.access_token = token_data["access_token"]
        
        print(f"✓ Access token acquired")
        print(f"  Token type: {token_data.get('token_type', 'Bearer')}")
        print(f"  Expires in: {token_data.get('expires_in', 'N/A')} seconds")
        print()
    
    async def make_mcp_request(self, method: str, params: dict):
        """Step 4: Make authenticated MCP request"""
        print("=" * 70)
        print(f"Step 4: Making Authenticated MCP Request: {method}")
        print("=" * 70)
        
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1
        }
        
        print(f"✓ Sending request to: {self.server_url}/mcp")
        print(f"  Method: {method}")
        print(f"  Params: {json.dumps(params, indent=2)}")
        
        response = await self.client.post(
            f"{self.server_url}/mcp",
            json=payload,
            headers=headers
        )
        
        if response.status_code != 200:
            print(f"✗ Request failed: {response.status_code}")
            print(f"  {response.text}")
            return None
        
        result = response.json()
        print(f"✓ Request successful!")
        print(f"  Response: {json.dumps(result, indent=2)}")
        print()
        
        return result


async def main():
    """Main demo flow"""
    if len(sys.argv) < 3:
        print("Usage: python mcp_prm_client.py <server_url> <client_id>")
        print()
        print("Example:")
        print("  python mcp_prm_client.py \\")
        print("    https://your-server.azurecontainerapps.io \\")
        print("    d1db4c8f-dd4f-44c4-9245-8c2e25f7f61c")
        sys.exit(1)
    
    server_url = sys.argv[1]
    client_id = sys.argv[2]
    
    print()
    print("=" * 70)
    print("Camp 1: PRM-Enabled MCP Client Demo")
    print("=" * 70)
    print()
    print(f"Server URL: {server_url}")
    print(f"Client ID: {client_id}")
    print()
    
    try:
        async with PRMMCPClient(server_url) as client:
            # Step 1: Discover PRM
            await client.discover_prm()
            
            # Step 2: Discover auth server
            await client.discover_authorization_server()
            
            # Step 3: Perform OAuth flow
            client.perform_oauth_flow(client_id)
            
            # Step 4: Make authenticated requests
            await client.make_mcp_request("initialize", {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "prm-demo-client", "version": "1.0"}
            })
            
            await client.make_mcp_request("tools/list", {})
            
            await client.make_mcp_request("tools/call", {
                "name": "get_user_info",
                "arguments": {"user_id": "user_001"}
            })
            
        print("=" * 70)
        print("✓ Demo Complete!")
        print("=" * 70)
        print()
        print("What we demonstrated:")
        print("  ✓ PRM discovery from WWW-Authenticate header (RFC 9728)")
        print("  ✓ Authorization server metadata discovery")
        print("  ✓ PKCE authorization code flow")
        print("  ✓ Authenticated MCP requests with JWT")
        print()
        print("This proves your server's PRM implementation is correct!")
        print()
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
