# Sherpa Agent Foundry Tools Sample

This demo creates a prompt agent in the existing `camp2-project` and connects it to the Sherpa MCP Server registered in the Camp 2 API Center catalog.

The Foundry resource name is `sherpa-agent` because agent names cannot contain spaces. Its metadata and description identify it as **Sherpa Agent**.

## Prerequisites

- Complete Camp 2 through waypoint 1.4.
- Sign in with `az login` to the subscription tenant.
- Install `azd`, `uv`, and Python 3.11+.
- Have permission to manage the Foundry project and Sherpa APIM API policy.

## Run

=== "Bash"

    ```bash
    cd camps/camp2-gateway/samples/foundry-tools
    ./setup.sh
    ./test.sh
    ```

=== "PowerShell"

    ```powershell
    cd camps/camp2-gateway/samples/foundry-tools
    ./setup.ps1
    ./test.ps1
    ```

The agent authenticates to Sherpa with the Foundry project's managed identity. Review and approve each requested Sherpa MCP tool call in the terminal.

Setup is safe to rerun. It configures the catalog-backed connection for project managed identity, extends the live APIM policy to accept that identity, and recreates the prompt agent. Delegated Camp 2 OAuth access continues to work.

## Cleanup

Cleanup deletes `sherpa-agent` and restores both the API Center catalog connection and Sherpa APIM policy to their previous states.

=== "Bash"

    ```bash
    ./cleanup.sh
    ```

=== "PowerShell"

    ```powershell
    ./cleanup.ps1
    ```

## Catalog behavior

Foundry's private catalog is the discovery surface. The sample reads the Sherpa runtime URL from its API Center deployment and preserves the catalog metadata on the Foundry project connection. No client secret is created or stored.
