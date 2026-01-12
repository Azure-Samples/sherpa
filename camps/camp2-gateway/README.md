# Camp 2: Gateway Security

> *"The Gateway Station"* - A checkpoint where all climbers must pass through proper channels before accessing mountain resources.

Establish enterprise-grade API gateway security for MCP servers using Azure API Management, implementing centralized access control, rate limiting, AI content safety, and OAuth 2.0 with Protected Resource Metadata (RFC 9728) discovery.

## Overview

- **Difficulty:** Advanced
- **Prerequisites:** Azure subscription, completed Camp 1 (recommended)
- **Tech Stack:** Python, MCP, Azure API Management, Container Apps, Azure AI Content Safety, API Center
- **Estimated Time:** 90 minutes

## Workshop Methodology

Camp 2 follows the **vulnerable → exploit → fix → validate** pattern:

1. **Deploy Vulnerable**: Start with an insecure configuration
2. **Exploit**: Demonstrate the real-world risk
3. **Fix**: Apply the security control
4. **Validate**: Confirm the fix works

## What You'll Learn

- Deploy Azure API Management as an MCP gateway
- Implement OAuth 2.0 with PRM (RFC 9728) for automatic discovery
- Configure rate limiting and throttling for MCP servers
- Add AI content safety filtering with Azure AI Content Safety
- Establish API governance with Azure API Center

## OWASP MCP Risks Addressed

| Waypoint | OWASP Risk | Vulnerability | Fix |
|----------|-----------|---------------|-----|
| 1.1 | MCP-05 | No user identity | OAuth + PRM |
| 1.2 | MCP-06 | Unlimited requests | Rate limiting |
| 1.3 | MCP-09 | No governance | API Center |
| 2 | MCP-03 | No content filtering | Content Safety |
| 3.1 | MCP-04 | Public backends | IP restrictions |

## Quick Start

```bash
# Clone and navigate
cd camps/camp2-gateway

# Deploy infrastructure (~15 minutes)
azd provision

# Follow the waypoint scripts
./scripts/1.1-deploy.sh     # Deploy Sherpa MCP Server
./scripts/1.1-exploit.sh    # See the vulnerability
./scripts/1.1-fix.sh        # Apply OAuth
./scripts/1.1-validate.sh   # Confirm it works

# Continue through all waypoints...
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure APIM Gateway                        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ OAuth Validation (Entra ID)                            │ │
│  │ Rate Limiting (by Subscription Key)                    │ │
│  │ AI Content Safety Filtering                            │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────┬──────────────────────┬──────────────────────┘
               │                      │
    ┌──────────▼─────────┐  ┌────────▼─────────────┐
    │  Sherpa MCP Server │  │     Trail API        │
    │  (Container App)   │  │  (Container App)     │
    │  - Weather         │  │  - Trails            │
    │  - Trails          │  │  - Conditions        │
    │  - Gear            │  │                      │
    └────────────────────┘  └──────────────────────┘
```

## Waypoint Summary

### Section 1: MCP Gateway and Governance

| Script | Description |
|--------|-------------|
| `1.1-deploy.sh` | Deploy Sherpa MCP Server |
| `1.1-exploit.sh` | Demonstrate no authentication |
| `1.1-fix.sh` | Apply OAuth + PRM |
| `1.1-validate.sh` | Confirm OAuth working |
| `1.2-deploy.sh` | Deploy Trail REST API |
| `1.2-exploit.sh` | Demonstrate subscription key limitations |
| `1.2-fix.sh` | Export as MCP Server with OAuth |
| `1.2-validate.sh` | Confirm hybrid auth working |
| `1.3-exploit.sh` | Demonstrate no rate limiting |
| `1.3-fix.sh` | Apply rate limiting |
| `1.3-validate.sh` | Confirm rate limiting |
| `1.4-fix.sh` | Register APIs in API Center |

### Section 2: Content Safety

This section adds AI-powered content filtering at the gateway. Additional safety layers (input validation, output sanitization) are covered in Camp 3.

| Script | Description |
|--------|-------------|
| `2.1-fix.sh` | Apply Azure AI Content Safety filtering |

### Section 3: Network Security

| Script | Description |
|--------|-------------|
| `3.1-exploit.sh` | Demonstrate direct backend access |
| `3.1-fix.sh` | Apply IP restrictions |
| `3.1-validate.sh` | Confirm restrictions work |

## Project Structure

