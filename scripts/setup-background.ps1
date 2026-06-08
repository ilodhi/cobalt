$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $env:LOCALAPPDATA "cobalt"
$StartupDir = [Environment]::GetFolderPath("Startup")
$TunnelName = "cobalt-downloader"

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

Write-Host "cobalt background setup" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host "Installing dependencies requires pnpm: npm install -g pnpm" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path (Join-Path $Root "node_modules"))) {
    Write-Host "Installing dependencies (first time only)..." -ForegroundColor Yellow
    Set-Location $Root
    pnpm install
}

$ApiEnv = Join-Path $Root "api" | Join-Path -ChildPath ".env"
$ApiEnvExample = Join-Path $Root "api" | Join-Path -ChildPath ".env.example"

if (-not (Test-Path $ApiEnv)) {
    Copy-Item $ApiEnvExample $ApiEnv
}

function Install-StartupShortcut($Name, $ScriptPath) {
    $vbsPath = Join-Path $StartupDir "$Name.vbs"
    $escaped = $ScriptPath.Replace("'", "''")
    @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File '$escaped'", 0, False
"@ | Set-Content -Path $vbsPath -Encoding ASCII
    Write-Host "  added startup item: $Name" -ForegroundColor Green
}

Write-Host "Registering auto-start on Windows login..." -ForegroundColor Cyan
Install-StartupShortcut "CobaltApi" (Join-Path $Root "scripts\run-api-background.ps1")
Install-StartupShortcut "CobaltTunnel" (Join-Path $Root "scripts\run-tunnel-background.ps1")

Write-Host ""
Write-Host "Tunnel setup (needed for GitHub Pages):" -ForegroundColor Cyan
Write-Host "  [1] Quick tunnel (no account, URL changes each reboot)" -ForegroundColor Yellow
Write-Host "  [2] Named tunnel (free Cloudflare account, stable URL)" -ForegroundColor Green
Write-Host "  [3] Skip tunnel (localhost only)" -ForegroundColor Gray
$choice = Read-Host "Choose 1, 2, or 3"

switch ($choice) {
    "1" {
        if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
            Write-Host "Install cloudflared: winget install Cloudflare.cloudflared" -ForegroundColor Red
            exit 1
        }
        "" | Set-Content (Join-Path $ConfigDir "quick-tunnel.flag")
        Remove-Item (Join-Path $ConfigDir "cloudflared.yml") -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host "Quick tunnel enabled. After reboot, check tunnel log for URL:" -ForegroundColor Yellow
        Write-Host "  $ConfigDir\tunnel.log" -ForegroundColor Gray
        Write-Host "Then paste it in GitHub Pages -> Settings -> Instances -> custom instance URL." -ForegroundColor Yellow
    }
    "2" {
        if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
            Write-Host "Install cloudflared: winget install Cloudflare.cloudflared" -ForegroundColor Red
            exit 1
        }
        Remove-Item (Join-Path $ConfigDir "quick-tunnel.flag") -ErrorAction SilentlyContinue

        $cloudflaredDir = Join-Path $env:USERPROFILE ".cloudflared"
        New-Item -ItemType Directory -Force -Path $cloudflaredDir | Out-Null

        if (-not (Test-Path (Join-Path $cloudflaredDir "cert.pem"))) {
            Write-Host "Log in to Cloudflare in the browser window..." -ForegroundColor Cyan
            cloudflared tunnel login
        }

        $tunnelList = cloudflared tunnel list 2>$null
        if ($tunnelList -notmatch $TunnelName) {
            cloudflared tunnel create $TunnelName
        }

        $tunnelId = (cloudflared tunnel list | Select-String $TunnelName).ToString().Split(" ")[0].Trim()
        $credentials = Join-Path $cloudflaredDir "$tunnelId.json"

        @"
tunnel: $tunnelId
credentials-file: $credentials

ingress:
  - service: http://127.0.0.1:9000
  - service: http_status:404
"@ | Set-Content -Path (Join-Path $ConfigDir "cloudflared.yml") -Encoding utf8

        Write-Host ""
        Write-Host "Add a public hostname for tunnel '$TunnelName' in Cloudflare Zero Trust:" -ForegroundColor Cyan
        Write-Host "  https://one.dash.cloudflare.com/ -> Networks -> Tunnels -> $TunnelName -> Public Hostname" -ForegroundColor Gray
        Write-Host "  Service URL: http://127.0.0.1:9000" -ForegroundColor Gray
        $publicUrl = Read-Host "Paste your public HTTPS URL (e.g. https://something.cfargotunnel.com)"

        if ($publicUrl -notmatch "^https?://") {
            $publicUrl = "https://$publicUrl"
        }
        if (-not $publicUrl.EndsWith("/")) {
            $publicUrl += "/"
        }

        $publicUrl | Set-Content -Path (Join-Path $ConfigDir "tunnel-url.txt") -Encoding utf8

        Set-Content -Path $ApiEnv -Value "API_URL=$publicUrl" -Encoding utf8

        $apiConfig = Join-Path $Root "web" | Join-Path -ChildPath "static" | Join-Path -ChildPath "api-config.json"
        $configJson = @{ defaultApi = $publicUrl } | ConvertTo-Json -Compress
        Set-Content -Path $apiConfig -Value $configJson -Encoding utf8

        Write-Host ""
        Write-Host "Saved API URL: $publicUrl" -ForegroundColor Green
        Write-Host "Commit web/static/api-config.json and push to update GitHub Pages." -ForegroundColor Yellow
    }
    default {
        Write-Host "Skipped tunnel. Use pnpm start:local for browser UI on this PC only." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Starting services now..." -ForegroundColor Cyan
& (Join-Path $Root "scripts\run-api-background.ps1")
Start-Sleep -Seconds 3
& (Join-Path $Root "scripts\run-tunnel-background.ps1")

Write-Host ""
Write-Host "Done. API and tunnel will auto-start whenever you log in to Windows." -ForegroundColor Green
Write-Host "GitHub Pages: https://ilodhi.github.io/cobalt/ (after you push)" -ForegroundColor Green
