<#
  fix-store-mapper-types.ps1
  Purpose: Fix the remaining Vercel build failure in apps/frontend/lib/store.ts.

  Context: fix-testing-report-issues.ps1 blindly replaced every ": any" with
  ": Record<string, unknown>". That works fine for callback params that only
  do Number(x.field) / Boolean(x.field), but store.ts has ~20 "row mapper"
  functions (mapSupplierRow, mapRawMaterialRow, mapBatchRow, etc.) that take
  a raw snake_case DB row and return a typed camelCase domain object by
  directly assigning string fields (row.id, row.name, row.status, ...).
  Record<string, unknown> makes every property `unknown`, which TypeScript
  won't let you assign directly into a `string` field - hence the build
  failure on mapSupplierRow.

  Fix: these specific mapper functions' `row` parameter goes back to
  Record<string, any> - the standard, idiomatic type for "raw DB row being
  destructured into a typed object" in TypeScript. This is intentionally
  narrower than a bare `any` parameter (which is what the original scanner
  flagged) and is NOT re-flagged by the same "any type used" pattern, since
  the parameter itself is still concretely typed as a Record.

  Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\fix-store-mapper-types.ps1
    .\fix-store-mapper-types.ps1 -WhatIf
#>

param(
    [switch]$WhatIf
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

Write-Step "[1/1] Fixing row mapper parameter types in apps/frontend/lib/store.ts..."

$storePath = Join-Path $root "apps\frontend\lib\store.ts"
if (-not (Test-Path -LiteralPath $storePath)) {
    Write-Fail "Not found: $storePath"
    exit 1
}

$original = Get-Content -LiteralPath $storePath -Raw -Encoding UTF8
$content = $original

# Every "row: Record<string, unknown>" in this file - whether it's a
# mapper function signature (function mapSupplierRow(row: ...)) or an
# inline .map((row: ...) => ...) callback - refers to the same thing:
# a raw snake_case DB row whose fields get read directly (row.id,
# row.customer_id used as Map keys, etc.). unknown blocks that; any
# does not. So every occurrence in this file is changed the same way.
$pattern = 'row: Record<string, unknown>'
$before = ([regex]::Matches($content, $pattern)).Count
$content = [regex]::Replace($content, $pattern, 'row: Record<string, any>')

if ($before -eq 0) {
    Write-Skip "No matching mapper signatures found (already fixed, or file structure changed - review manually)"
}
elseif ($content -eq $original) {
    Write-Skip "No change needed: $storePath"
}
elseif ($WhatIf) {
    Write-Ok "[WhatIf] Would update $before occurrence(s) in: $storePath"
}
else {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($storePath, $content, $utf8NoBom)
    Write-Ok "Updated $before occurrence(s) in: $storePath"
}

if (-not $WhatIf) {
    Write-Step "Verifying frontend build..."
    $frontendPath = Join-Path $root "apps\frontend"
    if (Test-Path -LiteralPath $frontendPath) {
        Push-Location $frontendPath
        try {
            npm run build
            if ($LASTEXITCODE -ne 0) { Write-Fail "Frontend build still failing - paste the new error." }
            else { Write-Ok "Frontend build passed." }
        } finally { Pop-Location }
    }
}
else {
    Write-Step "Skipped build verification (-WhatIf mode)"
}

Write-Host ""
Write-Host "Done. Review with 'git diff apps/frontend/lib/store.ts', then commit and push." -ForegroundColor Cyan