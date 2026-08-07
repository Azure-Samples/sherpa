# Select the host's configured Python package index for container builds.

$ErrorActionPreference = 'Stop'

$PIP_INDEX_URL = $env:PIP_INDEX_URL
$pipIndexSource = "configured environment"

if ([string]::IsNullOrWhiteSpace($PIP_INDEX_URL)) {
    $pythonCommand = $null
    $pythonArguments = @()

    if (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonCommand = "python"
    } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        $pythonCommand = "python3"
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $pythonCommand = "py"
        $pythonArguments = @("-3")
    }

    $detectedPipIndexUrl = $null
    if ($pythonCommand) {
        $inheritedPipIndexUrl = $env:PIP_INDEX_URL
        Remove-Item Env:PIP_INDEX_URL -ErrorAction SilentlyContinue
        try {
            $pipConfigOutput = & $pythonCommand @pythonArguments -m pip config list 2>$null
        } finally {
            $env:PIP_INDEX_URL = $inheritedPipIndexUrl
        }

        $indexConfig = $pipConfigOutput | Where-Object { $_ -match "^global\.index-url='(.*)'$" } | Select-Object -First 1
        if ($indexConfig) {
            $indexMatch = [regex]::Match([string]$indexConfig, "^global\.index-url='(.*)'$")
            $detectedPipIndexUrl = $indexMatch.Groups[1].Value
        }
    }

    if ($detectedPipIndexUrl) {
        $PIP_INDEX_URL = $detectedPipIndexUrl
        $pipIndexSource = "host pip configuration"
    } else {
        $PIP_INDEX_URL = "https://pypi.org/simple"
        $pipIndexSource = "public PyPI default"
    }
}

$pipIndexUri = $null
$isValidPipIndex = [Uri]::TryCreate($PIP_INDEX_URL, [UriKind]::Absolute, [ref]$pipIndexUri)
if (-not $isValidPipIndex -or $pipIndexUri.Scheme -notin @("http", "https") -or -not $pipIndexUri.Host) {
    throw "PIP_INDEX_URL must be an absolute HTTP or HTTPS URL with a hostname."
}
if ($pipIndexUri.UserInfo) {
    throw "PIP_INDEX_URL must not contain embedded credentials."
}

azd env set PIP_INDEX_URL "$PIP_INDEX_URL"
Write-Host "Python package index: $($pipIndexUri.Host) ($pipIndexSource)"