$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$backendCommand = @"
Set-Location '$PSScriptRoot'
uv run uvicorn api.main:app --host 127.0.0.1 --port 8080 --reload
"@

$frontendCommand = @"
Set-Location '$PSScriptRoot\webui'
npm run dev
"@

Write-Host "Starting MediaCrawler backend on http://localhost:8080 ..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-Command',$backendCommand

Start-Sleep -Seconds 2

Write-Host "Starting MediaCrawler WebUI on http://localhost:5173 ..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-Command',$frontendCommand

Start-Sleep -Seconds 3
Start-Process 'http://localhost:5173/'

Write-Host "MediaCrawler WebUI launch commands were started." -ForegroundColor Green
Write-Host "Backend:  http://localhost:8080"
Write-Host "Frontend: http://localhost:5173"
