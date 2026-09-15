$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Test-Url([string]$Url) {
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
    }
    catch {
        return $false
    }
}

$backendUrl = "http://127.0.0.1:8080"
$backendHealthUrl = "$backendUrl/api/health"
$frontendUrl = "http://127.0.0.1:5173"

$backendCommand = @"
Set-Location '$PSScriptRoot'
Write-Host 'MediaCrawler Backend - keep this window open' -ForegroundColor Cyan
uv run uvicorn api.main:app --host 127.0.0.1 --port 8080 --reload
"@

$frontendCommand = @"
Set-Location '$PSScriptRoot\webui'
Write-Host 'MediaCrawler WebUI - keep this window open' -ForegroundColor Cyan
npm run dev -- --host 127.0.0.1
"@

Write-Host "MediaCrawler WebUI launcher" -ForegroundColor Green

# 1. Start backend only if it is not already healthy.
if (Test-Url $backendHealthUrl) {
    Write-Host "Backend is already running: $backendHealthUrl" -ForegroundColor Green
}
else {
    Write-Host "Starting backend on $backendUrl ..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-Command',$backendCommand

    Write-Host "Waiting for backend health check" -NoNewline
    $backendReady = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Url $backendHealthUrl) {
            $backendReady = $true
            break
        }
        Write-Host "." -NoNewline
    }
    Write-Host ""

    if (-not $backendReady) {
        Write-Host "Backend did not become available within 60 seconds." -ForegroundColor Red
        Write-Host "Check the Backend PowerShell window for the actual error." -ForegroundColor Yellow
        Write-Host "You can also run this command manually from the project root:" -ForegroundColor Yellow
        Write-Host "  uv run uvicorn api.main:app --host 127.0.0.1 --port 8080 --reload" -ForegroundColor White
        Write-Host "Then verify: $backendHealthUrl" -ForegroundColor White
        exit 1
    }

    Write-Host "Backend is ready." -ForegroundColor Green
}

# 2. Start the Vite frontend.
if (Test-Url $frontendUrl) {
    Write-Host "Frontend is already running: $frontendUrl" -ForegroundColor Green
}
else {
    Write-Host "Starting WebUI on $frontendUrl ..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-Command',$frontendCommand

    Write-Host "Waiting for frontend" -NoNewline
    $frontendReady = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Url $frontendUrl) {
            $frontendReady = $true
            break
        }
        Write-Host "." -NoNewline
    }
    Write-Host ""

    if (-not $frontendReady) {
        Write-Host "Frontend did not become available within 30 seconds." -ForegroundColor Red
        Write-Host "Check the WebUI PowerShell window for the actual npm/Vite error." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Frontend is ready." -ForegroundColor Green
}

Start-Process "$frontendUrl/"

Write-Host "`nMediaCrawler is ready." -ForegroundColor Green
Write-Host "Backend health: $backendHealthUrl"
Write-Host "Frontend:       $frontendUrl"
