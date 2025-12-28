# Base Camp: Understanding the Mountain

*"Know Your Terrain Before You Climb"*

**Duration:** 60 minutes  
**Primary OWASP Risks:** MCP07 (Insufficient Authentication & Authorization), MCP01 (Token Mismanagement & Secret Exposure)  
**Secondary Risks:** MCP02 (Privilege Escalation via Scope Creep)  
**Tech Stack:** Python, FastMCP, VS Code  
**Guide Reference:** [microsoft.github.io/mcp-azure-security-guide/mcp/mcp07-authz](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp07-authz/)

## Learning Objectives

- Understand what MCP is and why security matters
- Experience the risk of unauthenticated MCP servers
- Learn the workshop's "vulnerable → exploit → fix → validate" methodology
- Implement basic authentication for MCP servers
- Set up your workshop environment

## What is MCP?

The **Model Context Protocol (MCP)** is an open protocol that standardizes how AI applications connect to external tools and data sources. Think of it as USB for AI - a universal way to plug capabilities into any AI model.

**MCP Architecture:**
- **Host:** Application containing an LLM (e.g., Claude Desktop, VS Code)
- **Client:** Component within the host that manages MCP connections
- **Server:** Exposes tools, resources, and prompts to AI (this is what we secure!)
- **Transport:** Communication layer (Streamable HTTP for remote servers)

## Route Map

| Phase | Activity | Duration | Type |
|:-----:|----------|:--------:|:----:|
| **1** | Deploy Vulnerable Server | 10 min | Setup |
| **2** | Exploit the Vulnerability | 15 min | Hands-on |
| **3** | Understand the Risk | 10 min | Discussion |
| **4** | Implement Security | 15 min | Hands-on |
| **5** | Validate the Fix | 10 min | Verification |

---

## Phase 1: Deploy Vulnerable Server (10 min)

### Setup Python Environment

```bash
# Navigate to Base Camp
cd camps/base-camp

# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# One command setup (creates venv, installs all dependencies)
uv sync
```

**Architecture Note**: Each camp uses a single shared `.venv` for all components (vulnerable server, secure server, exploits). This simplifies setup for workshop participants. See [SETUP.md](SETUP.md) for details.

### Start the Vulnerable MCP Server

```bash
# Run the server
cd vulnerable-server
uv run --project .. python -m src.server
```

You should see:
```
MCP Server 'base-camp-vulnerable' running...
Available resources: 3 users
⚠️  WARNING: No authentication enabled!
```

### Configure VS Code MCP Client (Optional)

**If using VS Code:** The repository already has `.vscode/settings.json` configured! Just:

1. Open this repository in VS Code
2. Open the MCP panel (sidebar icon)
3. Connect to "base-camp-vulnerable"

**Alternative: Use the test script** (recommended for hands-on learning):

```bash
cd camps/base-camp/exploits
source ../.venv/bin/activate  # Use camp-level venv
python test_vulnerable.py
```

---

## Phase 2: Exploit the Vulnerability (15 min)

### Method 1: Automated Test Script (Recommended)

Run the provided exploit script to demonstrate all vulnerabilities:

```bash
cd camps/base-camp/exploits
uv run --project .. python test_vulnerable.py
```

This automated script uses **FastMCP Client** to perform 6 comprehensive exploit tests:

1. ✅ **Enumerate Tools** - Connect without authentication and list available tools
2. ✅ **Enumerate Resources** - List all user resources without authorization
3. 🚨 **EXPLOIT** - Access user_001 (Alice Johnson) data without authentication
4. 🚨 **EXPLOIT** - Access user_002 (Bob Smith) data without authorization
5. 🚨 **EXPLOIT** - Access user_003 (Carol Williams) data without authorization
6. 🚨 **EXPLOIT** - Read resources directly via user:// URIs

The script demonstrates:
- No authentication required to connect
- No authorization checks on tool calls
- Complete data breach of all user accounts
- Access to sensitive data (SSN, balance, email)
- **Key point:** Even accessing user_001 is a breach because there's no identity verification!

**Result:** All 6 exploits succeed, confirming OWASP MCP07 and MCP01 vulnerabilities!

### Method 2: Manual Testing via VS Code

If you prefer hands-on exploration:

### Test 1: List Available Resources

In VS Code, open the MCP panel and connect to "base-camp-vulnerable". You should see available resources:

```
resource://user-data/user_001
resource://user-data/user_002
resource://user-data/user_003
```

### Method 3: MCP Inspector (Visual Debugging) ✅

**Confirmed working!** For a web-based interface:

```bash
cd camps/base-camp/exploits
./launch-inspector-http.sh
```

This opens a browser with an interactive MCP testing interface. Perfect for:

- Visual exploration of resources
- Interactive tool calling
- Understanding MCP protocol messages
- No code required!

### Test 2: Access Your Own Data (Authorized)

**Manual test:** Read `resource://user-data/user_001`:

```json
{
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "ssn_last4": "1234",
  "account_balance": "$10,500.00"
}
```

**This is expected** - you're accessing your own data.

