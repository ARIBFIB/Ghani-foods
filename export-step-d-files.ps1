<#
export-step-d-files.ps1

Run from project root (GhaniFoods\):
    PS D:\...\GhaniFoods> .\export-step-d-files.ps1

Exports the files needed to:
  - verify Step A edge function body shapes exactly (so store.ts calls match)
  - write Step B for lib/api.ts (the wrapper layer, if used)
  - build Step D UI (purchase-receipt-dialog.tsx needs poId support)

Produces: step-d-export-<timestamp>.txt
#>

$ErrorActionPreference = "Continue"

$FilesToExport = @(
    "apps\backend\supabase\functions\supplier-payments\index.ts",
    "apps\backend\supabase\functions\credit-notes\index.ts",
    "apps\backend\supabase\functions\debit-notes\index.ts",
    "apps\backend\supabase\functions\contra-vouchers\index.ts",
    "apps\backend\supabase\functions\payments\index.ts",
    "apps\backend\supabase\functions\purchase-receipts\index.ts",
    "apps\frontend\lib\api.ts",
    "apps\frontend\components\ui\purchase-receipt-dialog.tsx",
    "apps\frontend\components\ui\purchase-order-dialog.tsx"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outFile = "step-d-export-$timestamp.txt"

if (Test-Path $outFile) { Remove-Item $outFile }

foreach ($file in $FilesToExport) {
    Add-Content -Path $outFile -Value "==================================================================="
    Add-Content -Path $outFile -Value "FILE: $file"
    Add-Content -Path $outFile -Value "==================================================================="
    if (Test-Path $file) {
        Get-Content -Path $file -Raw | Add-Content -Path $outFile
    } else {
        Add-Content -Path $outFile -Value "*** MISSING - file not found at this path ***"
        Write-Host "WARNING: missing -> $file" -ForegroundColor Yellow
    }
    Add-Content -Path $outFile -Value ""
}

Write-Host "Done. Wrote: $outFile"
Write-Host "Share this .txt back here - I'll verify body shapes match store.ts and build Step D."