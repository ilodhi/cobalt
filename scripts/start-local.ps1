$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Set-Location $Root

if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host "pnpm is required. Install it with: npm install -g pnpm" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies (first run only)..." -ForegroundColor Yellow
    pnpm install
}

if (-not (Test-Path "api\.env")) {
    Copy-Item "api\.env.example" "api\.env"
}

if (-not (Test-Path "web\.env")) {
    Copy-Item "web\.env.example" "web\.env"
}

Write-Host "Starting local cobalt API on http://localhost:9000" -ForegroundColor Cyan
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$Root\api'; pnpm start"
)

Start-Sleep -Seconds 2

Write-Host "Starting browser UI on http://localhost:5173" -ForegroundColor Cyan
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$Root\web'; pnpm dev"
)

Start-Sleep -Seconds 4
Start-Process "http://localhost:5173"

Write-Host ""
Write-Host "cobalt is starting. Keep both terminal windows open while you use it." -ForegroundColor Green
Write-Host "Downloads go through your local API only — not api.cobalt.tools." -ForegroundColor Green
