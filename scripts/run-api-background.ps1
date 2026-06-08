$ErrorActionPreference = "SilentlyContinue"
$Root = Split-Path -Parent $PSScriptRoot
$ApiDir = Join-Path $Root "api"
$LogDir = Join-Path $env:LOCALAPPDATA "cobalt"
$LogFile = Join-Path $LogDir "api.log"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:9000/" -UseBasicParsing -TimeoutSec 2
    if ($response.StatusCode -eq 200) {
        exit 0
    }
} catch {}

if (-not (Test-Path (Join-Path $ApiDir ".env"))) {
    Copy-Item (Join-Path $ApiDir ".env.example") (Join-Path $ApiDir ".env")
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) node.js not found"
    exit 1
}

$wrapper = Join-Path $LogDir "start-api.cmd"
@"
@echo off
cd /d "$ApiDir"
"$($node.Source)" src\cobalt >> "$LogFile" 2>&1
"@ | Set-Content -Path $wrapper -Encoding ASCII

$process = Start-Process `
    -FilePath $wrapper `
    -WindowStyle Hidden `
    -PassThru

Add-Content -Path $LogFile -Value "$(Get-Date -Format o) started cobalt api (pid $($process.Id))"
