# fix-package-json-bom.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-package-json-bom.ps1
#
# Fixes the Vercel build error:
#   "Could not read /vercel/path0/apps/frontend/package.json: Unexpected
#    token '\ufeff', '\ufeff{ "na"... is not valid JSON."
#
# Root cause: an earlier script wrote package.json with
#   Set-Content -Encoding UTF8
# which in Windows PowerShell adds a UTF-8 BOM at the start of the file.
# A BOM is invalid at the start of a JSON file, so Vercel's JSON parser
# (and npm/node's JSON.parse) rejects it.
#
# This script rewrites apps\frontend\package.json (and, as a safety net,
# the root package.json and apps\backend\package.json too) as clean
# UTF-8 WITHOUT BOM.

$ErrorActionPreference = "Stop"
$Root = Get-Location

$targets = @(
    (Join-Path $Root "package.json"),
    (Join-Path $Root "apps\frontend\package.json"),
    (Join-Path $Root "apps\backend\package.json")
)

Write-Host "=== Fixing package.json BOM issue ===" -ForegroundColor Cyan

$fixedCount = 0

foreach ($path in $targets) {
    if (-not (Test-Path $path)) {
        Write-Host "  Skipped (not found): $path" -ForegroundColor Gray
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

    # Read text (StreamReader with BOM detection strips the BOM automatically)
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

    # Validate it's actually parseable JSON before rewriting
    try {
        $null = $text | ConvertFrom-Json
    } catch {
        Write-Host "  ERROR: $path does not contain valid JSON even after stripping BOM." -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    # Rewrite as UTF-8 WITHOUT BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)

    $relPath = $path.Substring($Root.Path.Length).TrimStart('\')
    if ($hasBom) {
        Write-Host "  Fixed (had BOM): $relPath" -ForegroundColor Green
        $fixedCount++
    } else {
        Write-Host "  OK (no BOM found, rewritten clean anyway): $relPath" -ForegroundColor Gray
    }
}

Write-Host ""
if ($fixedCount -gt 0) {
    Write-Host "$fixedCount file(s) had a BOM and were fixed." -ForegroundColor Green
} else {
    Write-Host "No BOM found in any target file (issue may be elsewhere)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify locally:  cd apps\frontend && npm install" -ForegroundColor Gray
Write-Host "  2. Commit + push:" -ForegroundColor Gray
Write-Host "       git add -A" -ForegroundColor Gray
Write-Host "       git commit -m `"fix: remove BOM from package.json files`"" -ForegroundColor Gray
Write-Host "       git push origin main" -ForegroundColor Gray
Write-Host "  3. Vercel will auto-redeploy on push." -ForegroundColor Gray