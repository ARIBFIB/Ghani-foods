# =============================================================================
# GhaniFoods - Start frontend dev server (auto-locate apps\frontend)
# =============================================================================

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  $msg" -ForegroundColor Red }

Write-Step "Locating apps\frontend"

$cwd = Get-Location
$frontendDir = $null

if (Test-Path (Join-Path $cwd "package.json")) {
    $pkg = Get-Content (Join-Path $cwd "package.json") -Raw
    if ($pkg -match '"next"') { $frontendDir = $cwd.Path }
}
if (-not $frontendDir -and (Test-Path (Join-Path $cwd "apps\frontend\package.json"))) {
    $frontendDir = Join-Path $cwd "apps\frontend"
}
if (-not $frontendDir) {
    $candidate = Get-ChildItem -Path $cwd -Filter "package.json" -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "apps\\frontend\\package\.json$" } |
        Select-Object -First 1
    if ($candidate) { $frontendDir = Split-Path $candidate.FullName -Parent }
}

if (-not $frontendDir) {
    Write-Err "Could not find apps\frontend\package.json under $cwd"
    exit 1
}

Set-Location $frontendDir
Write-Ok "Using frontend dir: $frontendDir"

Write-Step "Checking node_modules"
if (-not (Test-Path "node_modules")) {
    Write-Warn "node_modules missing - running npm install..."
    npm install
} else {
    Write-Ok "node_modules present"
}

Write-Step "Checking .env.local (Supabase URL + anon key must be set for the frontend client)"
$envLocalPath = Join-Path $frontendDir ".env.local"
if (Test-Path $envLocalPath) {
    Write-Ok "Found .env.local"
    Get-Content $envLocalPath | ForEach-Object {
        if ($_ -match "^NEXT_PUBLIC_SUPABASE") {
            $keyOnly = ($_ -split "=")[0]
            Write-Host "    $keyOnly=<set>" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Warn ".env.local NOT found. The frontend needs:"
    Write-Warn "  NEXT_PUBLIC_SUPABASE_URL=https://hbvcdxhdkbksknasdqst.supabase.co"
    Write-Warn "  NEXT_PUBLIC_SUPABASE_ANON_KEY=<your anon/publishable key>"
    Write-Warn "Without these, supabase.from(...)/rpc(...) calls in the browser will fail."
}

Write-Step "Starting Next.js dev server"
Write-Host "  Once it starts, open http://localhost:3000 and log in, then click through:" -ForegroundColor White
Write-Host "  Suppliers -> Raw Materials -> Receipts -> Packaging -> Carton Config ->" -ForegroundColor White
Write-Host "  Batches -> Finished Cartons -> Customers -> Invoices -> Payments -> Settings" -ForegroundColor White
Write-Host ""

npm run dev