# export-code.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\export-code.ps1
#
# Generates code-export.txt with ALL project code every time you run it.
# After running, upload code-export.txt as a FILE ATTACHMENT in the chat
# (do not copy-paste its text - large pastes get truncated).
#
# v3: Fixes NUL-byte corruption caused by mixed file encodings (some files
# saved as UTF-16 get misread as UTF-8 and vice versa). Each file is now
# read with auto encoding detection, and any leftover NUL/control chars
# are stripped as a safety net.

$ProjectRoot = Get-Location
$OutputFile  = Join-Path $ProjectRoot "code-export.txt"

# Folders/paths to completely skip
$ExcludeDirs = @(
    "node_modules",
    ".next",
    ".git",
    ".vercel",
    "dist",
    "build",
    "coverage",
    ".turbo"
)

# File extensions considered "code" (edit as needed)
$IncludeExtensions = @(
    ".ts", ".tsx", ".js", ".jsx",
    ".json", ".css", ".mjs", ".cjs",
    ".md", ".ps1", ".env.example"
)

# Specific filenames to always exclude even if extension matches
$ExcludeFiles = @(
    "package-lock.json",
    "yarn.lock",
    "pnpm-lock.yaml",
    "code-export.txt"
)

Write-Host "=== Exporting GhaniFoods Code ===" -ForegroundColor Cyan

# Build exclude-dir regex pattern (matches any path containing \<dir>\ )
$excludePattern = ($ExcludeDirs | ForEach-Object { [Regex]::Escape("\$_\") }) -join "|"

$files = Get-ChildItem -Path $ProjectRoot -Recurse -File | Where-Object {
    $relativePath = $_.FullName.Substring($ProjectRoot.Path.Length)
    $extOk   = $IncludeExtensions -contains $_.Extension.ToLower()
    $notExcludedDir  = -not ($relativePath -match $excludePattern)
    $notExcludedFile = -not ($ExcludeFiles -contains $_.Name)
    $extOk -and $notExcludedDir -and $notExcludedFile
}

Write-Host "Found $($files.Count) files to export." -ForegroundColor Yellow

if (Test-Path $OutputFile) {
    Remove-Item $OutputFile -Force
}

$builder = New-Object System.Text.StringBuilder

$header = @"
==================================================
GhaniFoods - Full Code Export
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Total Files: $($files.Count)
==================================================

"@
[void]$builder.Append($header)

# Reads a file with automatic encoding detection (handles UTF-8, UTF-8 BOM,
# UTF-16 LE/BE, etc.) so mixed-encoding files don't produce NUL bytes.
function Read-FileSmart($path) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        if ($bytes.Length -eq 0) { return "" }

        # StreamReader with detectEncodingFromByteOrderMarks=$true auto-detects
        # BOM-based encodings; defaultEncoding fallback is UTF8.
        $stream = New-Object System.IO.MemoryStream(,$bytes)
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
        $text = $reader.ReadToEnd()
        $reader.Close()

        # Safety net: strip any stray NUL characters that slipped through
        $text = $text -replace "`0", ""
        return $text
    }
    catch {
        return "[Could not read file: $($_.Exception.Message)]"
    }
}

$count = 0
foreach ($file in $files) {
    $count++
    $relativePath = $file.FullName.Substring($ProjectRoot.Path.Length).TrimStart('\')

    Write-Host "  [$count/$($files.Count)] $relativePath" -ForegroundColor Gray

    $separator = @"

==================================================
FILE: $relativePath
==================================================

"@
    [void]$builder.Append($separator)

    $fileContent = Read-FileSmart $file.FullName
    [void]$builder.Append($fileContent)
}

# Write as UTF8 without BOM, single pass (avoids truncation issues from repeated Add-Content calls)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputFile, $builder.ToString(), $utf8NoBom)

Write-Host "`n=== Export complete ===" -ForegroundColor Green
Write-Host "Output: $OutputFile" -ForegroundColor Green
Write-Host "Total files exported: $count" -ForegroundColor Green
Write-Host "Total size: $([Math]::Round((Get-Item $OutputFile).Length / 1KB, 1)) KB" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEP: Upload code-export.txt as a FILE ATTACHMENT in the chat." -ForegroundColor Yellow
Write-Host "Do not copy-paste its contents as text - large pastes get truncated." -ForegroundColor Yellow