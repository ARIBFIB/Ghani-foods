<#
  link-and-deploy-edge-functions.ps1
  Purpose: Link this repo to your Supabase project and deploy the 2 Edge
  Functions that returned 404 NOT DEPLOYED in the testing report:
    - receipts-delete
    - receipts-update

  SECURITY NOTE: this script deliberately does NOT contain your database
  password or service_role/secret keys. Those grant full access to your
  database and should never be hardcoded into a script or committed to
  git. 'supabase login' opens a browser for interactive auth, and
  'supabase link' will prompt you for the DB password only when needed
  (it is not stored in this file).
  If you pasted your DB password / service_role / secret key anywhere
  in chat or a shared file, rotate them from the Supabase dashboard:
    Settings -> Database -> Reset database password
    Settings -> API -> Reset service_role key

  Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\link-and-deploy-edge-functions.ps1
    .\link-and-deploy-edge-functions.ps1 -WhatIf
#>

param(
    [switch]$WhatIf,
    [string]$ProjectRef = "hbvcdxhdkbksknasdqst"
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
Write-Host "Project ref: $ProjectRef" -ForegroundColor Cyan

$backendPath = Join-Path $root "apps\backend"
if (-not (Test-Path -LiteralPath $backendPath)) {
    Write-Fail "apps\backend not found at $backendPath - are you in the repo root?"
    exit 1
}

# Use global CLI if present, else npx.
$supabaseCmd = "supabase"
if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
    Write-Skip "Global 'supabase' CLI not found on PATH - falling back to 'npx supabase'."
    $supabaseCmd = "npx supabase"
}

Push-Location $backendPath
try {
    # ---------------------------------------------------------------------
    # 1. Login (opens browser - interactive, no password stored here)
    # ---------------------------------------------------------------------
    Write-Step "[1/4] Supabase login..."
    if ($WhatIf) {
        Write-Ok "[WhatIf] Would run: $supabaseCmd login"
    }
    else {
        Invoke-Expression "$supabaseCmd login"
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Login failed or was cancelled."
            Pop-Location
            exit 1
        }
        Write-Ok "Logged in."
    }

    # ---------------------------------------------------------------------
    # 2. Init (safe to re-run - no-ops if already initialized)
    # ---------------------------------------------------------------------
    Write-Step "[2/4] Supabase init (skips if already initialized)..."
    if (Test-Path -LiteralPath (Join-Path $backendPath "supabase\config.toml")) {
        Write-Skip "Already initialized (supabase\config.toml exists)."
    }
    elseif ($WhatIf) {
        Write-Ok "[WhatIf] Would run: $supabaseCmd init"
    }
    else {
        Invoke-Expression "$supabaseCmd init"
        Write-Ok "Initialized."
    }

    # ---------------------------------------------------------------------
    # 3. Link project (will prompt for DB password interactively if needed)
    # ---------------------------------------------------------------------
    Write-Step "[3/4] Linking project ($ProjectRef)..."
    $linkedProjectFile = Join-Path $backendPath "supabase\.temp\linked-project.json"
    if (Test-Path -LiteralPath $linkedProjectFile) {
        Write-Skip "Already linked (supabase\.temp\linked-project.json exists)."
    }
    elseif ($WhatIf) {
        Write-Ok "[WhatIf] Would run: $supabaseCmd link --project-ref $ProjectRef"
    }
    else {
        Invoke-Expression "$supabaseCmd link --project-ref $ProjectRef"
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Link failed. If prompted for a DB password, enter it manually (it is not stored in this script)."
            Pop-Location
            exit 1
        }
        Write-Ok "Linked."
    }

    # ---------------------------------------------------------------------
    # 4. Deploy the missing functions
    # ---------------------------------------------------------------------
    $functionsToDeploy = @("receipts-delete", "receipts-update")
    foreach ($fn in $functionsToDeploy) {
        Write-Step "[4/4] Deploying function: $fn"
        $fnPath = Join-Path $backendPath "supabase\functions\$fn"

        if (-not (Test-Path -LiteralPath $fnPath)) {
            Write-Fail "Function folder not found: $fnPath - skipping."
            continue
        }

        if ($WhatIf) {
            Write-Ok "[WhatIf] Would run: $supabaseCmd functions deploy $fn"
            continue
        }

        Invoke-Expression "$supabaseCmd functions deploy $fn"
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Deploy failed for $fn (exit code $LASTEXITCODE). See output above."
        }
        else {
            Write-Ok "Deployed: $fn"
        }
    }
}
finally {
    Pop-Location
}

Write-Host ""
if ($WhatIf) {
    Write-Host "Preview complete. Re-run without -WhatIf to actually login/link/deploy." -ForegroundColor Cyan
}
else {
    Write-Host "Done. Verify in Supabase dashboard -> Edge Functions, or re-run your GhaniFoods testing script." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "REMINDER: rotate any secrets (DB password, service_role/secret key) that were" -ForegroundColor Red
    Write-Host "pasted into chat or shared files - Settings -> Database / Settings -> API in the dashboard." -ForegroundColor Red
}