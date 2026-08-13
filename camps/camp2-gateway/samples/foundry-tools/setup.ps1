$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CampDir = Resolve-Path (Join-Path $ScriptDir '..\..')

$PipIndexUrl = (& azd -C $CampDir env get-value PIP_INDEX_URL 2>$null | Out-String).Trim()
if ($PipIndexUrl) {
    $env:UV_INDEX_URL = $PipIndexUrl
}

Push-Location $ScriptDir
try {
    uv sync --quiet
    uv run python foundry_tools.py setup
}
finally {
    Pop-Location
}
