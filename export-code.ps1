# ============================================================
# export-code.ps1
# ============================================================
#
# GhaniFoods - JSON + ZIP Code Export
#
# Run from:
# D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Usage:
#   .\export-code.ps1
#
# Generates:
#   1. code-export.json
#   2. code-export.zip
#
# ZIP contains:
#   code-export.json
#
# ============================================================

$ProjectRoot = (Get-Location).Path

$OutputJson = Join-Path $ProjectRoot "code-export.json"
$OutputZip  = Join-Path $ProjectRoot "code-export.zip"

# ============================================================
# DIRECTORIES TO EXCLUDE
# ============================================================

$ExcludeDirs = @(
    "node_modules",
    ".next",
    ".git",
    ".vercel",
    "dist",
    "build",
    "coverage",
    ".turbo",
    ".cache",
    ".parcel-cache",
    "out",
    "tmp",
    "temp"
)

# ============================================================
# FILE EXTENSIONS TO INCLUDE
# ============================================================

$IncludeExtensions = @(
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".json",
    ".css",
    ".scss",
    ".sass",
    ".less",
    ".mjs",
    ".cjs",
    ".ps1",
    ".env.example"
)

# ============================================================
# FILES TO EXCLUDE
# ============================================================

$ExcludeFiles = @(
    # Dependency lock files
    "package-lock.json",
    "yarn.lock",
    "pnpm-lock.yaml",
    "bun.lockb",

    # Generated export files
    "code-export.json",
    "code-export.zip",

    # Large animation JSON files
    "loading.json",
    "404errorpagewithcat.json",

    # Documentation
    "README.md",

    # Export helper
    "export-code.ps1"
)

# ============================================================
# START
# ============================================================

Write-Host ""
Write-Host "==================================================" -ForegroundColor DarkCyan
Write-Host "      GhaniFoods JSON + ZIP Code Export" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "Project Root:" -ForegroundColor Gray
Write-Host "  $ProjectRoot" -ForegroundColor White
Write-Host ""

# ============================================================
# REMOVE OLD OUTPUT FILES
# ============================================================

if (Test-Path $OutputJson) {

    Write-Host "Removing previous code-export.json..." -ForegroundColor DarkGray

    Remove-Item $OutputJson -Force
}

if (Test-Path $OutputZip) {

    Write-Host "Removing previous code-export.zip..." -ForegroundColor DarkGray

    Remove-Item $OutputZip -Force
}

# ============================================================
# BUILD EXCLUDE REGEX
# ============================================================

