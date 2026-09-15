$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Test-Url([string]$Url) {
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
    }
    catch {
        return $false
    }
}

Write-Host "MediaCrawler WebUI launcher (production mode)" -ForegroundColor Green
Write-Host "This mode does not use Vite on port 5173." -ForegroundColor DarkGray

# 1. Build the React/Vite WebUI into api/webui.
$webuiPath = Join-Path $PSScriptRoot "webui"
$builtIndex = Join-Path $PSScriptRoot "api\webui\index.html"

if (-not (Test-Path $webuiPath)) {
    throw "WebUI directory not found: $webuiPath"
}

Write-Host "Building WebUI..." -ForegroundColor Cyan
Push-Location $webuiPath
try {
    npm run build
    if ($LASTEXITCODE -ne 0) {
        throw "npm run build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path $builtIndex)) {
    throw "WebUI build completed but $builtIndex was not created."
}
Write-Host "WebUI build completed." -ForegroundColor Green

# 2. Serve frontend + API from the same FastAPI process.
# Use 8088 so an older development backend on 8080 cannot interfere.
$appUrl = "http://127.0.0.1:8088"
$healthUrl = "$appUrl/api/health"

$serverCommand = @"
Set-Location '$PSScriptRoot'
Write-Host 'MediaCrawler WebUI + API - keep this window open' -ForegroundColor Cyan
Write-Host 'URL: $appUrl' -ForegroundColor Green
uv run uvicorn api.main:app --host 127.0.0.1 --port 8088
"@

if (Test-Url $healthUrl) {
    Write-Host "MediaCrawler server is already running: $appUrl" -ForegroundColor Green
}
else {
    Write-Host "Starting MediaCrawler server on $appUrl ..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-Command',$serverCommand

    Write-Host "Waiting for server" -NoNewline
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Url $healthUrl) {
            $ready = $true
            break
        }
        Write-Host "." -NoNewline
    }
    Write-Host ""

    if (-not $ready) {
        Write-Host "Server did not become available within 60 seconds." -ForegroundColor Red
        Write-Host "Check the new PowerShell server window for the actual error." -ForegroundColor Yellow
        Write-Host "Manual command:" -ForegroundColor Yellow
        Write-Host "  uv run uvicorn api.main:app --host 127.0.0.1 --port 8088" -ForegroundColor White
        exit 1
    }
}

if (-not (Test-Url $appUrl)) {
    Write-Host "API is running but the WebUI root page is not available." -ForegroundColor Red
    Write-Host "Expected built file: $builtIndex" -ForegroundColor Yellow
    exit 1
}

Start-Process "$appUrl/"

Write-Host "`nMediaCrawler is ready." -ForegroundColor Green
Write-Host "WebUI + API: $appUrl"
Write-Host "Health check: $healthUrl"
Write-Host "Port 5173 is no longer used by this launcher." -ForegroundColor DarkGray
