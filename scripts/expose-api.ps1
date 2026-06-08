$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    Write-Host "cloudflared is required to expose your local API over HTTPS." -ForegroundColor Yellow
    Write-Host "Install: winget install Cloudflare.cloudflared" -ForegroundColor Yellow
    Write-Host "Or download: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path "$Root\api\.env")) {
    Copy-Item "$Root\api\.env.example" "$Root\api\.env"
}

$apiListening = $false
try {
    Invoke-WebRequest -Uri "http://localhost:9000/" -UseBasicParsing -TimeoutSec 2 | Out-Null
    $apiListening = $true
} catch {}

if (-not $apiListening) {
    Write-Host "Starting local API on http://localhost:9000 ..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-Command",
        "Set-Location '$Root\api'; pnpm start"
    )
    Start-Sleep -Seconds 4
}

Write-Host ""
Write-Host "Starting HTTPS tunnel to your local API..." -ForegroundColor Cyan
Write-Host "Copy the https://....trycloudflare.com URL when it appears." -ForegroundColor Green
Write-Host ""
Write-Host "Then either:" -ForegroundColor Yellow
Write-Host "  1. Settings -> Instances -> enable custom instance -> paste the URL" -ForegroundColor Yellow
Write-Host "  2. Or set defaultApi in web/static/api-config.json and push to GitHub" -ForegroundColor Yellow
Write-Host ""
Write-Host "Keep this window open while using the GitHub Pages downloader." -ForegroundColor Green
Write-Host ""

cloudflared tunnel --url http://localhost:9000
