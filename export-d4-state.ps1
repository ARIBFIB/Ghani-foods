<#
export-d4-state.ps1

Purpose: Dump the CURRENT content of the files touched by
step-d4-credit-note-dialog.ps1 into one .txt file, so we can see
exactly what state the repo is in (since the last run partially
applied and then failed on the second run).

Run this from the repo root (GhaniFoods), then paste me the contents
of the generated .txt file. I will use that to figure out exactly
which of the 6 store.ts edits already landed and give you a corrected
.ps1 that only applies what's missing.

No files are modified by this script. It only reads and writes one
new .txt file.
#>

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Get-Location).Path

$targets = @(
    "apps\frontend\lib\store.ts",
    "apps\frontend\app\(dashboard)\invoices\[id]\page.tsx",
    "apps\frontend\components\ui\credit-note-dialog.tsx"
)

$outPath = Join-Path $repoRoot "d4-state-export-$timestamp.txt"
$sb = New-Object System.Text.StringBuilder

foreach ($rel in $targets) {
    $full = Join-Path $repoRoot $rel
    [void]$sb.AppendLine("=" * 80)
    [void]$sb.AppendLine("FILE: $rel")
    [void]$sb.AppendLine("=" * 80)
    if (Test-Path -LiteralPath $full) {
        $content = [System.IO.File]::ReadAllText($full)
        [void]$sb.AppendLine($content)
    } else {
        [void]$sb.AppendLine("*** FILE NOT FOUND ***")
    }
    [void]$sb.AppendLine("")
}

[System.IO.File]::WriteAllText($outPath, $sb.ToString())
Write-Host "Wrote: $outPath" -ForegroundColor Green
Write-Host "Open this file, copy its full contents, and paste it back to me." -ForegroundColor Cyan