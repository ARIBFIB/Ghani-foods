#
# fix-edge-functions-cors-deploy.ps1
# ------------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes the CORS preflight error on data-export / data-delete:
#   "Response to preflight request doesn't pass access control check:
#    It does not have HTTP ok status."
#
# ROOT CAUSE: Supabase Edge Functions require a valid JWT by default.
# The browser's OPTIONS preflight request does NOT carry the Authorization
# header, so Supabase's gateway rejects the preflight with 401 BEFORE your
# function code (and its corsHeaders) ever runs. The browser then reports
# this as a CORS failure.
#
# FIX: add supabase/config.toml with verify_jwt = false for both functions,
# then redeploy them with --no-verify-jwt.
#
# This script will:
#   1. Check the Supabase CLI is installed (installs via npx if missing is
#      NOT attempted automatically - script will just tell you what to run).
#   2. Create/update apps/backend/supabase/config.toml.
#   3. Log you in to Supabase CLI (opens a browser window) if not already.
#   4. Link the project (asks for your DB password interactively - this is
#      NOT stored anywhere by this script).
#   5. Deploy both functions with --no-verify-jwt.
#
# Safe to re-run.
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$projectRef = "hbvcdxhdkbksknasdqst"

Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
        Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
    }
}

# -----------------------------------------------------------------
# 0. Check Supabase CLI is available
# -----------------------------------------------------------------
$cliOk = $true
try {
    $null = & supabase --version 2>$null
} catch {
    $cliOk = $false
}

if (-not $cliOk) {
    Write-Host "ERROR: Supabase CLI not found on PATH." -ForegroundColor Red
    Write-Host "Install it first, e.g.:" -ForegroundColor Yellow
    Write-Host "  npm install -g supabase" -ForegroundColor Yellow
    Write-Host "or see: https://supabase.com/docs/guides/cli/getting-started" -ForegroundColor Yellow
    exit 1
}

# -----------------------------------------------------------------
# 1. backend folder (where supabase/functions lives)
# -----------------------------------------------------------------
$backendDir = Join-Path $root "apps\backend"
$supabaseDir = Join-Path $backendDir "supabase"
$configPath = Join-Path $supabaseDir "config.toml"

if (-not (Test-Path -LiteralPath $supabaseDir)) {
    Write-Host "ERROR: Could not find $supabaseDir" -ForegroundColor Red
    Write-Host "Make sure this script is run from the GhaniFoods project root." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------
# 2. Write/update config.toml with verify_jwt = false for both functions
# -----------------------------------------------------------------
if (Test-Path -LiteralPath $configPath) {
    Backup-File $configPath
    $existing = Get-Content -Raw -LiteralPath $configPath
} else {
    $existing = "project_id = `"$projectRef`"`r`n"
}

function Ensure-FunctionBlock($content, $fnName) {
    $marker = "[functions.$fnName]"
    if ($content -match [regex]::Escape($marker)) {
        # already has a block - make sure verify_jwt = false is present under it
        if ($content -notmatch [regex]::Escape("$marker`r`nverify_jwt = false")) {
            $content = $content -replace [regex]::Escape($marker), "$marker`r`nverify_jwt = false"
        }
        return $content
    } else {
        return $content.TrimEnd() + "`r`n`r`n$marker`r`nverify_jwt = false`r`n"
    }
}

$newConfig = Ensure-FunctionBlock $existing "data-export"
$newConfig = Ensure-FunctionBlock $newConfig "data-delete"

Set-Content -LiteralPath $configPath -Value $newConfig -NoNewline
Write-Host "config.toml -> verify_jwt = false set for data-export and data-delete." -ForegroundColor Green

# -----------------------------------------------------------------
# 3. Login (skips silently if already logged in)
# -----------------------------------------------------------------
Write-Host ""
Write-Host "Checking Supabase login status..." -ForegroundColor Cyan
try {
    & supabase projects list *> $null
    Write-Host "Already logged in." -ForegroundColor Green
} catch {
    Write-Host "Opening browser to log in to Supabase..." -ForegroundColor Yellow
    & supabase login
}

# -----------------------------------------------------------------
# 4. Link project (prompts for DB password interactively - not stored here)
# -----------------------------------------------------------------
Push-Location $backendDir
try {
    Write-Host ""
    Write-Host "Linking project ($projectRef)..." -ForegroundColor Cyan
    Write-Host "You will be asked for your database password (input hidden)." -ForegroundColor Yellow
    & supabase link --project-ref $projectRef

    # -----------------------------------------------------------------
    # 5. Deploy both functions without JWT verification
    # -----------------------------------------------------------------
    Write-Host ""
    Write-Host "Deploying data-export..." -ForegroundColor Cyan
    & supabase functions deploy data-export --no-verify-jwt

    Write-Host ""
    Write-Host "Deploying data-delete..." -ForegroundColor Cyan
    & supabase functions deploy data-delete --no-verify-jwt
}
finally {
    Pop-Location
}

# -----------------------------------------------------------------
# 6. Remind about required secrets (edge functions need these set on
#    Supabase, they are read via Deno.env.get inside the functions)
# -----------------------------------------------------------------
Write-Host ""
Write-Host "Done deploying." -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT - verify these secrets are set on the Supabase project" -ForegroundColor Yellow
Write-Host "(Dashboard > Project Settings > Edge Functions > Secrets, or via CLI):" -ForegroundColor Yellow
Write-Host "  supabase secrets set SUPABASE_URL=https://$projectRef.supabase.co" -ForegroundColor Yellow
Write-Host "  supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your service_role key>" -ForegroundColor Yellow
Write-Host ""
Write-Host "(SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are usually auto-injected" -ForegroundColor DarkGray
Write-Host "by Supabase for edge functions already, but worth checking if export" -ForegroundColor DarkGray
Write-Host "still fails after this deploy with a 500 instead of a CORS error.)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Now hard-refresh https://ghani-foods.vercel.app/settings?tab=export and try Export / Delete All Data again." -ForegroundColor Green