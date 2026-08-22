<#
  fix-testing-report-issues.ps1
  Purpose: Fix all issues found in TestingReport_20260823_000220.json for GhaniFoods:
    1. Empty catch blocks in apps/frontend/app/layout.tsx
    2. Hardcoded localhost URLs in apps/backend/src/index.ts
    3. console.log statements left in apps/backend/src/index.ts
    4. "any" type usage (55 instances) across backend + frontend files
       -> replaced with Record<string, unknown> (safe, compiles cleanly
          since all usages only do Number(x.field) / property reads)
    5. The 5 "SUSPECT: empty function body" functions were manually
       verified and are FALSE POSITIVES (ensureSpace, drawText,
       statusForPgError, jsonResponse, getCookie all have real bodies).
       No code change needed there - noted here for the record only.

  Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\fix-testing-report-issues.ps1
    .\fix-testing-report-issues.ps1 -WhatIf   # preview changes, no writes
#>

param(
    [switch]$WhatIf
)

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host $Text -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Text)
    Write-Host "  -> $Text" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Text)
    Write-Host "  -- $Text" -ForegroundColor DarkYellow
}

function Write-Fail {
    param([string]$Text)
    Write-Host "  ERROR: $Text" -ForegroundColor Red
}

function Save-File {
    param([string]$Path, [string]$Content, [string]$Original)
    if ($Content -eq $Original) {
        Write-Skip "No change needed: $Path"
        return
    }
    if ($WhatIf) {
        Write-Ok "[WhatIf] Would update: $Path"
        return
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Ok "Updated: $Path"
}

# NOTE: paths containing [ ] (e.g. Next.js dynamic routes like [id]) are
# treated as wildcard patterns by PowerShell's default path cmdlets, so
# every file read/write/existence-check below uses -LiteralPath instead
# of the positional -Path parameter.

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

# ===========================================================================
# 1. Fix empty catch blocks + theme-init robustness in layout.tsx
# ===========================================================================
Write-Step "[1/5] Fixing empty catch blocks in apps/frontend/app/layout.tsx..."

$layoutPath = Join-Path $root "apps\frontend\app\layout.tsx"
if (-not (Test-Path -LiteralPath $layoutPath)) {
    Write-Fail "Not found: $layoutPath"
}
else {
    $original = Get-Content -LiteralPath $layoutPath -Raw -Encoding UTF8
    $content = $original

    $content = $content.Replace(
        "    try { stored = localStorage.getItem('theme'); } catch (e) {}",
        "    try { stored = localStorage.getItem('theme'); } catch (e) { console.warn('theme-init: could not read localStorage', e); }"
    )
    $content = $content.Replace(
        "      try { localStorage.setItem('theme', stored); } catch (e) {}",
        "      try { localStorage.setItem('theme', stored); } catch (e) { console.warn('theme-init: could not write localStorage', e); }"
    )

    Save-File -Path $layoutPath -Content $content -Original $original
}

# ===========================================================================
# 2 & 3. Fix hardcoded localhost URLs + remove console.log in backend index.ts
# ===========================================================================
Write-Step "[2/5] Fixing hardcoded localhost + console.log in apps/backend/src/index.ts..."

$backendIndexPath = Join-Path $root "apps\backend\src\index.ts"
if (-not (Test-Path -LiteralPath $backendIndexPath)) {
    Write-Fail "Not found: $backendIndexPath"
}
else {
    $original = Get-Content -LiteralPath $backendIndexPath -Raw -Encoding UTF8
    $content = $original

    # 2a. No hardcoded localhost fallback - require env var explicitly.
    $content = $content.Replace(
        'const FRONTEND_ORIGIN = process.env.FRONTEND_ORIGIN || "http://localhost:3000";',
        "const FRONTEND_ORIGIN = process.env.FRONTEND_ORIGIN;`r`nif (!FRONTEND_ORIGIN) {`r`n  throw new Error(`"FRONTEND_ORIGIN env var is required (e.g. http://localhost:3000 for local dev)`");`r`n}"
    )

    # 2b. Startup log: use the actual configured origin instead of a
    # hardcoded string, and gate the request logger behind NODE_ENV
    # instead of deleting it outright (still useful in dev).
    $content = $content.Replace(
        'app.use((req, _res, next) => {' + "`r`n" + '  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);' + "`r`n" + '  next();' + "`r`n" + '});',
        'app.use((req, _res, next) => {' + "`r`n" + '  if (process.env.NODE_ENV !== "production") {' + "`r`n" + '    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);' + "`r`n" + '  }' + "`r`n" + '  next();' + "`r`n" + '});'
    )

    $content = $content.Replace(
        'app.listen(PORT, () => {' + "`r`n" + '  console.log(`GhaniFoods backend running at http://localhost:${PORT}`);' + "`r`n" + '});',
        'app.listen(PORT, () => {' + "`r`n" + '  console.log(`GhaniFoods backend running on port ${PORT} (origin: ${FRONTEND_ORIGIN})`);' + "`r`n" + '});'
    )

    Save-File -Path $backendIndexPath -Content $content -Original $original
}

# ===========================================================================
# 4. Replace ": any" with ": Record<string, unknown>" across flagged files
# ===========================================================================
Write-Step "[3/5] Replacing weak 'any' types with Record<string, unknown>..."

$anyTypeFiles = @(
    "apps\backend\supabase\functions\dashboard-kpis\index.ts",
    "apps\backend\supabase\functions\inventory-leftover-summary\index.ts",
    "apps\backend\supabase\functions\reports-finished-carton-availability\index.ts",
    "apps\backend\supabase\functions\reports-inventory\index.ts",
    "apps\backend\supabase\functions\reports-pnl\index.ts",
    "apps\backend\supabase\functions\reports-production\index.ts",
    "apps\frontend\app\(dashboard)\batches\[id]\page.tsx",
    "apps\frontend\app\(dashboard)\monthly-expenses\page.tsx",
    "apps\frontend\components\ui\auth-page.tsx",
    "apps\frontend\lib\store.ts"
)

$totalReplacements = 0
foreach ($rel in $anyTypeFiles) {
    $path = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Fail "Not found (skipped): $rel"
        continue
    }

    $original = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $content = $original

    # Covers: (m: any), (m: any =>, (sum: number, m: any), etc.
    # i.e. any occurrence of ": any" immediately followed by ')' or ','
    $before = ([regex]::Matches($content, ':\s*any\s*(?=[),])')).Count
    $content = [regex]::Replace($content, ':\s*any\s*(?=[),])', ': Record<string, unknown>')

    if ($before -gt 0) {
        $totalReplacements += $before
        Save-File -Path $path -Content $content -Original $original
        Write-Host "     ($before occurrence(s) replaced in $rel)" -ForegroundColor DarkGray
    }
    else {
        Write-Skip "No ': any' pattern matched in $rel (may already be fixed or uses a different shape - review manually)"
    }
}

Write-Host ""
Write-Host "Total 'any' -> 'Record<string, unknown>' replacements: $totalReplacements" -ForegroundColor Cyan

# ===========================================================================
# 5. Note on false-positive "suspect" functions (no code change)
# ===========================================================================
Write-Step "[4/5] Suspect functions from report - verified manually, no fix needed:"
Write-Host "  - data-export/index.ts: ensureSpace() - has a real body (page overflow check)" -ForegroundColor DarkGray
Write-Host "  - data-export/index.ts: drawText()   - has a real body (PDF text draw helper)" -ForegroundColor DarkGray
Write-Host "  - _shared/client.ts: statusForPgError() - has a real body (error code mapping)" -ForegroundColor DarkGray
Write-Host "  - _shared/client.ts: jsonResponse()     - has a real body (Response wrapper)" -ForegroundColor DarkGray
Write-Host "  - layout.tsx: getCookie()  - has a real body (inside the theme-init IIFE string)" -ForegroundColor DarkGray
Write-Host "  These were scanner false positives. No action taken." -ForegroundColor DarkGray

# ===========================================================================
# 6. Optional: rebuild to confirm nothing broke
# ===========================================================================
Write-Step "[5/5] Verifying backend TypeScript still compiles..."

if ($WhatIf) {
    Write-Skip "Skipped build verification (-WhatIf mode)"
}
else {
    $backendPath = Join-Path $root "apps\backend"
    if (Test-Path $backendPath) {
        Push-Location $backendPath
        try {
            npm run build
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "Backend build failed after changes - please review the diffs above."
            }
            else {
                Write-Ok "Backend build passed."
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Skip "apps\backend not found, skipping build check."
    }
}

Write-Host ""
Write-Host "Done. Review changes with 'git diff', then commit." -ForegroundColor Cyan