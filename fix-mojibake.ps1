# fix-mojibake.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\fix-mojibake.ps1
#
# Fixes two known issues across apps/frontend:
#   1. "â€"" mojibake (corrupted em-dash) -> proper "—"
#   2. Leftover broken class "text-[var(--foreground)]0" -> "text-[var(--text-faint)]"
#
# Safe to re-run - if nothing matches, files are left untouched (no rewrite).

$FrontendRoot = Join-Path (Get-Location) "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: Could not find apps\frontend under $(Get-Location)" -ForegroundColor Red
    Write-Host "Make sure you run this script from the GhaniFoods project root." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Fixing mojibake + broken classes in apps/frontend ===" -ForegroundColor Cyan

$ExcludeDirs = @("node_modules", ".next", ".git", ".vercel", "dist", "build")
$excludePattern = ($ExcludeDirs | ForEach-Object { [Regex]::Escape("\$_\") }) -join "|"

$files = Get-ChildItem -Path $FrontendRoot -Recurse -File -Include *.ts,*.tsx | Where-Object {
    $relativePath = $_.FullName.Substring($FrontendRoot.Length)
    -not ($relativePath -match $excludePattern)
}

Write-Host "Scanning $($files.Count) .ts/.tsx files..." -ForegroundColor Yellow

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$changedCount = 0

foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -eq 0) { continue }

    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
    $original = $reader.ReadToEnd()
    $reader.Close()

    $updated = $original

    # 1. Mojibake em-dash: "â€"" (and common variants) -> proper em dash "—"
    $updated = $updated -replace [char]0x00E2 + [char]0x20AC + [char]0x201D, [string][char]0x2014
    $updated = $updated -replace [char]0x00E2 + [char]0x20AC + [char]0x0022, [string][char]0x2014
    $updated = $updated -replace [char]0x00E2 + [char]0x20AC + [char]0x2019, "'"      # mojibake right single quote
    $updated = $updated -replace [char]0x00E2 + [char]0x20AC + [char]0x0153, [string][char]0x201C  # mojibake left double quote
    $updated = $updated -replace [char]0x00E2 + [char]0x20AC + [char]0x009D, [string][char]0x201D  # mojibake right double quote

    # 2. Broken leftover class -> correct muted/faint text class
    $updated = $updated -replace "text-\[var\(--foreground\)\]0", "text-[var(--text-faint)]"

    if ($updated -ne $original) {
        [System.IO.File]::WriteAllText($file.FullName, $updated, $utf8NoBom)
        $relPath = $file.FullName.Substring($FrontendRoot.Length).TrimStart('\')
        Write-Host "  Fixed: $relPath" -ForegroundColor Green
        $changedCount++
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Files changed: $changedCount" -ForegroundColor Green
Write-Host "Please review the diffs (git diff) before committing." -ForegroundColor Yellow