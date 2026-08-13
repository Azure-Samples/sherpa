# Waypoint 1.4: Register remote MCP servers in API Center

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot "..")

function Get-AzdValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = (azd env get-value $Name 2>$null | Out-String).Trim()
    if (-not $value -or $value.StartsWith("ERROR:")) {
        throw "$Name is not set in the current azd environment."
    }
    return $value
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Waypoint 1.4: API Center MCP Registry"
Write-Host "=========================================="
Write-Host ""

$RG = Get-AzdValue "AZURE_RESOURCE_GROUP"
$APIM_URL = Get-AzdValue "APIM_GATEWAY_URL"
$APIM_NAME = Get-AzdValue "APIM_NAME"
$API_CENTER_NAME = Get-AzdValue "API_CENTER_NAME"

$CURRENT_USER_OBJECT_ID = (az ad signed-in-user show --query id -o tsv 2>$null | Out-String).Trim()
if (-not $CURRENT_USER_OBJECT_ID) {
    throw "Unable to resolve the signed-in user's Entra object ID. Run 'az login' with a user account before retrying."
}

$APIM_RESOURCE_ID = (az apim show `
    --resource-group $RG `
    --name $APIM_NAME `
    --query id -o tsv | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $APIM_RESOURCE_ID) {
    throw "Unable to resolve the API Management resource ID."
}

$API_CENTER_RESOURCE_ID = (az apic show `
    --resource-group $RG `
    --name $API_CENTER_NAME `
    --query id -o tsv | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $API_CENTER_RESOURCE_ID) {
    throw "Unable to resolve the API Center resource ID."
}

Write-Host "Registering remote MCP servers..."
Write-Host "  API Center: $API_CENTER_NAME"
Write-Host "  Lifecycle: Preview"
Write-Host "  Environment: Camp 2 APIM Gateway"
Write-Host ""

$deploymentOutputJson = az deployment group create `
    --name camp2-waypoint-1-4 `
    --resource-group $RG `
    --template-file infra/waypoints/1.4-apicenter.bicep `
    --parameters apiCenterName=$API_CENTER_NAME `
                 apimGatewayUrl=$APIM_URL `
                 apimResourceId=$APIM_RESOURCE_ID `
                 currentUserObjectId=$CURRENT_USER_OBJECT_ID `
    --query properties.outputs `
    --output json
if ($LASTEXITCODE -ne 0) {
    throw "API Center registration deployment failed."
}

$deploymentOutputs = $deploymentOutputJson | ConvertFrom-Json
$REGISTRY_ENDPOINT = $deploymentOutputs.mcpRegistryEndpoint.value

Write-Host "Validating API Center records..."
foreach ($API_NAME in @("sherpa-mcp", "trails-mcp")) {
    $API_KIND = (az rest `
        --method get `
        --uri "https://management.azure.com$API_CENTER_RESOURCE_ID/workspaces/default/apis/$API_NAME`?api-version=2024-06-01-preview" `
        --query properties.kind -o tsv | Out-String).Trim()
    $VERSION_STAGE = (az rest `
        --method get `
        --uri "https://management.azure.com$API_CENTER_RESOURCE_ID/workspaces/default/apis/$API_NAME/versions/v1-0-0`?api-version=2024-06-01-preview" `
        --query properties.lifecycleStage -o tsv | Out-String).Trim()
    $RUNTIME_URL = (az rest `
        --method get `
        --uri "https://management.azure.com$API_CENTER_RESOURCE_ID/workspaces/default/apis/$API_NAME/deployments/camp2-apim`?api-version=2024-06-01-preview" `
        --query "properties.server.runtimeUri[0]" -o tsv | Out-String).Trim()

    $EXPECTED_PATH = if ($API_NAME -eq "sherpa-mcp") { "sherpa/mcp" } else { "trails/mcp" }
    if ($API_KIND -ne "mcp" -or $VERSION_STAGE -ne "preview" -or $RUNTIME_URL -ne "$APIM_URL/$EXPECTED_PATH") {
        throw "API Center validation failed for $API_NAME."
    }
}

$ROLE_COUNT = [int](az role assignment list `
    --assignee $CURRENT_USER_OBJECT_ID `
    --scope $API_CENTER_RESOURCE_ID `
    --query "[?roleDefinitionName=='Azure API Center Data Reader'] | length(@)" `
    -o tsv)
if ($ROLE_COUNT -lt 1) {
    throw "Azure API Center Data Reader assignment was not found."
}

$nullDevice = if ($IsWindows) { "NUL" } else { "/dev/null" }
$REGISTRY_STATUS = curl.exe -sS -o $nullDevice -w "%{http_code}" $REGISTRY_ENDPOINT
if ($LASTEXITCODE -ne 0 -or $REGISTRY_STATUS -ne "401") {
    throw "Expected the protected MCP Registry endpoint to return HTTP 401 without a token; received $REGISTRY_STATUS."
}

Write-Host ""
Write-Host "=========================================="
Write-Host "API Center Registration Complete"
Write-Host "=========================================="
Write-Host ""
Write-Host "Registered remote MCP servers:"
Write-Host "  - Sherpa MCP Server ($APIM_URL/sherpa/mcp)"
Write-Host "  - Trails MCP Server ($APIM_URL/trails/mcp)"
Write-Host ""
Write-Host "Discovery profile:"
Write-Host "  - Version: 1.0.0 (Preview)"
Write-Host "  - Transport: Streamable HTTP"
Write-Host "  - Security: Workshop / non-production"
Write-Host "  - Sherpa auth: Microsoft Entra OAuth"
Write-Host "  - Trails auth: Microsoft Entra OAuth + APIM subscription key"
Write-Host "  - Credentials are not stored in API Center"
Write-Host ""
Write-Host "MCP Registry:"
Write-Host "  $REGISTRY_ENDPOINT"
Write-Host ""
Write-Host "Foundry Tools:"
Write-Host "  1. Open your Foundry project"
Write-Host "  2. Go to Build > Tools"
Write-Host "  3. Find the private catalog named: $API_CENTER_NAME"
Write-Host ""
Write-Host "Azure API Center Data Reader was assigned to the signed-in participant."
Write-Host "Role propagation can take up to 24 hours."
Write-Host ""
Write-Host "View in Azure Portal:"
Write-Host "  https://portal.azure.com/#resource$API_CENTER_RESOURCE_ID"
Write-Host ""