### Test 3: Access Someone Else's Data (UNAUTHORIZED!)

Now read `resource://user-data/user_002`:

```json
{
  "name": "Bob Smith",
  "email": "bob@example.com",
  "ssn_last4": "5678",
  "account_balance": "$25,750.00"
}
```

**🚨 SECURITY BREACH!** You just accessed Bob's sensitive data without any authorization check!

### Test 4: Use the Tool

Call the `get_user_info` tool with `user_id: "user_003"`:

```json
{
  "name": "Carol White",
  "email": "carol@example.com",
  "ssn_last4": "9012",
  "account_balance": "$8,200.00"
}
```

**Another breach!** You can query ANY user's information.

---

## Phase 3: Understand the Risk (10 min)

### What Just Happened?

You successfully exploited **OWASP MCP07 (Insufficient Authentication & Authorization)** and **MCP01 (Token Mismanagement & Secret Exposure)**.

**The Vulnerability:**
- The MCP server has NO authentication mechanism
- ANY client can connect and access ANY resource
- There's no check to verify the client's identity or permissions

**Real-World Impact:**
- **Data Breach:** Unauthorized access to sensitive user information
- **Compliance Violations:** GDPR, HIPAA, PCI-DSS violations
- **Reputation Damage:** Customer trust destroyed
- **Financial Loss:** Fines, legal fees, remediation costs

### Code Review: Where's the Vulnerability?

Open `vulnerable-server/src/server.py` and look at the `list_resources` function:

```python
@server.list_resources()
async def list_resources() -> list[Resource]:
    # VULNERABILITY: No authentication check!
    # This allows ANY client to access ANY user's data.
    # Maps to OWASP MCP07: Insufficient Authentication & Authorization
    # Maps to OWASP MCP01: Token Mismanagement & Secret Exposure
    return [
        Resource(
            uri=AnyUrl(f"resource://user-data/{user_id}"),
            name=f"User {user_id}",
            description=f"Personal data for user {user_id}",
            mimeType="application/json"
        )
        for user_id in MOCK_USER_DATA.keys()
    ]
```

**The problem:** There's no code checking WHO is making the request!

---

## Phase 4: Implement Security (15 min)

### Switch to Secure Server

```bash
# Stop the vulnerable server (Ctrl+C)
# Navigate to secure server
cd ../secure-server
```

### Configure Authentication Token

```bash
# Copy example environment file
cp .env.example .env

# The default token is: workshop_demo_token_12345
# You can customize it by editing .env if desired
```

### Start the Secure Server

```bash
# From camps/base-camp/secure-server directory
uv run --project .. python -m src.server
```

You should see:
```
🏔️  Base Camp - Secure MCP Server (Streamable HTTP)
======================================================================
Server Name: Base Camp Secure Server
Available Resources: 3 user records
Listening on: http://0.0.0.0:8001

✅ AUTHENTICATION ENABLED
   Required token: workshop_demo_token_12345
   All requests must include valid Bearer token

✅ AUTHORIZATION ENABLED
   Users can only access their own data (user_001)
======================================================================
```

### Test With MCP Inspector

1. Open MCP Inspector in a new terminal: `npx @modelcontextprotocol/inspector`
2. In the MCP Inspector web interface, change the server URL to `http://localhost:8001/mcp`
3. Click "Connect" - you should get an authentication error (401 Unauthorized)
4. Add the authentication header:
   - Click to add a custom header
   - **Header Name:** `Authorization`
   - **Header Value:** `Bearer workshop_demo_token_12345`
   - **Important:** Enable the toggle button to the left of the header!
5. Click "Connect" again - now it succeeds!

**Test the security:**
- ✅ Access `user://user_001` (your own data) - should work
- ❌ Access `user://user_002` or `user://user_003` - should get 403 Forbidden
- ✅ Call `get_user_info` with `user_id: user_001` - should work
- ❌ Call `get_user_info` with `user_id: user_002` - should fail

---

## Phase 5: Validate the Fix (10 min)

### Automated Testing

Run the secure server test script:

```bash
cd camps/base-camp/exploits
uv run --project .. python test_secure.py
```

The test script uses **FastMCP Client** (`fastmcp.client.Client`) with **BearerAuth** to programmatically test the secure server.

This will automatically test:
- ✅ Test 1: Connection WITH token succeeds (user_001 can access own data)
- ✅ Test 2: Connection WITHOUT token fails (401 Unauthorized)
- ✅ Test 3: Invalid token is rejected (401 Unauthorized)
- ✅ Test 4: Authorization prevents accessing other user's data (user_002, user_003)
- ✅ Test 5: Resource access requires authentication

Expected output when all tests pass:
```
Test 1: Authenticated access with valid token... ✅ PASSED
Test 2: Unauthenticated access rejected... ✅ PASSED
Test 3: Invalid token rejected... ✅ PASSED
Test 4: Authorization check (cannot access other users)... ✅ PASSED
Test 5: Resource access with authentication... ✅ PASSED

==================== Test Summary ====================
✅ All 5 tests passed!
```

### Manual Testing

