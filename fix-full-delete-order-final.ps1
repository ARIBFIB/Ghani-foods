#
# fix-full-delete-order-final.ps1
# -----------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes: "Delete failed for wrappers: violates foreign key constraint
# carton_configurations_wrapper_id_fkey" (and prevents further
# whack-a-mole FK errors from the same root cause).
#
# ROOT CAUSE: DELETE_ORDER was built incrementally by patching one FK
# error at a time. This script replaces it ONCE with the complete,
# correct order derived directly from 0001_init_schema.sql's foreign
# keys, so every table's children are deleted before it.
#
# Dependency chain (child -> parent), verified against the schema:
#   payments                -> customer_ledger_entries, customers
#   customer_ledger_entries -> customers
#   customer_item_prices    -> customers, finished_cartons
#   invoice_items            -> invoices, finished_cartons
#   invoices                 -> customers
#   batch_consumptions       -> production_batches, raw_materials
#   finished_cartons         -> production_batches, carton_configurations
#   carton_configurations    -> wrappers, boxes
#   box_production_runs      -> boxes
#   wrapper_production_runs  -> wrappers
#   purchase_receipt_lines   -> purchase_receipts, raw_materials
#   purchase_receipts        -> suppliers
#   production_batches       -> (self-referencing only, safe in bulk delete)
#   wrappers                 -> raw_materials
#   boxes                    -> raw_materials
#   raw_materials, suppliers, customers -> (roots, deleted last)
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

if ($content -notmatch [regex]::Escape('const DELETE_ORDER: string[] = [')) {
    Write-Host "ERROR: Could not find DELETE_ORDER array start in the file." -ForegroundColor Red
    exit 1
}

# Extract everything from "const DELETE_ORDER" up to its closing "];"
$pattern = '(?s)const DELETE_ORDER: string\[\] = \[.*?\];'
if ($content -notmatch $pattern) {
    Write-Host "ERROR: Could not isolate the full DELETE_ORDER array block." -ForegroundColor Red
    exit 1
}

$newOrderBlock = @'
const DELETE_ORDER: string[] = [
  // -- deepest children first, verified against 0001_init_schema.sql --
  "payments",                   // FK -> customer_ledger_entries, customers
  "customer_ledger_entries",    // FK -> customers
  "customer_item_prices",       // FK -> customers, finished_cartons
  "invoice_items",               // FK -> invoices, finished_cartons
  "invoices",                    // FK -> customers
  "batch_consumptions",          // FK -> production_batches, raw_materials
  "finished_cartons",            // FK -> production_batches, carton_configurations
  "carton_configurations",       // FK -> wrappers, boxes
  "box_production_runs",         // FK -> boxes
  "wrapper_production_runs",     // FK -> wrappers
  "purchase_receipt_lines",      // FK -> purchase_receipts, raw_materials
  "purchase_receipts",           // FK -> suppliers
  "production_batches",          // self-referencing only
  "wrappers",                    // FK -> raw_materials
  "boxes",                       // FK -> raw_materials
  "raw_materials",
  "suppliers",
  "customers",
];
'@

$updated = [regex]::Replace($content, $pattern, { param($m) $newOrderBlock.TrimEnd("`r`n") })

Backup-File $deleteFnPath
Set-Content -LiteralPath $deleteFnPath -Value $updated -NoNewline
Write-Host "data-delete/index.ts -> DELETE_ORDER fully replaced with correct FK-safe order (18 tables)." -ForegroundColor Green

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