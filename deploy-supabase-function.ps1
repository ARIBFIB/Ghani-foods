<#
  deploy-supabase-function.ps1
  Reusable script: links this project to the Supabase project, pushes any
  pending database migrations, and deploys one or more edge functions via
  the Supabase CLI.

  USAGE:
    Deploy one function (default = raw-materials-create):
      .\deploy-supabase-function.ps1

    Deploy a specific function:
      .\deploy-supabase-function.ps1 -Functions "supplier-payments"

    Deploy multiple functions:
      .\deploy-supabase-function.ps1 -Functions "raw-materials-create","supplier-payments"

    Deploy ALL functions (every folder under supabase/functions, except
    ones starting with "_" like "_shared" or "_disabled-..."):
      .\deploy-supabase-function.ps1 -All

    Skip migrations (functions only):
      .\deploy-supabase-function.ps1 -SkipMigrations

    Provide the DB password so "db push" doesn't stop and wait for input:
      .\deploy-supabase-function.ps1 -DbPassword "S0ep2CxuMkk0FgEH"

  NOTES:
    - Run this from the PROJECT ROOT (folder that contains "apps\backend\supabase\").
    - Requires Docker Desktop running (Supabase CLI uses it to build functions).
    - First run will open a browser for "supabase login" (one-time, interactive).
    - Migrations are pushed with "supabase db push" BEFORE functions are deployed,
      so any schema changes are live before the new function code runs against them.
    - "supabase db push" may prompt for the database password if -DbPassword is
      not supplied and no SUPABASE_DB_PASSWORD env var is set - watch the console.
    - Output + logs saved to deploy-output.txt
#>

param(
    [string[]]$Functions = @("raw-materials-create"),
    [switch]$SkipMigrations,
    [string]$DbPassword = "",
    [switch]$All
)

# NOTE: deliberately NOT "Stop" - the Supabase CLI writes normal progress
# lines (e.g. "Connecting to remote database...") to stderr. With
# $ErrorActionPreference = "Stop", PowerShell turns those into terminating
# errors via 2>&1 and kills the whole script even on success. We check
# $LASTEXITCODE after each native call instead of relying on this.
$ErrorActionPreference = "Continue"
$ProjectRef = "hbvcdxhdkbksknasdqst"
$root = Get-Location
$log = @()

if ($DbPassword -ne "") {
    $env:SUPABASE_DB_PASSWORD = $DbPassword
}

function Log($msg) {
    Write-Host $msg
    $script:log += $msg
}

Log "== Supabase Deploy (Migrations + Functions) =="
Log "Project root: $root"
Log "Project ref : $ProjectRef"
Log "Functions   : $($Functions -join ', ')"
Log "Skip migrations: $SkipMigrations"

# ---------------------------------------------------------------------
# 1. Check Supabase CLI is installed
# ---------------------------------------------------------------------
$supabaseCli = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseCli) {
    Log "ERROR: Supabase CLI not found in PATH."
    Log "Install it first, e.g.:  npm install -g supabase"
    Log "or see: https://supabase.com/docs/guides/cli/getting-started"
    $log -join "`n" | Set-Content "deploy-output.txt" -Encoding UTF8
    exit 1
}
Log "OK: Supabase CLI found."

# ---------------------------------------------------------------------
# 2. No Docker needed for function deploy - we use --use-api (API-based bundling)
# ---------------------------------------------------------------------
Log "OK: Using --use-api mode for functions (no Docker required)."

# ---------------------------------------------------------------------
# 3. Ensure backend/supabase folder exists (where config.toml should live)
# ---------------------------------------------------------------------
$supabaseDir = Join-Path $root "apps\backend\supabase"
if (-not (Test-Path $supabaseDir)) {
    Log "ERROR: Could not find $supabaseDir"
    Log "Make sure you're running this from the project root."
    $log -join "`n" | Set-Content "deploy-output.txt" -Encoding UTF8
    exit 1
}
Push-Location $supabaseDir
Log "Working in: $supabaseDir"

