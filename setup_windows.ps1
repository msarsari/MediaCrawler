$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    $uvLocalBin = Join-Path $HOME ".local\bin"
    if (Test-Path $uvLocalBin) {
        $env:Path = "$uvLocalBin;$env:Path"
    }
}

Write-Host "MediaCrawler - Windows setup" -ForegroundColor Green
Write-Host "Repository: $PSScriptRoot"

Write-Step "Checking uv"
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv was not found. Installing it..."
    try {
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    }
    catch {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id astral-sh.uv -e --accept-source-agreements --accept-package-agreements
        }
        else {
            throw "Unable to install uv automatically. Install uv, then run this script again."
        }
    }
    Refresh-Path
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv was installed but is not available in PATH. Close PowerShell, reopen it, and run this script again."
}
uv --version

Write-Step "Installing Python 3.11 with uv"
uv python install 3.11

Write-Step "Installing Python project dependencies"
uv sync

Write-Step "Installing Playwright Chromium"
uv run playwright install chromium

Write-Step "Checking Node.js and npm"
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Node.js was not found. Installing Node.js LTS with winget..."
        winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
        Refresh-Path
    }
    else {
        throw "Node.js is required for the WebUI. Install Node.js LTS, then run this script again."
    }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js was installed but is not available in PATH. Close PowerShell, reopen it, and run this script again."
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm was not found. Reinstall Node.js LTS and run this script again."
}

node --version
npm --version

Write-Step "Installing WebUI dependencies"
$webuiPath = Join-Path $PSScriptRoot "webui"
if (-not (Test-Path $webuiPath)) {
    throw "webui directory was not found: $webuiPath"
}
Push-Location $webuiPath
try {
    npm install
}
finally {
    Pop-Location
}

Write-Step "Verifying backend import"
uv run python -c "import fastapi, uvicorn, playwright; print('Python backend dependencies: OK')"

Write-Host "`nSetup completed successfully." -ForegroundColor Green
Write-Host "To start MediaCrawler WebUI, run:" -ForegroundColor Yellow
Write-Host "  .\start_webui.ps1" -ForegroundColor White
Write-Host "`nThe development WebUI will use:" -ForegroundColor Yellow
Write-Host "  Backend: http://localhost:8080"
Write-Host "  Frontend: http://localhost:5173"
