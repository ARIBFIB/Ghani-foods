<#
export-step-d4-sql.ps1

Purpose: Export migration 0009 (fn_create_credit_note / fn_create_debit_note
/ fn_create_contra_transfer / supplier ledger) and the invoice_items table
definition from 0002_functions.sql, so the credit-notes body-shape mismatch
(itemId vs invoiceItemId) can be resolved correctly against the real SQL
function signature instead of guessing.

Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

Output: step-d4-sql-export-<timestamp>.txt in the repo root.
Paste the full contents of that .txt file back into chat.
#>

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outFile = ".\step-d4-sql-export-$timestamp.txt"
$outFileFull = [System.IO.Path]::GetFullPath($outFile)

$filesToExport = @(
    "apps\backend\supabase\migrations\0009_contra_returns_supplier_ledger.sql",
    "apps\backend\supabase\migrations\0001_init_schema.sql",
    "apps\backend\supabase\migrations\0002_functions.sql"
)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("=== STEP D4 SQL EXPORT - $timestamp ===")
[void]$sb.AppendLine("")

foreach ($rel in $filesToExport) {
    [void]$sb.AppendLine("=====================================================")
    [void]$sb.AppendLine("FILE: $rel")
    [void]$sb.AppendLine("=====================================================")

    if (Test-Path -LiteralPath $rel) {
        try {
            $fullPath = (Resolve-Path -LiteralPath $rel).Path
            $content = [System.IO.File]::ReadAllText($fullPath)
            [void]$sb.AppendLine($content)
        } catch {
            [void]$sb.AppendLine("ERROR READING FILE: $($_.Exception.Message)")
        }
    } else {
        [void]$sb.AppendLine("FILE NOT FOUND AT THIS PATH")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("")
}

$outDir = Split-Path -Parent $outFileFull
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
[System.IO.File]::WriteAllText($outFileFull, $sb.ToString())

Write-Host ""
Write-Host "=== STEP D4 SQL EXPORT COMPLETE ===" -ForegroundColor Green
Write-Host "Output file: $outFileFull"
Write-Host ""
Write-Host "NEXT: Open the .txt file, copy its full contents, and paste them" -ForegroundColor Cyan
Write-Host "back into the chat so the credit-notes body-shape mismatch can be" -ForegroundColor Cyan
Write-Host "resolved correctly against the real SQL function signature." -ForegroundColor Cyan