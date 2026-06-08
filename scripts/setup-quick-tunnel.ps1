$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $env:LOCALAPPDATA "cobalt"
$LogFile = Join-Path $ConfigDir "tunnel.log"
$QuickFlag = Join-Path $ConfigDir "quick-tunnel.flag"
$ApiEnv = Join-Path $Root "api" | Join-Path -ChildPath ".env"
$ApiConfig = Join-Path $Root "web" | Join-Path -ChildPath "static" | Join-Path -ChildPath "api-config.json"

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    Write-Host "cloudflared not found. Run: winget install Cloudflare.cloudflared" -ForegroundColor Red
    exit 1
}

"" | Set-Content $QuickFlag
Remove-Item (Join-Path $ConfigDir "cloudflared.yml") -ErrorAction SilentlyContinue
Remove-Item $LogFile -ErrorAction SilentlyContinue

Write-Host "Starting local API..." -ForegroundColor Cyan
& (Join-Path $Root "scripts\run-api-background.ps1")
Start-Sleep -Seconds 3

$apiOk = $false
for ($i = 0; $i -lt 10; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:9000/" -UseBasicParsing -TimeoutSec 2
        if ($r.StatusCode -eq 200) { $apiOk = $true; break }
    } catch { Start-Sleep -Seconds 1 }
}

if (-not $apiOk) {
    Write-Host "API did not start on port 9000." -ForegroundColor Red
    exit 1
}

Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "Starting quick tunnel (option 1)..." -ForegroundColor Cyan

Start-Process `
    -FilePath "cloudflared" `
    -ArgumentList "tunnel", "--url", "http://127.0.0.1:9000", "--logfile", $LogFile, "--loglevel", "info" `
    -WindowStyle Hidden `
    -WorkingDirectory $ConfigDir

$tunnelUrl = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $LogFile) {
        $log = Get-Content $LogFile -Raw -ErrorAction SilentlyContinue
        if ($log -match "(https://[a-z0-9-]+\.trycloudflare\.com)") {
            $tunnelUrl = $Matches[1]
            if (-not $tunnelUrl.EndsWith("/")) { $tunnelUrl += "/" }
            break
        }
    }
}

if (-not $tunnelUrl) {
    Write-Host "Tunnel started but URL not found yet. Check log:" -ForegroundColor Yellow
    Write-Host "  $LogFile" -ForegroundColor Gray
    exit 1
}

Set-Content -Path $ApiEnv -Value "API_URL=$tunnelUrl" -Encoding utf8
$configJson = @{ defaultApi = $tunnelUrl } | ConvertTo-Json -Compress
Set-Content -Path $ApiConfig -Value $configJson -Encoding utf8
$tunnelUrl | Set-Content -Path (Join-Path $ConfigDir "tunnel-url.txt") -Encoding utf8

Write-Host ""
Write-Host "Quick tunnel is ready!" -ForegroundColor Green
Write-Host "  Tunnel URL: $tunnelUrl" -ForegroundColor Cyan
Write-Host "  GitHub Pages: https://ilodhi.github.io/cobalt/" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: this URL changes after each reboot. Re-run: pnpm setup:quick-tunnel" -ForegroundColor Yellow