$excludePattern = (
    $ExcludeDirs | ForEach-Object {
        [Regex]::Escape("\$_\")
    }
) -join "|"

# ============================================================
# FIND PROJECT FILES
# ============================================================

Write-Host "Scanning project..." -ForegroundColor Yellow

$files = Get-ChildItem `
    -Path $ProjectRoot `
    -Recurse `
    -File `
    -ErrorAction SilentlyContinue |
    Where-Object {

        $relativePath = $_.FullName.Substring(
            $ProjectRoot.Length
        )

        $extension = $_.Extension.ToLower()

        $extOk = $IncludeExtensions -contains $extension

        $notExcludedDir = -not (
            $relativePath -match $excludePattern
        )

        $notExcludedFile = -not (
            $ExcludeFiles -contains $_.Name
        )

        $extOk `
        -and $notExcludedDir `
        -and $notExcludedFile
    } |
    Sort-Object FullName

# ============================================================
# FILE COUNT
# ============================================================

Write-Host ""
Write-Host "Found $($files.Count) files to export." -ForegroundColor Green
Write-Host ""

if ($files.Count -eq 0) {

    Write-Host "ERROR: No files found to export." -ForegroundColor Red
    exit 1
}

# ============================================================
# SMART FILE READER
# ============================================================

function Read-FileSmart {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {

        $bytes = [System.IO.File]::ReadAllBytes($Path)

        if ($bytes.Length -eq 0) {
            return ""
        }

        # Memory stream
        $stream = New-Object System.IO.MemoryStream(, $bytes)

        # UTF-8 with BOM detection
        $reader = New-Object System.IO.StreamReader(
            $stream,
            [System.Text.Encoding]::UTF8,
            $true
        )

        $text = $reader.ReadToEnd()

        $reader.Close()
        $stream.Dispose()

        # Remove NUL characters
        $text = $text -replace "`0", ""

        # Remove invalid control characters
        # Preserve:
        # TAB
        # CR
        # LF
        $text = [regex]::Replace(
            $text,
            "[\x00-\x08\x0B\x0C\x0E-\x1F]",
            ""
        )

        return $text
    }
    catch {

        return "[Could not read file: $($_.Exception.Message)]"
    }
}

# ============================================================
# BUILD FILE OBJECTS
# ============================================================

$fileObjects = New-Object System.Collections.Generic.List[object]

$count = 0
$totalSourceBytes = 0

foreach ($file in $files) {

    $count++

    $relativePath = $file.FullName.Substring(
        $ProjectRoot.Length
    ).TrimStart('\')

    # Portable path format
    $jsonPath = $relativePath.Replace("\", "/")

    Write-Host `
        ("  [{0}/{1}] {2}" -f $count, $files.Count, $relativePath) `
        -ForegroundColor Gray

    $totalSourceBytes += $file.Length

    $content = Read-FileSmart -Path $file.FullName

    $fileObjects.Add(
        [PSCustomObject]@{
            path    = $jsonPath
            content = $content
        }
    )
}

# ============================================================
# CREATE EXPORT OBJECT
# ============================================================

$exportObject = [PSCustomObject]@{
    project    = "GhaniFoods"
    generated  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    totalFiles = $fileObjects.Count
    files      = $fileObjects
}

# ============================================================
# CONVERT TO COMPACT JSON
# ============================================================

Write-Host ""
Write-Host "Creating compact JSON..." -ForegroundColor Yellow

$json = $exportObject | ConvertTo-Json -Depth 20 -Compress

# ============================================================
# WRITE JSON AS UTF-8 WITHOUT BOM
# ============================================================

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {

    [System.IO.File]::WriteAllText(
        $OutputJson,
        $json,
        $utf8NoBom
    )
}
catch {

    Write-Host ""
    Write-Host "ERROR: Could not write JSON file." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ============================================================
# VALIDATE JSON
# ============================================================

Write-Host "Validating JSON..." -ForegroundColor Yellow

try {

    $testJson = [System.IO.File]::ReadAllText(
        $OutputJson,
        [System.Text.Encoding]::UTF8
    )

    $null = $testJson | ConvertFrom-Json

    Write-Host "JSON validation: PASSED" -ForegroundColor Green
}
catch {

    Write-Host "JSON validation: FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ============================================================
# CREATE ZIP
# ============================================================

Write-Host ""
Write-Host "Creating ZIP archive..." -ForegroundColor Yellow

try {

    # Compress-Archive creates:
    #
    # code-export.zip
    #
    # containing:
    #
    # code-export.json

    Compress-Archive `
        -Path $OutputJson `
        -DestinationPath $OutputZip `
        -CompressionLevel Optimal `
        -Force

    Write-Host "ZIP creation: PASSED" -ForegroundColor Green
}
catch {

    Write-Host "ZIP creation: FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ============================================================
# VERIFY ZIP
# ============================================================

Write-Host "Verifying ZIP..." -ForegroundColor Yellow

try {

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::OpenRead($OutputZip)

    $zipEntries = $zip.Entries

    $zipEntryNames = @(
        $zipEntries | ForEach-Object {
            $_.FullName
        }
    )

    $zip.Dispose()

    if ($zipEntryNames -contains "code-export.json") {

        Write-Host "ZIP validation: PASSED" -ForegroundColor Green
    }
    else {

        Write-Host "ZIP validation: FAILED" -ForegroundColor Red
        Write-Host "code-export.json was not found inside ZIP." -ForegroundColor Red
        exit 1
    }
}
catch {

    Write-Host "ZIP validation: FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ============================================================
# SIZE INFORMATION
# ============================================================

$jsonInfo = Get-Item $OutputJson
$zipInfo  = Get-Item $OutputZip

$jsonBytes = $jsonInfo.Length
$zipBytes  = $zipInfo.Length

$sourceKB = [Math]::Round(
    $totalSourceBytes / 1KB,
    1
)

$jsonKB = [Math]::Round(
    $jsonBytes / 1KB,
    1
)

$jsonMB = [Math]::Round(
    $jsonBytes / 1MB,
    2
)

$zipKB = [Math]::Round(
    $zipBytes / 1KB,
    1
)

$zipMB = [Math]::Round(
    $zipBytes / 1MB,
    2
)

if ($jsonBytes -gt 0) {

    $zipReduction = [Math]::Round(
        (1 - ($zipBytes / $jsonBytes)) * 100,
        1
    )
}
else {

    $zipReduction = 0
}

# ============================================================
# FINAL RESULT
# ============================================================

Write-Host ""
Write-Host "==================================================" -ForegroundColor DarkGreen
Write-Host "              EXPORT COMPLETE" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor DarkGreen
Write-Host ""

Write-Host "JSON File:" -ForegroundColor Gray
Write-Host "  $OutputJson" -ForegroundColor White

Write-Host ""
Write-Host "JSON Size:" -ForegroundColor Gray
Write-Host "  $jsonKB KB ($jsonMB MB)" -ForegroundColor White

Write-Host ""

Write-Host "ZIP File:" -ForegroundColor Gray
Write-Host "  $OutputZip" -ForegroundColor White

Write-Host ""
Write-Host "ZIP Size:" -ForegroundColor Gray
Write-Host "  $zipKB KB ($zipMB MB)" -ForegroundColor Green

Write-Host ""

Write-Host "ZIP Compression Reduction:" -ForegroundColor Gray
Write-Host "  $zipReduction%" -ForegroundColor Green

Write-Host ""

Write-Host "Total Files:" -ForegroundColor Gray
Write-Host "  $($fileObjects.Count)" -ForegroundColor White

Write-Host ""

Write-Host "JSON Validation:" -ForegroundColor Gray
Write-Host "  PASSED" -ForegroundColor Green

Write-Host ""

Write-Host "ZIP Validation:" -ForegroundColor Gray
Write-Host "  PASSED" -ForegroundColor Green

Write-Host ""
Write-Host "==================================================" -ForegroundColor DarkCyan
Write-Host "FILES GENERATED" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  1. code-export.json" -ForegroundColor White
Write-Host "  2. code-export.zip" -ForegroundColor White
Write-Host ""
Write-Host "The ZIP contains code-export.json." -ForegroundColor Gray
Write-Host ""
Write-Host "For upload, prefer code-export.zip because it is" -ForegroundColor Yellow
Write-Host "normally much smaller than the JSON file." -ForegroundColor Yellow
Write-Host ""