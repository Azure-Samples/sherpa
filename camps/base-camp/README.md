# Base Camp: Understanding the Mountain

*"Know Your Terrain Before You Climb"*

**Duration:** 60 minutes  
**Primary OWASP Risks:** MCP07 (Insufficient Authentication & Authorization), MCP01 (Token Mismanagement & Secret Exposure)  
**Secondary Risks:** MCP02 (Privilege Escalation via Scope Creep)  
**Tech Stack:** Python, MCP SDK, VS Code  
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

Run the provided exploit script to see all vulnerabilities:
 (Manual)

In VS Code MCP panel, after connecting to "base-camp-vulnerable", you should see
python test_vulnerable.py
```

This will automatically:
- Connect without authentication
- List all user resources
- Access authorized data (user_001)
- Access UNAUTHORIZED data (user_002, user_003)
- Display a security breach summary

Continue reading below to understand what each test does.

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
./launch-inspector.sh
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

# Use the camp-level venv (already created by uv sync)
# No additional setup needed!
```

### Configure Authentication Token

```bash
# Copy example environment file
cp .env.example .env

# Edit .env and set your token
# AUTH_TOKEN=workshop_demo_token_12345
```

### Start the Secure Server

```bash
cd secure-server
uv run --project .. python -m src.server
```

You should see:
```
MCP Server 'base-camp-secure' running...
✅ Authentication enabled
Required token: workshop_demo_token_12345
```

### Update VS Code Configuration

Edit your MCP settings to include the authentication token:

```json
{
  "mcpServers": {
    "base-camp-secure": {
      "command": "python",
      "args": ["-m", "src.server"],
      "cwd": "/path/to/sherpa/camps/base-camp/secure-server",
      "env": {
        "AUTH_TOKEN": "workshop_demo_token_12345"
      }
    }
  }
}
```

---

## Phase 5: Validate the Fix (10 min)

### Test 1: Connect Without Token

Remove the `env` section from your VS Code MCP configuration and try to connect.

**Expected Result:** Connection fails with `401 Unauthorized`

### Test 2: Connect With Valid Token

Restore the `env` section with the correct token and connect.

**Expected Result:** Connection succeeds!

### Test 3: Access Resources With Authentication

Try to access `resource://user-data/user_002` again.

**Expected Result:** 
- With proper authentication, the request is checked
- The server validates your identity
- Access control decisions are made based on who you are

### Code Review: How Was It Fixed?

Open `secure-server/src/server.py` and look at the authentication decorator:

```python
def require_auth(func):
    """
    SECURITY FIX: Validate authentication on every request
    This addresses OWASP MCP07 and MCP01 by ensuring only authorized
    clients can access resources.
    """
    async def wrapper(*args, **kwargs):
        token = get_token_from_context()
        if not validate_token(token):
            raise PermissionError("Unauthorized: Invalid or missing token")
        return await func(*args, **kwargs)
    return wrapper

@server.list_resources()
@require_auth  # ✅ Authentication required!
async def list_resources() -> list[Resource]:
    return [...]
```

**The fix:** Every request is now authenticated before processing!

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
