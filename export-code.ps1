# export-code.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\export-code.ps1

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

$header = @"
==================================================
GhaniFoods - Full Code Export
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Total Files: $($files.Count)
==================================================

"@
Add-Content -Path $OutputFile -Value $header -Encoding UTF8

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
    Add-Content -Path $OutputFile -Value $separator -Encoding UTF8

    try {
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        Add-Content -Path $OutputFile -Value $content -Encoding UTF8
    }
    catch {
        Add-Content -Path $OutputFile -Value "[Could not read file: $($_.Exception.Message)]" -Encoding UTF8
    }
}

Write-Host "`n=== Export complete ===" -ForegroundColor Green
Write-Host "Output: $OutputFile" -ForegroundColor Green
Write-Host "Total files exported: $count" -ForegroundColor Green