---
hide:
  - toc
---

<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">Community</div>
      <h1>Contributing</h1>
      <p>Thank you for your interest in improving this workshop! Here's how to get involved.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">group_add</span></span>
    </div>
  </div>
</div>

## Quick Links

:material-book-open-variant: [Workshop site](https://azure-samples.github.io/sherpa/) · :material-shield-lock: [OWASP MCP Azure Security Guide](https://microsoft.github.io/mcp-azure-security-guide/) · :material-github: [Open an issue](https://github.com/Azure-Samples/sherpa/issues)

---

## Repository Structure

```
sherpa/
├── camps/                       # Workshop modules
│   ├── base-camp/               # Local-only MCP fundamentals
│   ├── camp1-identity/          # OAuth, Managed Identity, Key Vault
│   ├── camp2-gateway/           # APIM, Content Safety, API Center
│   ├── camp3-io-security/       # Input validation, PII, prompt injection
│   └── camp4-monitoring/        # Logging, dashboards, alerts
├── docs/                        # MkDocs documentation site
│   └── camps/                   # Workshop guides (mirrors camps/ structure)
├── infra/                       # Shared infrastructure docs
└── mkdocs.yml                   # MkDocs configuration
```

Each Azure camp (1–4) follows this layout:

| Path | Purpose |
|------|---------|
| `azure.yaml` | azd project definition with lifecycle hooks |
| `infra/` | Bicep modules for Azure resources |
| `scripts/` | Waypoint scripts (`.sh` + `.ps1`) |
| `scripts/hooks/` | azd preprovision / postprovision hooks |
| `servers/` | MCP server source code (Python, FastMCP) |
| `tests/` | Test and example scripts |

---

## Workshop Pattern

Every camp follows the same **exploit → fix → validate** methodology:

1. Start with a vulnerable or incomplete configuration
2. Run an exploit to demonstrate the real-world risk
3. Apply the security fix
4. Validate the fix blocks the attack

---

## Scripts: Bash & PowerShell Parity

All scripts must have both a `.sh` (Bash) and `.ps1` (PowerShell) version. Camp 2 is the reference implementation with full parity.

**Bash conventions:**

- Use `set -euo pipefail` at the top
- Clear progress output with section headers
- Script naming: `{section}.{waypoint}-{action}.sh` (e.g., `1.1-deploy.sh`)

**PowerShell conventions:**

- Use `$ErrorActionPreference = 'Stop'` at the top
- Use `curl.exe` (not the PowerShell alias `curl`)
- Use `ConvertFrom-Json` / `ConvertTo-Json` instead of `jq`

**azure.yaml hooks** support both platforms:

```yaml
hooks:
  preprovision:
    posix:
      shell: sh
      run: ./scripts/hooks/preprovision.sh
    windows:
      shell: pwsh
      run: ./scripts/hooks/preprovision.ps1
```

---

## Documentation

The docs site is built with **MkDocs Material** (`mkdocs.yml` at repo root).

**Run locally:**

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

**Key conventions:**

- OS-specific commands use content tabs: `=== "Bash"` / `=== "PowerShell"`
- Cross-platform commands (e.g., `azd provision`) do **not** need tabs
- Tabs inside admonitions (`!!!`, `???`) need an extra 4-space indent

---

## Code Guidelines

| Language | Standard |
|----------|----------|
| **Python** | 3.11+, type hints, `uv` for package management |
| **Bash** | `set -euo pipefail`, clear section headers |
| **PowerShell** | `$ErrorActionPreference = 'Stop'`, no aliases |
| **Bicep** | Consistent naming with `abbreviations.json`, security comments |

---

## Submitting Changes

1. **Fork** the repo and create a feature branch
2. **Test** your changes — run through the workshop guide yourself, verify exploits demonstrate the vulnerability, and confirm fixes resolve the issue
3. **Check docs** render correctly with `mkdocs serve`
4. **Submit a PR** with a clear description of what changed and why

!!! tip "Before submitting"
    If you're adding or modifying scripts, make sure both `.sh` and `.ps1` versions exist and are tested.
