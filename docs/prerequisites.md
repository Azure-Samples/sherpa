---
hide:
  - navigation
---

# Prerequisites

Before starting any camp in the MCP Security Summit workshop, ensure you have the required tools installed and configured. This page provides installation instructions and verification steps for all tools used throughout the workshop.

## Required Tools

### Azure Subscription

You'll need an Azure subscription with **Contributor** access to deploy resources.

!!! tip "Free Trial"
    If you don't have an Azure subscription, you can [create a free account](https://azure.microsoft.com/free/) with $200 in credits.

---

### Azure CLI

The Azure CLI is required for authenticating with Azure and managing resources.

=== "macOS"
    ```bash
    brew install azure-cli
    ```

=== "Windows"
    ```powershell
    winget install Microsoft.AzureCLI
    ```
    Or download the [MSI installer](https://learn.microsoft.com/cli/azure/install-azure-cli-windows)

=== "Linux"
    ```bash
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    ```

**Verify installation:**
```bash
az --version
# Expected: azure-cli 2.x.x or higher
```

**Authenticate:**
```bash
az login
```

📚 [Full installation guide](https://learn.microsoft.com/cli/azure/install-azure-cli)

---

### Azure Developer CLI (azd)

The Azure Developer CLI simplifies provisioning and deploying applications to Azure.

=== "macOS/Linux"
    ```bash
    curl -fsSL https://aka.ms/install-azd.sh | bash
    ```

=== "Windows"
    ```powershell
    winget install microsoft.azd
    ```
    Or use PowerShell:
    ```powershell
    powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"
    ```

**Verify installation:**
```bash
azd version
# Expected: azd version 1.x.x or higher
```

**Authenticate:**
```bash
azd auth login
```

📚 [Full installation guide](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)

---

### Python 3.10+

Python is required for running the MCP servers and exploitation scripts.

=== "macOS"
    ```bash
    brew install python@3.11
    ```
    
    !!! note "Python command on macOS"
        macOS may install Python as `python3` instead of `python`. This is normal and won't affect the workshop.

=== "Windows"
    Download from [python.org](https://www.python.org/downloads/)
    
    !!! warning "Add to PATH"
        During installation, check "Add Python to PATH"

=== "Linux"
    ```bash
    sudo apt update
    sudo apt install python3.11 python3-pip
    ```

**Verify installation:**
```bash
python --version
# Or on some systems: python3 --version
# Expected: Python 3.10.x or higher
```

📚 [Download Python](https://www.python.org/downloads/)

---

### uv - Fast Python Package Installer

We use `uv` for faster Python package management and virtual environment handling.

=== "macOS/Linux"
    ```bash
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ```

=== "Windows"
    ```powershell
    powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
    ```

**Verify installation:**
```bash
uv --version
# Expected: uv 0.x.x or higher
```

!!! info "Why uv?"
    `uv` is significantly faster than pip and handles virtual environments automatically. It's developed by the creators of Ruff and provides a modern Python packaging experience.

📚 [uv documentation](https://docs.astral.sh/uv/)

---

### Docker

Docker is required for Camp 1+ to build and deploy container images to Azure.

=== "macOS"
    Download and install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
    
    After installation, **launch Docker Desktop** from Applications to start the Docker daemon.

=== "Windows"
    Download and install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
    
    After installation, **launch Docker Desktop** to start the Docker daemon.

=== "Linux"
    ```bash
    # Ubuntu/Debian
    sudo apt update
    sudo apt install docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add your user to docker group to run without sudo
    sudo usermod -aG docker $USER
    # Log out and back in for group changes to take effect
    ```

**Verify installation:**
```bash
docker --version
docker ps
# Expected: Docker version info and running containers list
```

!!! note "Docker Desktop must be running"
    Before running `azd up` in Camp 1, ensure Docker Desktop is running. You should see the Docker icon in your system tray (macOS) or taskbar (Windows).

📚 [Docker Desktop documentation](https://docs.docker.com/desktop/)

---

### Azure Functions Core Tools

Azure Functions Core Tools is required for deploying and testing Azure Functions locally.

=== "macOS"
    ```bash
    brew tap azure/functions
    brew install azure-functions-core-tools@4
    ```

=== "Windows"
    ```powershell
    winget install Microsoft.Azure.FunctionsCoreTools
    ```
    Or download the [MSI installer](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools)

=== "Linux"
    ```bash
    # Ubuntu/Debian
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
    sudo apt update
    sudo apt install azure-functions-core-tools-4
    ```

**Verify installation:**
```bash
func --version
# Expected: 4.x.x or higher
```

📚 [Full installation guide](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools)

---

## Recommended Tools

### VS Code with Extensions

Visual Studio Code is recommended for the best workshop experience, especially for AI-powered exploitation scenarios.

**Install VS Code:**  
Download from [code.visualstudio.com](https://code.visualstudio.com/)

**Recommended Extensions:**

- **[GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)** - AI pair programming (used in Base Camp exploits)
- **[Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python)** - Python language support
- **[Azure Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack)** - Azure resource management
- **[Bicep](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)** - Infrastructure as Code editing

Install extensions:
```bash
code --install-extension github.copilot
code --install-extension ms-python.python
code --install-extension ms-vscode.vscode-node-azure-pack
code --install-extension ms-azuretools.vscode-bicep
```

---

### Git

Git is required for cloning the workshop repository.

=== "macOS"
    ```bash
    brew install git
    ```

=== "Windows"
    Download from [git-scm.com](https://git-scm.com/download/win)

=== "Linux"
    ```bash
    sudo apt install git
    ```

**Verify installation:**
```bash
git --version
```

---

## Clone the Workshop Repository

Once you have the prerequisites installed, clone the workshop repository:

```bash
git clone https://github.com/Azure-Samples/sherpa.git
cd sherpa
```

---

## Verification Checklist

Run these commands to verify your setup:

=== "macOS/Linux"
    ```bash
    # Azure CLI
    az --version
    az account show

    # Azure Developer CLI
    azd version
    azd auth login --check-status

    # Python (try python3 first, then python)
    python3 --version || python --version

    # uv
    uv --version

    # Git
    git --version
    ```

=== "Windows (PowerShell)"
    ```powershell
    # Azure CLI
    az --version
    az account show

    # Azure Developer CLI
    azd version
    azd auth login --check-status

    # Python
    python --version

    # uv
    uv --version

    # Git
    git --version
    ```

!!! success "All Set!"
    If all commands run successfully, you're ready to start the workshop!

---

## Camp-Specific Requirements

### Base Camp
:material-check: Python 3.10+  
:material-check: uv  
:material-check: VS Code (recommended for exploitation scenarios)  

### Camp 1: Identity & Access Management
:material-check: Azure subscription  
:material-check: Azure CLI (authenticated)  
:material-check: Azure Developer CLI (authenticated)  
:material-check: Python 3.10+  
:material-check: uv  
:material-check: Docker (running)  

### Camp 2: Gateway Security
:material-check: Azure subscription  
:material-check: Azure CLI (authenticated)  
:material-check: Azure Developer CLI (authenticated)  
:material-check: Python 3.10+  
:material-check: uv  
:material-check: Docker (running)  

### Camp 3: I/O Security
:material-check: Azure subscription  
:material-check: Azure CLI (authenticated)  
:material-check: Azure Developer CLI (authenticated)  
:material-check: Python 3.10+  
:material-check: uv  
:material-check: Docker (running)  
:material-check: Azure Functions Core Tools  

### Camp 4: Monitoring
:material-check: Azure subscription  
:material-check: Azure CLI (authenticated)  
:material-check: Azure Developer CLI (authenticated)  
:material-check: Python 3.10+  
:material-check: uv  
:material-check: Docker (running)  
:material-check: Azure Functions Core Tools

---

## Troubleshooting

??? question "Azure CLI: 'az' command not found"
    **Solution:** Ensure Azure CLI is in your PATH.
    
    - **macOS/Linux:** Restart your terminal or run `source ~/.bashrc` / `source ~/.zshrc`
    - **Windows:** Restart PowerShell or Command Prompt

??? question "azd: Authentication failed"
    **Solution:** Ensure you're logged into both Azure CLI and azd:
    ```bash
    az login
    azd auth login
    # Verify
    az account show
    azd auth login --check-status
    ```

??? question "Python: Module not found after installation"
    **Solution:** Verify you're using the correct Python installation:
    ```bash
    which python
    python --version
    # If multiple Python versions exist, use python3 explicitly
    python3 --version
    ```

??? question "uv: Installation script fails"
    **Solution:** Manual installation:
    
    - **macOS/Linux:** Download from [GitHub releases](https://github.com/astral-sh/uv/releases)
    - **Windows:** Use pip as fallback: `pip install uv`

??? question "VS Code: Extensions not installing"
    **Solution:** Install manually through VS Code:
    
    1. Open VS Code
    2. Press `Ctrl+Shift+X` (Windows/Linux) or `Cmd+Shift+X` (macOS)
    3. Search for extension name
    4. Click "Install"

---

## Platform-Specific Notes

### macOS
- Homebrew is recommended for package management
- If Homebrew prompts for Xcode Command Line Tools during installation, run: `xcode-select --install`

### Windows
- PowerShell 7+ is recommended over Windows PowerShell 5.1
- Windows Subsystem for Linux (WSL) is supported for all tools
- Some scripts use bash - consider Git Bash or WSL

### Linux
- Ubuntu 20.04+ and similar distributions are tested
- Ensure `curl`, `wget`, and `sudo` are available
- SELinux may require configuration adjustments

---

## Next Steps

Once your prerequisites are installed and verified:

1. **New to MCP Security?** Start with [Base Camp](camps/base-camp.md)
2. **Ready for Azure?** Jump to [Camp 1: Identity & Access Management](camps/camp1-identity.md)
3. **Explore the Guide:** [OWASP MCP Azure Security Guide](https://microsoft.github.io/mcp-azure-security-guide/)

---

**Questions or issues?** [Open an issue](https://github.com/Azure-Samples/sherpa/issues) on GitHub.