```
camps/camp2-gateway/
├── azure.yaml                    # azd configuration
├── infra/
│   ├── main.bicep               # Base infrastructure
│   ├── modules/                 # Shared Bicep modules
│   ├── waypoints/               # Per-waypoint Bicep files
│   │   ├── 1.1-deploy-sherpa.bicep
│   │   ├── 1.1-oauth.bicep
│   │   ├── 1.2-deploy-trail.bicep
│   │   ├── 1.2-ratelimit.bicep
│   │   ├── 1.3-apicenter.bicep
│   │   ├── 2.1-contentsafety.bicep
│   │   └── 3.1-iprestrictions.bicep
│   └── policies/                # APIM policy XML files
├── servers/
│   ├── sherpa-mcp-server/       # MCP server (FastMCP)
│   └── trail-api/               # REST API (FastAPI)
├── scripts/
│   ├── hooks/                   # azd hooks
│   │   ├── preprovision.sh
│   │   └── postprovision.sh
│   └── *.sh                     # Waypoint scripts
└── README.md
```

## Resources Deployed

| Resource | Purpose |
|----------|---------|
| API Management (Basic v2) | MCP gateway with security policies |
| Container Apps Environment | Hosts MCP servers |
| Container Registry | Stores container images |
| Content Safety (S0) | Filters harmful content |
| API Center | API governance and discovery |
| Log Analytics | Monitoring and diagnostics |
| Managed Identity | Secure service-to-service auth |

## Documentation

- [Full Workshop Guide](https://azure-samples.github.io/sherpa/camps/camp2-gateway/)
- [Network Concepts](./docs/network-concepts.md)
- [Read/Write Patterns](./docs/read-write-patterns.md)

## Troubleshooting

### Common Issues

**azd provision fails with "quota exceeded"**
- Content Safety free tier is limited to one per subscription
- The workshop uses S0 (Standard) tier which has no limit

**Scripts fail with "command not found"**
- Ensure you're in the `camps/camp2-gateway` directory
- Scripts use relative paths

**OAuth validation returns 401**
- Check that preprovision hook completed successfully
- Verify `MCP_APP_CLIENT_ID` is set: `azd env get-value MCP_APP_CLIENT_ID`

**VS Code MCP can't authenticate**
- Ensure the Entra app has empty `identifierUris` (not `api://{appId}`)
- Verify both PRM discovery paths work (see Technical Deep Dive below)
- Check that VS Code client ID is pre-authorized on the Entra app

## Technical Deep Dive: OAuth + PRM

### RFC 9728 Protected Resource Metadata

VS Code discovers OAuth configuration using [RFC 9728](https://datatracker.ietf.org/doc/html/rfc9728):

1. **Path-based discovery** (tried first): `/.well-known/oauth-protected-resource/{path}`
2. **Suffix pattern** (fallback): `/{path}/.well-known/oauth-protected-resource`

Both endpoints must return identical PRM metadata:

```json
{
  "resource": "https://apim.azure-api.net/sherpa/mcp",
  "authorization_servers": ["https://login.microsoftonline.com/{tenant}/v2.0"],
  "scopes_supported": ["{appId}/user_impersonate"]
}
```

### Entra ID App Configuration

**Critical**: The Entra app's `identifierUris` must be **empty** for VS Code MCP OAuth:

| identifierUris | Scope Format | Works with VS Code? |
|---------------|--------------|---------------------|
| `[]` (empty) | `{appId}/scope` | ✅ Yes |
| `api://{appId}` | `api://{appId}/scope` | ❌ No |

### Key Learnings

1. **PRM must bypass OAuth**: The PRM operation policy uses `<return-response>` before `<base />` to skip token validation
2. **401 response matters**: Both the `WWW-Authenticate` header AND response body must include the correct `resource_metadata` URL with the API path
3. **Pre-authorization**: VS Code uses Microsoft's registered app ID (`aebc6443-996d-45c2-90f0-388ff96faa56`) - add it to `preAuthorizedApplications`
4. **No dynamic registration**: Entra ID doesn't support OAuth Dynamic Client Registration; use pre-authorized clients instead

## Cleanup

```bash
# Remove all Azure resources
azd down --force --purge

# Clean up Entra ID app (optional)
az ad app delete --id $(azd env get-value MCP_APP_CLIENT_ID)
```

## Next Steps

After completing Camp 2:
- **Camp 3:** Input/Output Security - Validate inputs, sanitize outputs, and add grounding protection
- **Camp 4:** Monitoring & Response - Detect and respond to security incidents
