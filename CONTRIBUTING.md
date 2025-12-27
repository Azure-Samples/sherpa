# Contributing to MCP Security Summit Workshop

Thank you for your interest in improving this workshop! This guide explains the repository structure and how to contribute effectively.

## Repository Structure

```
/
├── camps/                  # Workshop modules (Base Camp → Summit)
│   ├── base-camp/         # Fundamentals + basic authentication
│   ├── camp1-identity/    # OAuth, Managed Identity, Key Vault
│   ├── camp2-gateway/     # API/MCP Gateway, Network Security
│   ├── camp3-io-security/ # Content Safety, Input Validation
│   └── camp4-monitoring/  # Logging, Monitoring, Alerts
├── infra/                 # Shared Bicep templates
│   ├── shared/           # Common Azure resources
│   └── README.md
├── scripts/              # Deployment automation helpers
│   └── README.md
├── docs/                 # GitHub Pages documentation
│   └── index.md
└── README.md             # Workshop overview
```

## How to Add a New Camp

Each camp follows the **vulnerable → secure** pattern established in Base Camp. Use this template:

### Camp Directory Structure

```
camps/your-camp/
├── README.md              # Participant guide (5-phase format)
├── pyproject.toml         # Dependencies (managed by uv)
├── vulnerable-server/     # Insecure implementation
│   ├── src/
│   │   ├── server.py     # MCP server with vulnerabilities
│   │   └── ...
│   ├── pyproject.toml    # Package metadata
│   ├── Dockerfile
│   └── .env.example
├── secure-server/         # Fixed implementation
│   ├── src/
│   │   ├── server.py     # MCP server with security controls
│   │   └── ...
│   ├── pyproject.toml    # Package metadata
│   ├── Dockerfile
│   └── .env.example
├── exploits/              # Demonstration scripts
│   └── test_exploit.py
├── infra/                 # Camp-specific Bicep
│   └── main.bicep
└── vscode-config/         # Example MCP client configs
    └── mcp-settings.json
```

**Note:** Camps use `uv` for fast, reliable dependency management. Run `uv sync` in the camp root to set up the environment.

### Camp README.md Format

```markdown
# Camp [N]: [Theme Name]

*"[Mountain metaphor subtitle]"*

**Duration:** [X] minutes  
**OWASP Risks:** [MCP0X, MCP0Y]  
**Azure Services:** [Service A, Service B]  
**Guide Reference:** [Link to microsoft.github.io/mcp-azure-security-guide]

## Learning Objectives
- Objective 1
- Objective 2

## Route Map
| Phase | Activity | Duration | Type |
|:-----:|----------|:--------:|:----:|
| **1** | Deploy Vulnerable System | [X] min | Setup |
| **2** | Exploit Vulnerabilities | [X] min | Hands-on |
| **3** | Implement Security Fixes | [X] min | Hands-on |
| **4** | Validate Fixes | [X] min | Verification |
| **5** | Summary & Teaching Points | [X] min | Discussion |

[... detailed phase instructions ...]
```

## Code Style Guidelines

### Python MCP Servers

- Use the official `mcp` Python package (not FastMCP)
- Python 3.10+ with type hints
- Clear comments explaining vulnerabilities and fixes
- Follow PEP 8 style guidelines

**Example vulnerability comment:**
```python
# VULNERABILITY: No authentication check!
# This allows ANY client to access ANY user's data.
# Maps to OWASP MCP07: Insufficient Authentication
@server.list_resources()
async def list_resources() -> list[Resource]:
    # Should check authentication here but doesn't
    return [Resource(...)]
```

**Example security fix comment:**
```python
# SECURITY FIX: Validate authentication on every request
# This addresses OWASP MCP07 by ensuring only authorized
# clients can access resources.
def require_auth(func):
    async def wrapper(*args, **kwargs):
        token = get_token_from_context()
        if not validate_token(token):
            raise PermissionError("Unauthorized")
        return await func(*args, **kwargs)
    return wrapper
```

### Bicep Templates

- Use consistent naming conventions: `{resource-type}-{camp-name}`
- Include comments explaining security controls
- Output important values (endpoints, resource IDs)
- Follow Azure naming best practices

### Documentation

- Use clear, action-oriented headings
- Include code snippets with explanations
- Provide expected outputs for validation steps
- Link to relevant OWASP MCP Top 10 sections
- Use callout boxes for important notes

## Testing Your Contribution

Before submitting a pull request:

1. **Set up the environment:**
   ```bash
   cd camps/your-camp
   uv sync  # Install dependencies
   ```

2. **Test the vulnerable version:**
   - Deploy and run the vulnerable server
   - Verify the exploit works as documented
   - Ensure the vulnerability is clear to participants

3. **Test the secure version:**
   - Deploy and run the secure server
   - Verify the exploit now fails appropriately
   - Ensure security controls work as documented

4. **Validate documentation:**
   - Follow your own instructions step-by-step
   - Verify all commands work
   - Check all links are valid

## Submission Guidelines

1. Fork the repository
2. Create a feature branch: `git checkout -b camp-feature-name`
3. Make your changes following the guidelines above
4. Test thoroughly (see Testing section)
5. Commit with clear messages: `git commit -m "Add Camp X: [Feature]"`
6. Push to your fork: `git push origin camp-feature-name`
7. Open a Pull Request with:
   - Clear description of what was added/changed
   - Which OWASP MCP risks are addressed
   - Testing steps you performed

## Questions?

Open an issue or discussion in the repository. We're here to help!

---

*Thank you for helping others scale the summit safely! 🏔️*
