<#
Export apps\frontend\lib\store.ts content to a timestamped .txt so it can be
shared back for exact-match verification before generating Step D2
(purchase-receipt-dialog.tsx -> PO-based receipt UI).

Run from repo root:
  .\export-store-verify.ps1
#>

$ErrorActionPreference = "Stop"

$target = "apps\frontend\lib\store.ts"

if (-not (Test-Path $target)) {
    Write-Host "ERROR: $target not found. Run this script from the GhaniFoods repo root." -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outFile = "store-verify-$timestamp.txt"

$header = "===================================================================`r`nFILE: $target`r`n===================================================================`r`n"
$header | Set-Content -Path $outFile -NoNewline
Get-Content -Path $target -Raw | Add-Content -Path $outFile -NoNewline

Write-Host "Wrote: $outFile"
Write-Host "Please paste/upload this file's content back so Step D2 (purchase-receipt-dialog.tsx) can be generated to exactly match your store.ts shape."