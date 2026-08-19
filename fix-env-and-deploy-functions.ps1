# =============================================================================
# GhaniFoods - Fix corrupted .env, then deploy all Supabase edge functions
# Can be run from EITHER the repo root OR apps\backend directly.
# =============================================================================

$ErrorActionPreference = "Stop"
$ProjectRef = "hbvcdxhdkbksknasdqst"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  $msg" -ForegroundColor Red }

# -----------------------------------------------------------------------
# 0. Auto-locate apps\backend
# -----------------------------------------------------------------------
Write-Step "Locating apps\backend"

$cwd = Get-Location
$backendDir = $null

if (Test-Path (Join-Path $cwd "supabase\config.toml")) {
    $backendDir = $cwd.Path
} elseif (Test-Path (Join-Path $cwd "apps\backend\supabase\config.toml")) {
    $backendDir = Join-Path $cwd "apps\backend"
} else {
    $candidate = Get-ChildItem -Path $cwd -Filter "config.toml" -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "apps\\backend\\supabase\\config\.toml$" } |
        Select-Object -First 1
    if ($candidate) {
        $backendDir = Split-Path (Split-Path $candidate.FullName -Parent) -Parent
    }
}

if (-not $backendDir) {
    Write-Err "Could not find apps\backend\supabase\config.toml anywhere under $cwd"
    exit 1
}

Set-Location $backendDir
Write-Ok "Using backend dir: $backendDir"

# -----------------------------------------------------------------------
# 1. Fix the corrupted .env file
#    Error was: "unexpected character in variable name near
#    SUPABASE_PROJECT_REF=..." - almost always a UTF-8 BOM or stray
#    invisible character at the start of the file/line. Rewrite it clean,
#    plain ASCII, no BOM, LF line endings.
# -----------------------------------------------------------------------
Write-Step "Fixing .env file"

$envPath = Join-Path $backendDir ".env"

if (Test-Path $envPath) {
    $backupPath = "$envPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $envPath $backupPath -Force
    Write-Ok "Backed up existing .env -> $backupPath"

    # Read raw bytes, strip BOM/non-printable junk, keep only clean KEY=VALUE lines
    $rawLines = Get-Content -Path $envPath -Encoding UTF8
    $cleanLines = @()
    foreach ($line in $rawLines) {
        # Strip BOM char (U+FEFF) and any other non-ASCII control chars, trim whitespace
        $clean = ($line -replace "[\uFEFF\u200B\u200E\u200F]", "").Trim()
        if ($clean -match "^[A-Za-z_][A-Za-z0-9_]*=") {
            $cleanLines += $clean
        } elseif ($clean.Length -gt 0) {
            Write-Warn "Dropping malformed line: $clean"
        }
    }

    if ($cleanLines.Count -eq 0) {
        Write-Warn "No valid KEY=VALUE lines found - writing a minimal clean .env"
        $cleanLines = @("SUPABASE_PROJECT_REF=$ProjectRef")
    }

    # Write with no BOM, LF endings
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $content = ($cleanLines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($envPath, $content, $utf8NoBom)
    Write-Ok "Rewrote clean .env ($($cleanLines.Count) line(s), no BOM)"
    Write-Host "  Contents:" -ForegroundColor DarkGray
    $cleanLines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
} else {
    Write-Warn ".env not found - creating a minimal one"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($envPath, "SUPABASE_PROJECT_REF=$ProjectRef`n", $utf8NoBom)
    Write-Ok "Created $envPath"
}

# -----------------------------------------------------------------------
# 2. Resolve Supabase CLI command
# -----------------------------------------------------------------------
Write-Step "Resolving Supabase CLI"

$supabaseCmd = $null
if (Get-Command supabase -ErrorAction SilentlyContinue) {
    $supabaseCmd = "supabase"
    Write-Ok "Found 'supabase' on PATH"
} else {
    try {
        $null = npx --yes supabase --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $supabaseCmd = "npx --yes supabase"
            Write-Ok "Using 'npx supabase'"
        }
    } catch {}
}

if (-not $supabaseCmd) {
    Write-Err "Supabase CLI not available. Run setup-and-push-supabase.ps1 first."
    exit 1
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

# -----------------------------------------------------------------------
# 3. Test with a single function first before looping all of them
# -----------------------------------------------------------------------
Write-Step "Sanity check: deploying one function first (batches)"
Invoke-Supabase "functions deploy batches"

if ($LASTEXITCODE -ne 0) {
    Write-Err "Still failing after .env fix. Try running with --debug manually:"
    Write-Err "  npx --yes supabase functions deploy batches --debug"
    Write-Err "Also check: apps\backend\supabase\.temp folder and confirm you're linked (supabase status)."
    exit 1
}

Write-Ok "Sanity check passed - proceeding to deploy the rest"

# -----------------------------------------------------------------------
# 4. Deploy all remaining edge functions
# -----------------------------------------------------------------------
Write-Step "Deploying all remaining edge functions"
$functionsDir = "supabase\functions"
$functionNames = Get-ChildItem -Path $functionsDir -Directory |
    Where-Object { $_.Name -ne "_shared" -and $_.Name -ne "batches" } |
    Select-Object -ExpandProperty Name

$failed = @()
foreach ($fn in $functionNames) {
    Write-Host "`n  Deploying: $fn" -ForegroundColor Yellow
    Invoke-Supabase "functions deploy $fn"
    if ($LASTEXITCODE -ne 0) {
        $failed += $fn
        Write-Err "  FAILED: $fn"
    }
}

Write-Host "`n=============================================================================" -ForegroundColor Cyan
if ($failed.Count -eq 0) {
    Write-Host "DONE. All edge functions deployed successfully (including 'batches')." -ForegroundColor Green
} else {
    Write-Host "DONE with $($failed.Count) failure(s):" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}
Write-Host "Next: cd ..\frontend; npm run dev  -- and test every module end to end" -ForegroundColor White
Write-Host "=============================================================================" -ForegroundColor Cyan