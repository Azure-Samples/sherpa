$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $ScriptDir
try {
    uv run python foundry_tools.py cleanup @args
}
finally {
    Pop-Location
}
