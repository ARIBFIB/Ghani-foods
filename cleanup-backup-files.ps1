<#
  cleanup-backup-files.ps1
  --------------------------
  Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  The repo has accumulated a lot of manual backup clutter from earlier
  step-by-step edits:
    - *.bak, *.bak2, *.bak-stepNN-<timestamp>, *.bak-<timestamp>
    - the whole apps/frontend/lib/mock-data.removed-<timestamp>/ folder
      (old mock data, superseded now that the store is fully live)
    - the .bak-<timestamp> files the two fix scripts you already ran
      created (topbar.tsx, invoices/new, and the 6 error-handling forms)

  This script does NOT delete anything permanently. It MOVES every match
  into a single folder:  _archived-backups-<timestamp>\
  at the repo root, preserving the original relative paths, so you can
  review it, zip it, or delete it yourself once you're confident nothing
  is needed.

  Run with -WhatIf first to just see what would move, with no changes:
      .\cleanup-backup-files.ps1 -WhatIf

  Then run for real:
      .\cleanup-backup-files.ps1
#>

param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$archiveRoot = Join-Path $root "_archived-backups-$stamp"

Write-Host "Running in: $root" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "DRY RUN - nothing will be moved." -ForegroundColor Yellow
}

# Patterns that identify backup/removed clutter, not real source files.
$patterns = @(
    '*.bak',
    '*.bak2',
    '*.bak-*',
    '*.step*.bak',
    '*.removed-*'
)

# Directories we should never touch even if a name happens to match.
$excludeDirs = @('node_modules', '.git', '.next', 'dist')

function Test-Excluded {
    param([string]$FullPath)
    foreach ($ex in $excludeDirs) {
        if ($FullPath -match [regex]::Escape("\$ex\")) { return $true }
    }
    return $false
}

# Collect matching files
$matches = @()
foreach ($pattern in $patterns) {
    $found = Get-ChildItem -LiteralPath $root -Recurse -Force -File -Filter $pattern -ErrorAction SilentlyContinue
    $matches += $found
}

# Collect the mock-data.removed-* directory (and any similarly named dirs) as whole trees
$removedDirs = Get-ChildItem -LiteralPath $root -Recurse -Force -Directory -Filter '*.removed-*' -ErrorAction SilentlyContinue

$matches = $matches | Where-Object { -not (Test-Excluded $_.FullName) } | Sort-Object FullName -Unique
$removedDirs = $removedDirs | Where-Object { -not (Test-Excluded $_.FullName) }

if ($matches.Count -eq 0 -and $removedDirs.Count -eq 0) {
    Write-Host "No backup clutter found. Nothing to do." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Found $($matches.Count) backup file(s) and $($removedDirs.Count) removed-data folder(s):" -ForegroundColor Cyan
foreach ($m in $matches) { Write-Host "  file: $($m.FullName.Substring($root.Path.Length + 1))" }
foreach ($d in $removedDirs) { Write-Host "  dir:  $($d.FullName.Substring($root.Path.Length + 1))\ (entire folder)" }

if ($WhatIf) {
    Write-Host ""
    Write-Host "Dry run only - re-run without -WhatIf to actually move these into $archiveRoot" -ForegroundColor Yellow
    exit 0
}

New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
Write-Host ""
Write-Host "Archiving into: $archiveRoot" -ForegroundColor Cyan

foreach ($m in $matches) {
    $relative = $m.FullName.Substring($root.Path.Length + 1)
    $dest = Join-Path $archiveRoot $relative
    New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
    Move-Item -LiteralPath $m.FullName -Destination $dest -Force
}

foreach ($d in $removedDirs) {
    $relative = $d.FullName.Substring($root.Path.Length + 1)
    $dest = Join-Path $archiveRoot $relative
    New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
    Move-Item -LiteralPath $d.FullName -Destination $dest -Force
}

Write-Host ""
Write-Host "Done. All clutter moved to: $archiveRoot" -ForegroundColor Green
Write-Host "Review it, then delete the folder yourself once confident:" -ForegroundColor Cyan
Write-Host "  Remove-Item -LiteralPath '$archiveRoot' -Recurse -Force"
Write-Host ""
Write-Host "Tip: going forward, use 'git' for version history instead of manual .bak files -" -ForegroundColor Cyan
Write-Host "  git add -A; git commit -m 'checkpoint before change X'"
Write-Host "gives you the same safety net without cluttering the working tree."