# ---------------------------------------------------------------------
# 3b. If -All was passed, discover every function folder automatically
#     (skips folders starting with "_" such as "_shared" or disabled ones)
# ---------------------------------------------------------------------
if ($All) {
    $functionsRoot = Join-Path $supabaseDir "functions"
    $discovered = Get-ChildItem -Path $functionsRoot -Directory |
        Where-Object { $_.Name -notlike "_*" } |
        Select-Object -ExpandProperty Name
    if ($discovered.Count -eq 0) {
        Log "ERROR: -All was passed but no function folders were found under $functionsRoot"
        Pop-Location
        $log -join "`n" | Set-Content (Join-Path $root "deploy-output.txt") -Encoding UTF8
        exit 1
    }
    $Functions = $discovered
    Log "`n-All passed: discovered $($Functions.Count) function(s): $($Functions -join ', ')"
}

# ---------------------------------------------------------------------
# 4. supabase init (only if not already initialized)
# ---------------------------------------------------------------------
if (-not (Test-Path "config.toml")) {
    Log "`nRunning: supabase init"
    supabase init 2>&1 | ForEach-Object { Log $_ }
} else {
    Log "`nSKIP: supabase already initialized (config.toml exists)."
}

# ---------------------------------------------------------------------
# 5. supabase login (interactive, one-time - opens browser)
# ---------------------------------------------------------------------
Log "`nChecking Supabase login status..."
$whoami = supabase projects list 2>&1
if ($LASTEXITCODE -ne 0 -or $whoami -match "not logged in|access token") {
    Log "Not logged in. Running: supabase login (browser will open)..."
    supabase login 2>&1 | ForEach-Object { Log $_ }
} else {
    Log "OK: Already logged in."
}

# ---------------------------------------------------------------------
# 6. supabase link
# ---------------------------------------------------------------------
Log "`nRunning: supabase link --project-ref $ProjectRef"
supabase link --project-ref $ProjectRef 2>&1 | ForEach-Object { Log $_ }
if ($LASTEXITCODE -ne 0) {
    Log "ERROR: supabase link failed. Aborting before touching the database."
    Pop-Location
    $log -join "`n" | Set-Content (Join-Path $root "deploy-output.txt") -Encoding UTF8
    exit 1
}

# ---------------------------------------------------------------------
# 7. Push database migrations (NEW)
# ---------------------------------------------------------------------
if (-not $SkipMigrations) {
    Log "`n---- Pushing database migrations ----"
    Log "Running: supabase db push"
    if ($DbPassword -eq "" -and -not $env:SUPABASE_DB_PASSWORD) {
        Log "NOTE: no -DbPassword given. If prompted for a database password in the console, type it and press Enter."
    }
    supabase db push --project-ref $ProjectRef 2>&1 | ForEach-Object { Log $_ }
    if ($LASTEXITCODE -eq 0) {
        Log "SUCCESS: migrations pushed (or already up to date)."
    } else {
        Log "FAILED: supabase db push exited with code $LASTEXITCODE."
        Log "Aborting function deploy since the schema may be out of sync. See log above."
        Pop-Location
        $log -join "`n" | Set-Content (Join-Path $root "deploy-output.txt") -Encoding UTF8
        exit 1
    }
} else {
    Log "`nSKIP: migrations (-SkipMigrations passed)."
}

# ---------------------------------------------------------------------
# 8. Deploy each function
# ---------------------------------------------------------------------
foreach ($fn in $Functions) {
    Log "`n---- Deploying: $fn ----"
    $fnPath = Join-Path $supabaseDir "functions\$fn"
    if (-not (Test-Path $fnPath)) {
        Log "WARNING: Function folder not found: $fnPath - skipping."
        continue
    }
    supabase functions deploy $fn --project-ref $ProjectRef 2>&1 | ForEach-Object { Log $_ }
    if ($LASTEXITCODE -eq 0) {
        Log "SUCCESS: $fn deployed."
    } else {
        Log "FAILED: $fn deploy exited with code $LASTEXITCODE. See log above."
    }
}

Pop-Location

Log "`n== Done =="
$log -join "`n" | Set-Content (Join-Path $root "deploy-output.txt") -Encoding UTF8
Write-Host "`nOutput saved to deploy-output.txt - share it back in chat if anything failed." -ForegroundColor Green