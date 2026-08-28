<#
export-step-d3-files.ps1

Purpose: Export current content of the files needed to plan Step D3
(Supplier Payment dialog) so Claude can generate an accurate change
script instead of guessing.

Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

Output: step-d3-export-<timestamp>.txt in the repo root.
Paste the full contents of that .txt file back into chat.
#>

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outFile = ".\step-d3-export-$timestamp.txt"
$outFileFull = [System.IO.Path]::GetFullPath($outFile)

$filesToExport = @(
    "apps\frontend\app\(dashboard)\suppliers\[id]\page.tsx",
    "apps\frontend\app\(dashboard)\suppliers\page.tsx",
    "apps\frontend\components\ui\purchase-order-dialog.tsx",
    "apps\frontend\lib\store.ts",
    "apps\backend\supabase\functions\supplier-payments\index.ts"
)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("=== STEP D3 EXPORT - $timestamp ===")
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
Write-Host "=== STEP D3 EXPORT COMPLETE ===" -ForegroundColor Green
Write-Host "Output file: $outFileFull"
Write-Host "Files attempted: $($filesToExport.Count)"
Write-Host ""
Write-Host "NEXT: Open the .txt file, copy its full contents, and paste them" -ForegroundColor Cyan
Write-Host "back into the chat so the real Step D3 (Supplier Payment dialog)" -ForegroundColor Cyan
Write-Host "change script can be generated accurately." -ForegroundColor Cyan