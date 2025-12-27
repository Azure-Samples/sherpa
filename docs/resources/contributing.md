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
```

## Documentation

### GitHub Pages

Documentation lives in the `docs/` directory:
- Keep docs separate from code README files
- Use clear headings and navigation
- Include code examples and screenshots
- Link to relevant Azure documentation

### README Files

README files in each camp serve as:
- Quick reference for workshop participants
- Navigation within GitHub repository
- Detailed step-by-step instructions

## Submitting Changes

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes** with clear commit messages
4. **Test thoroughly** - ensure all exploits and fixes work
5. **Submit a pull request** with description of changes

## Questions?

Open an issue on GitHub if you have questions or suggestions!

---

**Thank you for helping make this workshop better! 🏔️**