If using MCP Inspector:

**Test 1: No Authentication**
- Remove the Authorization header
- Try to call `get_user_info` tool
- **Result:** ❌ 401 Unauthorized

**Test 2: With Authentication**
- Add Authorization header: `Bearer workshop_demo_token_12345`
- Try to access `user://user_001`
- **Result:** ✅ Success - you can access your own data

**Test 3: Authorization Check**
- With valid token, try to access `user://user_002`
- **Result:** ❌ 403 Forbidden - cannot access other user's data!

### Code Review: How Was It Fixed?

Open [`secure-server/src/server.py`](secure-server/src/server.py) and examine the key changes:

**1. FastMCP Built-in Authentication:**
```python
from fastmcp.auth import StaticTokenVerifier

# Define authentication using FastMCP's built-in verifier
auth = StaticTokenVerifier(
    tokens={
        REQUIRED_TOKEN: {
            "client_id": "user_001",
            "scopes": ["read", "write"]
        }
    }
)

# Create MCP server with authentication enabled
mcp = FastMCP("Base Camp Secure Server", auth=auth)
```

**2. Authorization Helper Function:**
```python
def check_authorization(requested_user_id: str, authenticated_user: str) -> bool:
    """Verify user can only access their own data"""
    return requested_user_id == authenticated_user
```

**3. Applied to Endpoints with Context:**
```python
@mcp.resource("user://{user_id}")
async def get_user_resource(ctx: Context, user_id: str) -> str:
    """Get user information by ID - requires authentication & authorization"""
    # Get authenticated user from context
    authenticated_user = get_authenticated_user(ctx)
    
    # ✅ Authorization check
    if not check_authorization(user_id, authenticated_user):
        raise PermissionError(
            f"Forbidden: Cannot access {user_id}'s data"
        )
    # ... return data
```

**4. Streamable HTTP Transport:**
```python
# Export HTTP app with streamable HTTP transport
app = mcp.http_app(path="/mcp", transport="streamable-http")
```

**Key Security Features:**
- ✅ **Token-based authentication** - FastMCP's StaticTokenVerifier validates Bearer tokens
- ✅ **Context injection** - Authenticated user info available in `Context` parameter
- ✅ **Authorization checks** - Every endpoint validates user can access requested data
- ✅ **Streamable HTTP** - Modern MCP transport protocol

### ⚠️ Important: This Is NOT Production-Ready!

While this fixes the Base Camp vulnerability, **do not use this approach in production**:

❌ **Simple bearer token** - No expiration, no rotation  
❌ **Token in environment variable** - Can leak in logs/errors  
❌ **Hardcoded user mapping** - Token directly maps to user_001 for demo purposes  
❌ **No token refresh** - Can't revoke access easily  
❌ **No audit logging** - Can't track access  
❌ **No rate limiting** - Vulnerable to brute force

**Why FastMCP's StaticTokenVerifier?**  
FastMCP provides built-in authentication for learning and prototyping. The StaticTokenVerifier is intentionally simple - it maps predefined tokens to user identities. This is perfect for understanding authentication concepts, but production systems need dynamic token validation (JWT), token rotation, and integration with identity providers.

### What Makes It Production-Ready? → Camp 1!

In **Camp 1: Identity & Access Management**, you'll implement:

✅ **OAuth 2.1 with PKCE** - Industry-standard authentication  
✅ **Azure Entra ID** - Enterprise identity provider  
✅ **Azure Managed Identity** - Passwordless authentication  
✅ **Azure Key Vault** - Secure secrets storage (no .env files!)  
✅ **JWT tokens** - With expiration, refresh, and validation  
✅ **RBAC** - Role-based access control for fine-grained permissions  
✅ **Audit logging** - Track every access for compliance

---

## Summary & Key Takeaways

✅ **Vulnerability Demonstrated:** Unauthenticated MCP servers expose all data  
✅ **OWASP Risk:** MCP07 - Insufficient Authentication & Authorization  
✅ **Fix Applied:** Token-based authentication on every request  
✅ **Pattern Learned:** The "vulnerable → exploit → fix → validate" methodology

### What's Next in Camp 1?

Base Camp used simple bearer tokens for demonstration. **Camp 1: Identity & Access Management** will upgrade to production-grade security:

- **OAuth 2.1** with PKCE (S256 method)
- **Azure Managed Identity** for passwordless authentication
- **Azure Key Vault** for secrets management
- **RBAC** for least-privilege access control

Then **Camp 2: Gateway & Network Security** will add centralized API/MCP Gateway protection with Azure API Management.

---

## Preview: Camp 1 - Establishing Your Identity Base Camp

- Azure Entra ID (OAuth 2.1) authentication
- Managed Identity for secure Azure resource access
- Key Vault instead of environment variables
- Addressing OWASP MCP07 (Insufficient Authentication & Authorization) and MCP01 (Token Mismanagement & Secret Exposure)

**Ready to continue the ascent? Head to `camps/camp1-identity/`**

---

*Base Camp complete! You've learned the fundamentals. Now let's climb higher.* 🏔️
