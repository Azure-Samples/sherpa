# Base Camp Setup

This directory contains all Base Camp materials with a **single shared virtual environment** managed by `uv`.

## Quick Setup

```bash
cd camps/base-camp

# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# One command setup - creates venv, installs all dependencies
uv sync
```

That's it! `uv sync` automatically:
- ✅ Creates the virtual environment (`.venv/`)
- ✅ Installs all dependencies from `pyproject.toml`
- ✅ Installs the vulnerable server as an editable package
- ✅ Much faster than pip (10-100x)

## Alternative: Generate requirements.txt for pip

If you need pip compatibility:

```bash
uv pip compile pyproject.toml -o requirements.txt
pip install -r requirements.txt
pip install -e vulnerable-server/
```

## Structure

```
base-camp/
├── .venv/                    # Shared virtual environment (created by uv sync)
├── pyproject.toml            # All dependencies and project config
├── vulnerable-server/        # Insecure MCP server (HTTP/SSE)
│   ├── src/
│   │   ├── server.py        # Main server with vulnerabilities
│   │   └── data.py          # Sample user data
│   └── pyproject.toml       # Package metadata only
├── exploits/                 # Test scripts and tools
│   ├── test_vulnerable.py   # Python exploit demonstration
│   ├── launch-inspector-http.sh  # MCP Inspector launcher
│   └── README.md
└── README.md                 # Camp overview
```

## Benefits of uv

- ✅ **Single command** - `uv sync` does everything
- ✅ **10-100x faster** than pip
- ✅ **Better dependency resolution** - no conflicts
- ✅ **Lockfile support** - reproducible installs
- ✅ **No activation needed** - Use `uv run` directly
- ✅ **Drop-in pip replacement** - works with existing `requirements.txt`

## uv run vs Manual Activation

With `uv`, you don't need to activate the virtual environment:

**Old way (still works):**
```bash
source .venv/bin/activate  # Activate first
python -m src.server       # Then run
```

**New way (simpler):**
```bash
uv run --project .. python -m src.server  # No activation needed!
```

The `--project ..` flag tells uv to use the parent directory's pyproject.toml.

## Running Components

### Quick Commands from base-camp Folder

**Start server:**
```bash
cd vulnerable-server && uv run --project .. python -m src.server
```

**Run vulnerability test:**
```bash
cd exploits && uv run --project .. python test_vulnerable.py
```

**Launch MCP Inspector:**
```bash
cd exploits && ./launch-inspector-http.sh
```

### Detailed Instructions

### 1. Start the Vulnerable Server

```bash
cd camps/base-camp/vulnerable-server
uv run --project .. python -m src.server
```

The `--project ..` flag tells uv to use the parent directory's pyproject.toml (where all dependencies are defined).

Server runs on `http://localhost:8000/mcp` (HTTP/SSE transport)

### 2. Test the Vulnerability

**Option A: Python Script**
```bash
cd camps/base-camp/exploits
uv run --project .. python test_vulnerable.py
```

**Option B: MCP Inspector (Recommended)**
```bash
cd camps/base-camp/exploits
./launch-inspector-http.sh
```

**Option C: GitHub Copilot**

If configured in `.vscode/mcp.json`, ask Copilot:
```
#mcp_base-camp-vul_get_user_info user_002
```

## What You'll Learn

- **OWASP MCP07**: Insufficient Authentication & Authorization
- **OWASP MCP01**: Token Mismanagement & Secret Exposure
- How to exploit MCP servers over HTTP without authentication
- Using MCP Inspector for visual debugging
- Understanding resource URIs and tool calls

---

**Return to [Camp README](README.md)** | **[Workshop Overview](../../README.md)**
