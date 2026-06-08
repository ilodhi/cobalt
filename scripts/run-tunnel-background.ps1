$ErrorActionPreference = "SilentlyContinue"
$Root = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $env:LOCALAPPDATA "cobalt"
$ConfigFile = Join-Path $ConfigDir "cloudflared.yml"
$LogFile = Join-Path $ConfigDir "tunnel.log"
$UrlFile = Join-Path $ConfigDir "tunnel-url.txt"

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) cloudflared not installed"
    exit 1
}

if (-not (Test-Path $ConfigFile)) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) missing $ConfigFile — run pnpm setup:background first"
    exit 1
}

# quick tunnel mode (no cloudflare account): stable for this windows session only
$quickMode = Test-Path (Join-Path $ConfigDir "quick-tunnel.flag")

if ($quickMode) {
    $existing = Get-Process cloudflared -ErrorAction SilentlyContinue
    if ($existing) {
        exit 0
    }

    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) starting quick tunnel"

    Start-Process `
        -FilePath "cloudflared" `
        -ArgumentList "tunnel", "--url", "http://127.0.0.1:9000", "--logfile", $LogFile, "--loglevel", "info" `
        -WindowStyle Hidden `
        -WorkingDirectory $ConfigDir

    exit 0
}

$existing = Get-Process cloudflared -ErrorAction SilentlyContinue
if ($existing) {
    exit 0
}

Add-Content -Path $LogFile -Value "$(Get-Date -Format o) starting named tunnel"

Start-Process `
    -FilePath "cloudflared" `
    -ArgumentList "tunnel", "--config", $ConfigFile, "run" `
    -WindowStyle Hidden `
    -WorkingDirectory $ConfigDir

if (Test-Path $UrlFile) {
    $tunnelUrl = (Get-Content $UrlFile -Raw).Trim()
    if ($tunnelUrl) {
        $apiEnv = Join-Path $Root "api\.env"
        @"
API_URL=$tunnelUrl
"@ | Set-Content -Path $apiEnv -Encoding utf8

        $apiConfig = Join-Path $Root "web\static\api-config.json"
        @"
{
    "defaultApi": "$tunnelUrl"
}
"@ | Set-Content -Path $apiConfig -Encoding utf8
    }
}
