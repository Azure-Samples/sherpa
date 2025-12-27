# Infrastructure Templates

This directory contains shared Azure infrastructure templates (Bicep) used across multiple camps.

## Structure

```
infra/
├── shared/           # Common resources used by all camps
│   ├── main.bicep   # Shared infrastructure orchestrator
│   └── modules/     # Reusable Bicep modules
└── README.md
```

## Shared Resources

The following Azure resources are deployed once and shared across camps:

- **Resource Group:** Container for all workshop resources
- **Log Analytics Workspace:** Centralized logging and monitoring
- **Container Apps Environment:** Hosting environment for MCP servers
- **Virtual Network:** Network isolation and private endpoints
- **Application Insights:** Performance monitoring and diagnostics

## Usage

Each camp has its own Bicep template in `camps/<camp-name>/infra/` that references these shared modules.

### Deploy Shared Infrastructure

```bash
# From repository root
cd infra/shared
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters environmentName=mcpworkshop
```

### Camp-Specific Deployments

Each camp extends the shared infrastructure:

```bash
# Example: Deploy Base Camp
cd camps/base-camp/infra
az deployment group create \
  --resource-group rg-mcpworkshop \
  --template-file main.bicep
```

## Coming Soon

Infrastructure templates are under development and will be added as each camp is completed.

---

*Return to [Workshop Overview](../README.md)*
