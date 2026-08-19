# =============================================================================
# GhaniFoods - Install Supabase CLI (if needed), link project, push migrations
# Can be run from EITHER the repo root OR apps\backend directly.
# =============================================================================

$ErrorActionPreference = "Stop"
$ProjectRef = "hbvcdxhdkbksknasdqst"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  $msg" -ForegroundColor Red }

# -----------------------------------------------------------------------
# 0. Auto-locate apps\backend (works whether run from repo root or already inside it)
# -----------------------------------------------------------------------
Write-Step "Locating apps\backend"

$cwd = Get-Location
$backendDir = $null

if (Test-Path (Join-Path $cwd "supabase\config.toml")) {
    $backendDir = $cwd.Path
} elseif (Test-Path (Join-Path $cwd "apps\backend\supabase\config.toml")) {
    $backendDir = Join-Path $cwd "apps\backend"
} else {
    # Search up to 2 levels for apps\backend\supabase\config.toml
    $candidate = Get-ChildItem -Path $cwd -Filter "config.toml" -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "apps\\backend\\supabase\\config\.toml$" } |
        Select-Object -First 1
    if ($candidate) {
        $backendDir = Split-Path (Split-Path $candidate.FullName -Parent) -Parent
    }
}

if (-not $backendDir) {
    Write-Err "Could not find apps\backend\supabase\config.toml anywhere under $cwd"
    Write-Err "Run this script from the GhaniFoods repo root or from apps\backend itself."
    exit 1
}

Set-Location $backendDir
Write-Ok "Using backend dir: $backendDir"

# -----------------------------------------------------------------------
# 1. Resolve a working Supabase CLI command ($supabaseCmd)
# -----------------------------------------------------------------------
Write-Step "Resolving Supabase CLI"

$supabaseCmd = $null

if (Get-Command supabase -ErrorAction SilentlyContinue) {
    $supabaseCmd = "supabase"
    Write-Ok "Found 'supabase' on PATH"
}

if (-not $supabaseCmd) {
    Write-Warn "'supabase' not on PATH, trying npx..."
    try {
        $null = npx --yes supabase --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $supabaseCmd = "npx --yes supabase"
            Write-Ok "Using 'npx supabase' (works without permanent install)"
        }
    } catch {}
}

if (-not $supabaseCmd) {
    Write-Warn "npx path failed too. Installing via Scoop..."

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warn "Scoop not found - installing Scoop first..."
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    }

    scoop bucket add supabase https://github.com/supabase/scoop-bucket.git 2>$null
    scoop install supabase

    if (Get-Command supabase -ErrorAction SilentlyContinue) {
        $supabaseCmd = "supabase"
        Write-Ok "Installed via Scoop"
    } else {
        Write-Err "Could not install Supabase CLI automatically."
        Write-Err "Install manually: https://supabase.com/docs/guides/cli/getting-started"
        exit 1
    }
}

function Invoke-Supabase {
    param([string]$ArgsLine)
    if ($supabaseCmd -like "npx*") {
        $full = "npx --yes supabase $ArgsLine"
    } else {
        $full = "supabase $ArgsLine"
    }
    Write-Host "  > $full" -ForegroundColor DarkGray
    Invoke-Expression $full
}

Write-Step "Supabase CLI version"
Invoke-Supabase "--version"

# -----------------------------------------------------------------------
# 2. Init (safe if already initialized - ignored if supabase/ already exists)
# -----------------------------------------------------------------------
Write-Step "Ensuring supabase project is initialized"
if (-not (Test-Path "supabase\config.toml")) {
    Invoke-Supabase "init"
} else {
    Write-Ok "Already initialized (config.toml present)"
}

# -----------------------------------------------------------------------
# 3. Login (only if not already authenticated)
# -----------------------------------------------------------------------
Write-Step "Checking Supabase auth"
$whoami = & cmd /c "$($supabaseCmd -replace 'npx --yes ','npx --yes ') projects list" 2>&1
$needsLogin = ($whoami -match "not logged in") -or ($whoami -match "access token") -or ($whoami -match "error")

if ($needsLogin) {
    Write-Warn "Not logged in (or token missing). Opening browser for 'supabase login'..."
    Invoke-Supabase "login"
} else {
    Write-Ok "Already authenticated"
}

# -----------------------------------------------------------------------
# 4. Link project (pre-filled ref, only if not already linked)
# -----------------------------------------------------------------------
Write-Step "Checking project link"
$linkedProjectFile = "supabase\.temp\project-ref"
if (Test-Path $linkedProjectFile) {
    $existingRef = (Get-Content $linkedProjectFile -Raw).Trim()
    if ($existingRef -eq $ProjectRef) {
        Write-Ok "Already linked to correct project ref: $existingRef"
    } else {
        Write-Warn "Linked to a different ref ($existingRef) - relinking to $ProjectRef..."
        Invoke-Supabase "link --project-ref $ProjectRef"
    }
} else {
    Write-Warn "No linked project found - linking to $ProjectRef..."
    Write-Warn "You may be prompted for the database password (from your Supabase Dashboard)."
    Invoke-Supabase "link --project-ref $ProjectRef"
}

# -----------------------------------------------------------------------
# 5. Show migration status (local vs remote)
# -----------------------------------------------------------------------
Write-Step "Migration status (local vs remote) - BEFORE push"
Invoke-Supabase "migration list"

# -----------------------------------------------------------------------
# 6. Push all pending migrations
# -----------------------------------------------------------------------
Write-Step "Pushing migrations to remote database"
Invoke-Supabase "db push"

# -----------------------------------------------------------------------
# 7. Re-check migration status after push
# -----------------------------------------------------------------------
Write-Step "Migration status - AFTER push (confirm everything applied)"
Invoke-Supabase "migration list"

# -----------------------------------------------------------------------
# 8. Deploy all edge functions
# -----------------------------------------------------------------------
Write-Step "Deploying all edge functions"
$functionsDir = "supabase\functions"
$functionNames = Get-ChildItem -Path $functionsDir -Directory | Where-Object { $_.Name -ne "_shared" } | Select-Object -ExpandProperty Name

foreach ($fn in $functionNames) {
    Write-Host "`n  Deploying: $fn" -ForegroundColor Yellow
    Invoke-Supabase "functions deploy $fn"
}

# -----------------------------------------------------------------------
# 9. Confirm the "invoices" storage bucket exists
# -----------------------------------------------------------------------
Write-Step "Verifying 'invoices' storage bucket"
Write-Host "  Open Supabase Dashboard > Storage and confirm an 'invoices' bucket exists (public)." -ForegroundColor White
Write-Host "  It should already be there if 0004_storage_bucket.sql shows applied above." -ForegroundColor White

Write-Host "`n=============================================================================" -ForegroundColor Cyan
Write-Host "DONE. Summary:" -ForegroundColor Cyan
Write-Host "  - Migrations 0001-0004 pushed to remote Postgres" -ForegroundColor White
Write-Host "  - All edge functions deployed" -ForegroundColor White
Write-Host "  - Next: cd ..\frontend; npm run dev  -- and test every module end to end" -ForegroundColor White
Write-Host "`nSECURITY NOTE: you shared your DB password and service_role/secret keys in" -ForegroundColor Red
Write-Host "chat earlier. Consider rotating them from Dashboard > Settings > API once" -ForegroundColor Red
Write-Host "you're done, since they grant full access to your project." -ForegroundColor Red
Write-Host "=============================================================================" -ForegroundColor Cyan