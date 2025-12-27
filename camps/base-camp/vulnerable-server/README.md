# Base Camp - Vulnerable MCP Server

**⚠️ WARNING: This server is intentionally insecure for educational purposes!**

This MCP server demonstrates **OWASP MCP07 (Insufficient Authentication & Authorization)** and **MCP01 (Token Mismanagement & Secret Exposure)** by having:

- ❌ **No authentication** - Anyone can connect
- ❌ **No authorization** - Anyone can access any user's data  
- ❌ **No audit logging** - No record of access attempts
- ❌ **Exposed sensitive data** - SSN, account balances accessible to all

## Quick Start

### 1. Install Dependencies

**Use the camp-level setup (recommended):**

```bash
cd camps/base-camp

# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# One command setup
uv sync
```

See [SETUP.md](../SETUP.md) for full details.

### 2. Run the Server

```bash
cd vulnerable-server
uv run --project .. python -m src.server
```

You should see:
```
══════════════════════════════════════════════════════════════════════
🏔️  Base Camp - Vulnerable MCP Server
══════════════════════════════════════════════════════════════════════
Server Name: base-camp-vulnerable
Available Resources: 3 user records

⚠️  WARNING: This server has NO AUTHENTICATION!
   Anyone can access ANY user's sensitive data.
   
🚨 OWASP MCP07: Insufficient Authentication & Authorization
🚨 OWASP MCP01: Token Mismanagement & Secret Exposure
══════════════════════════════════════════════════════════════════════
```

### 3. Connect via VS Code

Add this to your VS Code MCP settings (Cmd/Ctrl + Shift + P → "MCP: Edit Configuration"):

```json
{
  "mcpServers": {
    "base-camp-vulnerable": {
      "command": "python",
      "args": ["-m", "src.server"],
      "cwd": "/absolute/path/to/sherpa/camps/base-camp/vulnerable-server"
    }
  }
}
```

Replace `/absolute/path/to/` with your actual repository path.

## What's Available

### Resources

The server exposes 3 user data resources:

- `resource://user-data/user_001` - Alice Johnson's data
- `resource://user-data/user_002` - Bob Smith's data  
- `resource://user-data/user_003` - Carol White's data

**Try accessing them all - they're all unprotected!**

### Tools

**`get_user_info(user_id: string)`**

Retrieves detailed user information including:
- Name
- Email
- SSN (last 4 digits)
- Account balance
- Role
- Member since date

**Example:**
```json
{
  "user_id": "user_002"
}
```

## The Vulnerability

### What's Wrong?

```python
@server.read_resource()
async def read_resource(uri: str) -> str:
    # 🚨 VULNERABILITY: No authentication check!
    # Should verify: Who is making this request?
    
    user_id = uri.replace("resource://user-data/", "")
    
    # 🚨 VULNERABILITY: No authorization check!
    # Should verify: Is this user allowed to access this data?
    
    user_data = get_user_by_id(user_id)
    return json.dumps(user_data)  # Returns sensitive data!
```

### How to Exploit

1. **List all resources** - See every user in the system
2. **Read user_001** - Access your "own" data (expected)
3. **Read user_002** - Access Bob's data (UNAUTHORIZED!)
4. **Read user_003** - Access Carol's data (UNAUTHORIZED!)

**You just demonstrated a data breach!**

## Next Steps

Once you've exploited this vulnerability, head to the secure server:

```bash
cd ../secure-server
```

The secure version implements authentication to prevent unauthorized access.

---

**Return to [Base Camp Guide](../README.md)**
