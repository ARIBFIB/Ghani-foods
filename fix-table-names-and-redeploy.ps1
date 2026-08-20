#
# fix-table-names-and-redeploy.ps1
# -----------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes: "Could not find the table 'public.invoice_lines' in the schema
# cache" (and similar) errors from data-export / data-delete.
#
# ROOT CAUSE: the two edge functions were generated with GUESSED table
# names that don't match your real Supabase schema. By cross-checking
# the rest of the app's code (which already talks to the real tables),
# the following corrections are needed:
#
#   receipts            -> purchase_receipts
#   receipt_lines        -> purchase_receipt_lines
#   batches              -> production_batches
#   invoice_lines        -> invoice_items
#
# (raw_materials, suppliers, customers, invoices, payments, wrappers,
#  boxes, carton_configurations, finished_cartons were already correct)
#
# This script:
#   1. Backs up and fixes apps/backend/supabase/functions/data-export/index.ts
#   2. Backs up and fixes apps/backend/supabase/functions/data-delete/index.ts
#   3. Redeploys both functions with --no-verify-jwt
#
# Safe to re-run - if a replacement was already applied it will be skipped.
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
        Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
    } else {
        Write-Host "  ERROR: File not found: $path" -ForegroundColor Red
        exit 1
    }
}

function Fix-TableNames($path, [string[]]$replacements) {
    # $replacements is a flat array: old1, new1, old2, new2, ...
    $content = Get-Content -Raw -LiteralPath $path
    $original = $content
    $changedAny = $false

    for ($i = 0; $i -lt $replacements.Length; $i += 2) {
        $old = $replacements[$i]
        $new = $replacements[$i + 1]
        if ($content -match [regex]::Escape($old)) {
            $content = $content.Replace($old, $new)
            $changedAny = $true
            Write-Host "  $old -> $new" -ForegroundColor DarkGray
        }
    }

    if ($changedAny -and $content -ne $original) {
        Backup-File $path
        Set-Content -LiteralPath $path -Value $content -NoNewline
        return $true
    } else {
        Write-Host "  No matching old table names found in $(Split-Path $path -Leaf) - already fixed or file changed." -ForegroundColor Yellow
        return $false
    }
}

# -----------------------------------------------------------------
# 1. Fix data-export/index.ts
# -----------------------------------------------------------------
$exportFnPath = Join-Path $root "apps\backend\supabase\functions\data-export\index.ts"
if (-not (Test-Path -LiteralPath $exportFnPath)) {
    Write-Host "ERROR: Could not find $exportFnPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Fixing data-export/index.ts ..." -ForegroundColor Cyan
$exportChanged = Fix-TableNames $exportFnPath @(
    'table: "receipts", dateColumn: "purchase_date"', 'table: "purchase_receipts", dateColumn: "purchase_date"',
    'table: "receipt_lines"',                          'table: "purchase_receipt_lines"',
    'table: "batches", dateColumn: "created_at"',       'table: "production_batches", dateColumn: "created_at"',
    'table: "invoice_lines"',                           'table: "invoice_items"'
)

# -----------------------------------------------------------------
# 2. Fix data-delete/index.ts
# -----------------------------------------------------------------
$deleteFnPath = Join-Path $root "apps\backend\supabase\functions\data-delete\index.ts"
if (-not (Test-Path -LiteralPath $deleteFnPath)) {
    Write-Host "ERROR: Could not find $deleteFnPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Fixing data-delete/index.ts ..." -ForegroundColor Cyan
$deleteChanged = Fix-TableNames $deleteFnPath @(
    '"invoice_lines",',   '"invoice_items",',
    '"receipt_lines",',   '"purchase_receipt_lines",',
    '"receipts",',        '"purchase_receipts",',
    '"batches",',         '"production_batches",'
)

# -----------------------------------------------------------------
# 3. Redeploy both functions
# -----------------------------------------------------------------
$backendDir = Join-Path $root "apps\backend"
Push-Location $backendDir
try {
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

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Hard-refresh https://ghani-foods.vercel.app/settings?tab=export (Ctrl+Shift+R) and try Export / Delete All Data again." -ForegroundColor Green
Write-Host ""
Write-Host "NOTE: if you still get 'table not found' for a DIFFERENT table name," -ForegroundColor Yellow
Write-Host "share the exact error and I will fix that one too - there may be" -ForegroundColor Yellow
Write-Host "column-name mismatches (e.g. dateColumn) that only show up once the" -ForegroundColor Yellow
Write-Host "table names themselves are correct." -ForegroundColor Yellow