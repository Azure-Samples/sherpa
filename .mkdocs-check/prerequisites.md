---
title: Prerequisites
description: Tools, accounts, and setup you'll need before starting any camp in the MCP Security Summit Workshop.
hide_page_header: true
---

<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">Before You Climb</div>
      <h1>Prerequisites</h1>
      <p>Tools, accounts, and setup you'll need before starting any camp in the workshop.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">checklist</span></span>
    </div>
  </div>
</div>

## Required Tools

### Azure Subscription

You'll need an Azure subscription with **Contributor** access. No subscription? [Create a free account](https://azure.microsoft.com/free/) with $200 in credits.

### Install & Verify

=== "macOS"

    ```bash
    # Git (if not already installed)
    brew install git

    # Azure CLI
    brew install azure-cli

    # Azure Developer CLI
    curl -fsSL https://aka.ms/install-azd.sh | bash

    # Python
    brew install python@3.11

    # uv (fast Python package manager)
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Docker — install Docker Desktop from https://docker.com/products/docker-desktop
    ```

=== "Windows"

    ```powershell
    # Git
    winget install Git.Git

    # Azure CLI
    winget install Microsoft.AzureCLI

    # Azure Developer CLI
    winget install microsoft.azd

    # Python — download from https://python.org (check "Add to PATH")
    # Or: winget install Python.Python.3.11

    # uv (fast Python package manager)
    powershell -c "irm https://astral.sh/uv/install.ps1 | iex"

    # Docker — install Docker Desktop from https://docker.com/products/docker-desktop
    ```

=== "Linux"

    ```bash
    # Git
    sudo apt install git

    # Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

    # Azure Developer CLI
    curl -fsSL https://aka.ms/install-azd.sh | bash

    # Python
    sudo apt update && sudo apt install python3.11 python3-pip

    # uv (fast Python package manager)
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Docker
    sudo apt install docker.io
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER  # log out and back in
    ```

**Authenticate and verify everything:**

=== "macOS / Linux"

    ```bash
    az login && az account show
    azd auth login && azd auth login --check-status
    python3 --version   # 3.10+
    uv --version
    docker ps            # Docker Desktop must be running
    git --version
    ```

=== "Windows (PowerShell)"

    ```powershell
    az login ; az account show
    azd auth login ; azd auth login --check-status
    python --version   # 3.10+
    uv --version
    docker ps           # Docker Desktop must be running
    git --version
    ```

| Tool | Docs |
|------|------|
| Azure CLI | [Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Azure Developer CLI | [Install guide](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) |
| Python | [Downloads](https://www.python.org/downloads/) |
| uv | [Documentation](https://docs.astral.sh/uv/) |
| Docker Desktop | [Documentation](https://docs.docker.com/desktop/) |

---

## Recommended: VS Code Extensions

Download [VS Code](https://code.visualstudio.com/), then install these extensions:

- **[GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)** — AI pair programming (used in Base Camp exploits)
- **[Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python)** — language support
- **[Azure Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack)** — resource management
- **[Bicep](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)** — Infrastructure as Code

---

## Optional: Azure Functions Core Tools

Only needed to **run and debug Azure Functions locally** during Camps 3–4. The workshop deploys functions to Azure, so this is not required to complete the labs.

=== "macOS"
    ```bash
    brew tap azure/functions && brew install azure-functions-core-tools@4
    ```

=== "Windows"
    ```powershell
    winget install Microsoft.Azure.FunctionsCoreTools
    ```

=== "Linux"
    ```bash
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
    sudo apt update && sudo apt install azure-functions-core-tools-4
    ```

Verify: `func --version` — [Install guide](https://learn.microsoft.com/azure/azure-functions/functions-run-local)

---

## What Each Camp Needs

| Tool | Base Camp | Camp 1 | Camp 2 | Camp 3 | Camp 4 |
|------|:---------:|:------:|:------:|:------:|:------:|
| Python 3.10+ & uv | +mdi:check+ | +mdi:check+ | +mdi:check+ | +mdi:check+ | +mdi:check+ |
| Azure subscription | | +mdi:check+ | +mdi:check+ | +mdi:check+ | +mdi:check+ |
| Azure CLI & azd | | +mdi:check+ | +mdi:check+ | +mdi:check+ | +mdi:check+ |
| Docker | | +mdi:check+ | +mdi:check+ | +mdi:check+ | +mdi:check+ |
| Functions Core Tools | | | | +mdi:check-outline+ | +mdi:check-outline+ |

- +mdi:check+ Required
- +mdi:check-outline+ Optional (local debugging only)

---

## Troubleshooting

??? question "Azure CLI: 'az' command not found"
    Restart your terminal, or run `source ~/.bashrc` / `source ~/.zshrc` (macOS/Linux). On Windows, restart PowerShell.

??? question "azd: Authentication failed"
    Log into both tools and verify:
    ```bash
    az login
    azd auth login
    az account show
    azd auth login --check-status
    ```

??? question "Python: wrong version or 'not found'"
    macOS often installs Python as `python3`. Try `python3 --version`. If multiple versions exist, use the full path or create an alias.

??? question "uv: Installation script fails"
    Download manually from [GitHub releases](https://github.com/astral-sh/uv/releases), or fall back to `pip install uv`.

??? question "Docker: 'Cannot connect to the Docker daemon'"
    Make sure Docker Desktop is **running** — look for the Docker icon in your system tray / menu bar. On Linux, run `sudo systemctl start docker`.

---

**Questions or issues?** [Open an issue](https://github.com/Azure-Samples/sherpa/issues) on GitHub.
