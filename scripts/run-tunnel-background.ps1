$ErrorActionPreference = "SilentlyContinue"
$Root = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $env:LOCALAPPDATA "cobalt"
$ConfigFile = Join-Path $ConfigDir "cloudflared.yml"
$LogFile = Join-Path $ConfigDir "tunnel.log"
$UrlFile = Join-Path $ConfigDir "tunnel-url.txt"
$QuickFlag = Join-Path $ConfigDir "quick-tunnel.flag"

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) cloudflared not installed"
    exit 0
}

$quickMode = Test-Path $QuickFlag
$namedMode = Test-Path $ConfigFile

if (-not $quickMode -and -not $namedMode) {
    exit 0
}

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
        $apiEnv = Join-Path $Root "api" | Join-Path -ChildPath ".env"
        Set-Content -Path $apiEnv -Value "API_URL=$tunnelUrl" -Encoding utf8

        $apiConfig = Join-Path $Root "web" | Join-Path -ChildPath "static" | Join-Path -ChildPath "api-config.json"
        $configJson = @{ defaultApi = $tunnelUrl } | ConvertTo-Json -Compress
        Set-Content -Path $apiConfig -Value $configJson -Encoding utf8
    }
}
