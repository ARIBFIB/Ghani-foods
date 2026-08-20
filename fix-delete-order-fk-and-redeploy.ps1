#
# fix-delete-order-fk-and-redeploy.ps1
# ---------------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes: "Delete failed for production_batches: update or delete on table
# production_batches violates foreign key constraint
# batch_consumptions_batch_id_fkey"
#
# ROOT CAUSE: DELETE_ORDER in data-delete/index.ts was missing several
# CHILD tables (batch_consumptions, box_production_runs,
# wrapper_production_runs, customer_item_prices, customer_ledger_entries).
# Rows in those tables reference rows in production_batches / boxes /
# wrappers / customers via foreign keys, so those parents can't be
# deleted until the children are deleted first.
#
# This script replaces DELETE_ORDER with a complete, FK-safe order
# (verified against the other edge functions that already query these
# tables: raw-materials-history, boxes-production-runs,
# wrappers-production-runs, customers-item-prices, customers-ledger).
#
# Safe to re-run.
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

$deleteFnPath = Join-Path $root "apps\backend\supabase\functions\data-delete\index.ts"
if (-not (Test-Path -LiteralPath $deleteFnPath)) {
    Write-Host "ERROR: Could not find $deleteFnPath" -ForegroundColor Red
    exit 1
}

$content = Get-Content -Raw -LiteralPath $deleteFnPath

$oldOrder = 'const DELETE_ORDER: string[] = [
  "invoice_items",
  "invoices",
  "payments",
  "purchase_receipt_lines",
  "purchase_receipts",
  "production_batches",
  "wrappers",
  "boxes",
  "carton_configurations",
  "finished_cartons",
  "raw_materials",
  "suppliers",
  "customers",
];'

$newOrder = 'const DELETE_ORDER: string[] = [
  // -- deepest children first --
  "customer_ledger_entries",   // FK -> customers
  "customer_item_prices",      // FK -> customers, finished_cartons
  "invoice_items",              // FK -> invoices
  "invoices",                   // FK -> customers
  "payments",                   // FK -> invoices / customers
  "batch_consumptions",         // FK -> production_batches, raw_materials
  "box_production_runs",        // FK -> boxes
  "wrapper_production_runs",    // FK -> wrappers
  "purchase_receipt_lines",     // FK -> purchase_receipts, raw_materials
  "purchase_receipts",          // FK -> suppliers
  "production_batches",
  "wrappers",
  "boxes",
  "carton_configurations",
  "finished_cartons",
  "raw_materials",
  "suppliers",
  "customers",
];'

if ($content -match [regex]::Escape('"customer_ledger_entries",')) {
    Write-Host "DELETE_ORDER already includes the fix - skipping." -ForegroundColor Yellow
}
elseif ($content -match [regex]::Escape($oldOrder)) {
    Backup-File $deleteFnPath
    $updated = $content.Replace($oldOrder, $newOrder)
    Set-Content -LiteralPath $deleteFnPath -Value $updated -NoNewline
    Write-Host "DELETE_ORDER -> replaced with complete FK-safe order (18 tables)." -ForegroundColor Green
}
else {
    Write-Host "ERROR: Could not find the expected DELETE_ORDER block." -ForegroundColor Red
    Write-Host "The file may differ from what this script expects - open it and check manually:" -ForegroundColor Red
    Write-Host $deleteFnPath -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------
# Redeploy
# -----------------------------------------------------------------
$backendDir = Join-Path $root "apps\backend"
Push-Location $backendDir
try {
    Write-Host ""
    Write-Host "Deploying data-delete..." -ForegroundColor Cyan
    & supabase functions deploy data-delete --no-verify-jwt
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Hard-refresh https://ghani-foods.vercel.app/settings?tab=export (Ctrl+Shift+R) and try Delete All Data again." -ForegroundColor Green
Write-Host ""
Write-Host "NOTE: if a NEW foreign-key error appears naming a different table," -ForegroundColor Yellow
Write-Host "share it and I will add that table to DELETE_ORDER too - your" -ForegroundColor Yellow
Write-Host "schema may have a few more child tables than what's covered here." -ForegroundColor Yellow