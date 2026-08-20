#
# fix-backend-settings-readonly.ps1
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes: apps/backend/src/index.ts
#
#   TypeScript error TS2540: Cannot assign to 'settings' because it is a
#   read-only property.
#
#   Cause: `import * as data from "./data"` creates a read-only namespace
#   object in TypeScript/ESM - you cannot reassign a named export through
#   it (data.settings = ...), even if data.ts declares `export let settings`.
#
#   Fix: mutate the settings object's properties instead of reassigning the
#   whole binding: Object.assign(data.settings, req.body) instead of
#   data.settings = { ...data.settings, ...req.body }.
#
# Safe to re-run - already-applied file is skipped.
# Backup made before edit: <file>.bak-<timestamp>
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
}

$indexPath = Join-Path $root "apps\backend\src\index.ts"

if (-not (Test-Path -LiteralPath $indexPath)) {
    Write-Host "ERROR: Could not find $indexPath" -ForegroundColor Red
    exit 1
}

$content = Get-Content -Raw -LiteralPath $indexPath

$oldLine = "data.settings = { ...data.settings, ...req.body };"
$newLine = "Object.assign(data.settings, req.body);"

if ($content.Contains($newLine)) {
    Write-Host "index.ts already fixed - skipping." -ForegroundColor Yellow
    exit 0
}

if (-not $content.Contains($oldLine)) {
    Write-Host "ERROR: Could not find the offending line - it may already differ. Aborting without changes." -ForegroundColor Red
    exit 1
}

Backup-File $indexPath

$content = $content.Replace($oldLine, $newLine)
Set-Content -LiteralPath $indexPath -Value $content -NoNewline

Write-Host ""
Write-Host "Done. index.ts patched:" -ForegroundColor Green
Write-Host "  data.settings = { ...data.settings, ...req.body };" -ForegroundColor DarkGray
Write-Host "  -> Object.assign(data.settings, req.body);" -ForegroundColor Green
Write-Host ""
Write-Host "Now run: npm run build   to verify." -ForegroundColor Cyan