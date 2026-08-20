#
# fix-receipts-duplicate-loader.ps1
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes: apps/frontend/app/(dashboard)/receipts/page.tsx
#
#   `loadRawMaterialsModule` was declared twice in ReceiptsPage - once near the
#   top (correct, used by the page's own useEffect) and a second time right
#   before the isRefreshing/handleRefresh block that a refresh-button script
#   injected later. Turbopack build error:
#     the name `loadRawMaterialsModule` is defined multiple times
#
#   This script removes the duplicate declaration and keeps the
#   isRefreshing/handleRefresh block (which still works fine referencing the
#   single remaining declaration).
#
# Safe to re-run - already-applied files are skipped.
# Backup made before any edit: <file>.bak-<timestamp>
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
}

$pagePath = Join-Path $root "apps\frontend\app\(dashboard)\receipts\page.tsx"

if (-not (Test-Path -LiteralPath $pagePath)) {
    Write-Host "ERROR: Could not find $pagePath" -ForegroundColor Red
    exit 1
}

$content = Get-Content -Raw -LiteralPath $pagePath

# Count occurrences of the declaration line
$declPattern = 'const\s+loadRawMaterialsModule\s*=\s*useStore\(\(s\)\s*=>\s*s\.loadRawMaterialsModule\);'
$matches = [regex]::Matches($content, $declPattern)

if ($matches.Count -le 1) {
    Write-Host "receipts/page.tsx already fixed (only $($matches.Count) declaration found) - skipping." -ForegroundColor Yellow
    exit 0
}

if ($matches.Count -gt 2) {
    Write-Host "WARNING: Found $($matches.Count) declarations, expected 2. Proceeding to remove all but the first - please double check the result." -ForegroundColor Yellow
}

Backup-File $pagePath

# Remove the duplicate: the pattern where the declaration is immediately
# followed by "const [isRefreshing" (the injected duplicate), keeping the
# earlier, original declaration near the top of the component intact.
$dupPattern = '(?s)\s*const\s+loadRawMaterialsModule\s*=\s*useStore\(\(s\)\s*=>\s*s\.loadRawMaterialsModule\);\s*(?=const\s*\[isRefreshing)'

$newContent = [regex]::Replace($content, $dupPattern, "`n  ", 1)

if ($newContent -eq $content) {
    Write-Host "ERROR: Could not locate the duplicate declaration pattern - aborting without changes." -ForegroundColor Red
    exit 1
}

Set-Content -LiteralPath $pagePath -Value $newContent -NoNewline

Write-Host ""
Write-Host "Done. receipts/page.tsx patched:" -ForegroundColor Green
Write-Host "  - Removed the duplicate 'loadRawMaterialsModule' declaration." -ForegroundColor Green
Write-Host ""
Write-Host "Now run: npm run build   (or push to trigger the Vercel build) to verify." -ForegroundColor Cyan