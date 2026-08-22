<#
  fix-vercel-build-and-local-server.ps1
  Purpose: Fix TWO regressions introduced by fix-testing-report-issues.ps1:

  1. VERCEL BUILD FAILURE (TypeScript):
     The blanket "any -> Record<string, unknown>" replacement made row
     fields (r.id, r.name, r.month, r.batchId, etc.) come back as
     `unknown`. That's fine for Number(...) calls (Number accepts any),
     but it broke assignment into typed string fields:
       apps/frontend/app/(dashboard)/batches/[id]/page.tsx
       apps/frontend/app/(dashboard)/monthly-expenses/page.tsx
     Fix: wrap those specific string fields in String(...).

  2. LOCAL DEV SERVER "DID NOT START":
     apps/backend/src/index.ts now throws at startup if FRONTEND_ORIGIN
     is not set in the environment. That's correct for production but
     breaks local dev machines / CI runners that don't have a .env with
     FRONTEND_ORIGIN set.
     Fix: only require FRONTEND_ORIGIN in production; default to
     http://localhost:3000 with a console.warn in all other environments.

  Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\fix-vercel-build-and-local-server.ps1
    .\fix-vercel-build-and-local-server.ps1 -WhatIf
#>

param(
    [switch]$WhatIf
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

function Save-File {
    param([string]$Path, [string]$Content, [string]$Original)
    if ($Content -eq $Original) {
        Write-Skip "No change needed (pattern not found or already fixed): $Path"
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

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

# ===========================================================================
# 1. Fix TypeScript type errors: batches/[id]/page.tsx
# ===========================================================================
Write-Step "[1/3] Fixing TS type error in apps/frontend/app/(dashboard)/batches/[id]/page.tsx..."

$batchDetailPath = Join-Path $root "apps\frontend\app\(dashboard)\batches\[id]\page.tsx"
if (-not (Test-Path -LiteralPath $batchDetailPath)) {
    Write-Fail "Not found: $batchDetailPath"
}
else {
    $original = Get-Content -LiteralPath $batchDetailPath -Raw -Encoding UTF8
    $content = $original

    $content = $content.Replace(
        "      (expensesRes.data ?? []).map((r: Record<string, unknown>) => ({`r`n        id: r.id,`r`n        name: r.name,`r`n        amount: Number(r.amount),`r`n        createdAt: r.created_at,`r`n      }))",
        "      (expensesRes.data ?? []).map((r: Record<string, unknown>) => ({`r`n        id: String(r.id),`r`n        name: String(r.name),`r`n        amount: Number(r.amount),`r`n        createdAt: String(r.created_at),`r`n      }))"
    )

    $content = $content.Replace(
        "      (allocationsRes.data ?? []).map((r: Record<string, unknown>) => ({`r`n        id: r.id,`r`n        month: r.month,`r`n        allocationMethod: r.allocation_method,`r`n        totalMonthExpense: Number(r.total_month_expense),`r`n        batchShare: Number(r.batch_share),`r`n      }))",
        "      (allocationsRes.data ?? []).map((r: Record<string, unknown>) => ({`r`n        id: String(r.id),`r`n        month: String(r.month),`r`n        allocationMethod: String(r.allocation_method),`r`n        totalMonthExpense: Number(r.total_month_expense),`r`n        batchShare: Number(r.batch_share),`r`n      }))"
    )

    Save-File -Path $batchDetailPath -Content $content -Original $original
}

# ===========================================================================
# 2. Fix TypeScript type errors: monthly-expenses/page.tsx
# ===========================================================================
Write-Step "[2/3] Fixing TS type error in apps/frontend/app/(dashboard)/monthly-expenses/page.tsx..."

$monthlyExpensesPath = Join-Path $root "apps\frontend\app\(dashboard)\monthly-expenses\page.tsx"
if (-not (Test-Path -LiteralPath $monthlyExpensesPath)) {
    Write-Fail "Not found: $monthlyExpensesPath"
}
else {
    $original = Get-Content -LiteralPath $monthlyExpensesPath -Raw -Encoding UTF8
    $content = $original

    $content = $content.Replace(
        '(data ?? []).map((r: Record<string, unknown>) => ({ id: r.id, month: r.month, name: r.name, amount: Number(r.amount) }))',
        '(data ?? []).map((r: Record<string, unknown>) => ({ id: String(r.id), month: String(r.month), name: String(r.name), amount: Number(r.amount) }))'
    )

    $content = $content.Replace(
        "      allocations: (result.allocations ?? []).map((a: Record<string, unknown>) => ({`r`n        batchId: a.batchId,`r`n        outputYieldKg: Number(a.outputYieldKg),`r`n        share: Number(a.share),`r`n      })),",
        "      allocations: (result.allocations ?? []).map((a: Record<string, unknown>) => ({`r`n        batchId: String(a.batchId),`r`n        outputYieldKg: Number(a.outputYieldKg),`r`n        share: Number(a.share),`r`n      })),"
    )

    Save-File -Path $monthlyExpensesPath -Content $content -Original $original
}

# ===========================================================================
# 3. Fix local dev server crash: apps/backend/src/index.ts
# ===========================================================================
Write-Step "[3/3] Fixing FRONTEND_ORIGIN startup crash in apps/backend/src/index.ts..."

$backendIndexPath = Join-Path $root "apps\backend\src\index.ts"
if (-not (Test-Path -LiteralPath $backendIndexPath)) {
    Write-Fail "Not found: $backendIndexPath"
}
else {
    $original = Get-Content -LiteralPath $backendIndexPath -Raw -Encoding UTF8
    $content = $original

    $content = $content.Replace(
        'const FRONTEND_ORIGIN = process.env.FRONTEND_ORIGIN;' + "`r`n" + 'if (!FRONTEND_ORIGIN) {' + "`r`n" + '  throw new Error("FRONTEND_ORIGIN env var is required (e.g. http://localhost:3000 for local dev)");' + "`r`n" + '}',
        'const DEFAULT_DEV_ORIGIN = "http://localhost:3000";' + "`r`n" + 'let FRONTEND_ORIGIN = process.env.FRONTEND_ORIGIN;' + "`r`n" + 'if (!FRONTEND_ORIGIN) {' + "`r`n" + '  if (process.env.NODE_ENV === "production") {' + "`r`n" + '    throw new Error("FRONTEND_ORIGIN env var is required in production");' + "`r`n" + '  }' + "`r`n" + '  console.warn(`FRONTEND_ORIGIN not set, defaulting to ${DEFAULT_DEV_ORIGIN} for local dev`);' + "`r`n" + '  FRONTEND_ORIGIN = DEFAULT_DEV_ORIGIN;' + "`r`n" + '}'
    )

    Save-File -Path $backendIndexPath -Content $content -Original $original
}

# ===========================================================================
# Verify: backend build + frontend build
# ===========================================================================
if (-not $WhatIf) {
    Write-Step "Verifying builds..."

    $backendPath = Join-Path $root "apps\backend"
    if (Test-Path -LiteralPath $backendPath) {
        Push-Location $backendPath
        try {
            npm run build
            if ($LASTEXITCODE -ne 0) { Write-Fail "Backend build failed - review diffs above." }
            else { Write-Ok "Backend build passed." }
        } finally { Pop-Location }
    }

    $frontendPath = Join-Path $root "apps\frontend"
    if (Test-Path -LiteralPath $frontendPath) {
        Push-Location $frontendPath
        try {
            npm run build
            if ($LASTEXITCODE -ne 0) { Write-Fail "Frontend build failed - review diffs above." }
            else { Write-Ok "Frontend build passed." }
        } finally { Pop-Location }
    }
}
else {
    Write-Step "Skipped build verification (-WhatIf mode)"
}

Write-Host ""
Write-Host "Done. Review changes with 'git diff', then commit and push to trigger a new Vercel build." -ForegroundColor Cyan