# Workshop Scripts

Helper scripts for deploying, managing, and tearing down workshop environments.

## Available Scripts

### Deployment

- `deploy-all.sh` - Deploy all camps in sequence
- `deploy-base-camp.sh` - Deploy Base Camp only
- `deploy-camp1.sh` - Deploy Camp 1 (Identity)
- `deploy-camp2.sh` - Deploy Camp 2 (Gateway & Network)
- `deploy-camp3.sh` - Deploy Camp 3 (I/O Security)
- `deploy-camp4.sh` - Deploy Camp 4 (Monitoring)

### Management

- `validate-environment.sh` - Check prerequisites and Azure access
- `test-exploit.sh` - Run automated exploit tests
- `cleanup.sh` - Remove specific camp resources

### Utilities

- `generate-test-data.sh` - Create mock data for workshops
- `rotate-secrets.sh` - Update Key Vault secrets

## Prerequisites

Before running any scripts:

1. **Azure CLI installed and authenticated:**
   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```

2. **Required tools:**
   - Azure CLI (`az`)
   - Python 3.10+
   - jq (for JSON parsing)

3. **Environment variables:**
   ```bash
   export AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
   export AZURE_LOCATION="eastus"
   export WORKSHOP_PREFIX="mcpworkshop"
   ```

## Usage Examples

### Deploy Everything

```bash
# Validate prerequisites first
./scripts/validate-environment.sh

# Deploy all camps
./scripts/deploy-all.sh
```

### Deploy Individual Camp

```bash
# Deploy only Base Camp
./scripts/deploy-base-camp.sh

# Or use Azure Developer CLI
cd camps/base-camp
azd up
```

### Cleanup

```bash
# Remove all workshop resources
./scripts/cleanup.sh --all

# Remove specific camp
./scripts/cleanup.sh --camp base-camp
# Or: ./scripts/cleanup.sh --camp camp2-gateway
```

## Coming Soon

Scripts are under development and will be added as each camp is completed.

---

*Return to [Workshop Overview](../README.md)*
