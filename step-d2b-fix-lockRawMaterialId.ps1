<#
Step D2b - Fix remaining lockRawMaterialId usage
purchase-receipt-dialog.tsx no longer accepts lockRawMaterialId (Step D2 -
the dialog is now PO-driven, not material-driven). The only usage found by
`git grep -n lockRawMaterialId` is in:
  apps/frontend/app/(dashboard)/raw-materials/[id]/page.tsx

This script removes that prop from the <PurchaseReceiptDialog ... /> call
so the file compiles again. The dialog will just show all open POs when
opened from this page (no supplier/material pre-filter) - user picks the
right PO manually.

Run from repo root:
  .\step-d2b-fix-lockRawMaterialId.ps1
#>

$ErrorActionPreference = "Stop"

$target = "apps\frontend\app\(dashboard)\raw-materials\[id]\page.tsx"

if (-not (Test-Path -LiteralPath $target)) {
    Write-Host "ERROR: $target not found. Run this script from the GhaniFoods repo root." -ForegroundColor Red
    exit 1
}

$targetFull = (Resolve-Path -LiteralPath $target).Path

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$target.bak-$timestamp"
Copy-Item -LiteralPath $targetFull -Destination $backup
Write-Host "Backed up existing file -> $backup"

$text = Get-Content -LiteralPath $targetFull -Raw -Encoding UTF8

$old = '<PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} lockRawMaterialId={material.id} />'
$new = '<PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />'

if ($text.Contains($new)) {
    Write-Host "Already patched - no change needed." -ForegroundColor DarkYellow
} elseif ($text.Contains($old)) {
    $text = $text.Replace($old, $new)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($targetFull, $text, $utf8NoBom)
    Write-Host "Patched: removed lockRawMaterialId prop." -ForegroundColor Green
} else {
    Write-Host "WARNING: exact expected line not found (file may already differ)." -ForegroundColor Yellow
    Write-Host "Search manually for 'lockRawMaterialId' in:" -ForegroundColor Yellow
    Write-Host "  $target" -ForegroundColor Yellow
    Write-Host "and remove that prop from the <PurchaseReceiptDialog ... /> call by hand." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "STEP D2b COMPLETE" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "NEXT (Step D3): build the Supplier Payment dialog (calls" -ForegroundColor Green
Write-Host "store.recordSupplierPayment) and wire it into the Suppliers detail page." -ForegroundColor Green
Write-Host "Say 'next' to generate that .ps1." -ForegroundColor Green