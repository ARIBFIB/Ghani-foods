# fix-sidebar-collapse.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\fix-sidebar-collapse.ps1
#
# Fixes sidebar collapse UI breaking (overlapping columns, BrandBadge
# and MobileSectionNav not hiding properly when collapsed).

$ErrorActionPreference = "Stop"

$sidebarPath = Join-Path (Get-Location) "apps\frontend\components\ui\sidebar-component.tsx"

if (-not (Test-Path $sidebarPath)) {
    Write-Host "ERROR: Could not find $sidebarPath" -ForegroundColor Red
    Write-Host "Make sure you're running this from the GhaniFoods root folder." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Fixing sidebar collapse behavior ===" -ForegroundColor Cyan

$content = Get-Content -Path $sidebarPath -Raw -Encoding UTF8
$original = $content
$changesMade = 0

# ---------------------------------------------------------------------
# 1. BrandBadge -> only render when NOT collapsed
# ---------------------------------------------------------------------
if ($content -match '(?<!\{!isCollapsed && )\<BrandBadge \/\>') {
    $content = $content -replace '(?<!\{!isCollapsed && )\<BrandBadge \/\>', '{!isCollapsed && <BrandBadge />}'
    $changesMade++
    Write-Host "[1/3] BrandBadge -> wrapped with {!isCollapsed && ...}" -ForegroundColor Green
} else {
    Write-Host "[1/3] BrandBadge already conditional or not found - skipped" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
# 2. MobileSectionNav -> only render when NOT collapsed
# ---------------------------------------------------------------------
if ($content -match '(?<!\{!isCollapsed && )\<MobileSectionNav activeSection=\{activeSection\} \/\>') {
    $content = $content -replace '(?<!\{!isCollapsed && )\<MobileSectionNav activeSection=\{activeSection\} \/\>', '{!isCollapsed && <MobileSectionNav activeSection={activeSection} />}'
    $changesMade++
    Write-Host "[2/3] MobileSectionNav -> wrapped with {!isCollapsed && ...}" -ForegroundColor Green
} else {
    Write-Host "[2/3] MobileSectionNav already conditional or not found - skipped" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
# 3. <aside> in DetailSidebar -> add overflow-hidden so collapse
#    transition clips content instead of overlapping columns.
#    Target the multi-line className block that contains 'lg:w-72'
# ---------------------------------------------------------------------
if ($content -match 'fixed inset-y-0 left-0 z-50 w-72 max-w\[85vw\] overflow-y-auto') {
    $content = $content -replace `
        'fixed inset-y-0 left-0 z-50 w-72 max-w\[85vw\] overflow-y-auto', `
        'fixed inset-y-0 left-0 z-50 w-72 max-w-[85vw] overflow-y-auto overflow-x-hidden'
    $changesMade++
    Write-Host "[3/3] <aside> -> added overflow-x-hidden to prevent overlap during transition" -ForegroundColor Green
} else {
    Write-Host "[3/3] <aside> overflow pattern not found - skipped (check manually)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
# Write back if anything changed
# ---------------------------------------------------------------------
if ($changesMade -eq 0) {
    Write-Host "`nNo changes were applied - patterns may already be fixed, or file structure differs." -ForegroundColor Yellow
    Write-Host "Please share the current file content if this looks wrong." -ForegroundColor Yellow
} else {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($sidebarPath, $content, $utf8NoBom)
    Write-Host "`nPatched: $sidebarPath ($changesMade change(s) applied)" -ForegroundColor Green
}

Write-Host "`n=== Verifying ===" -ForegroundColor Cyan
$check = Get-Content -Path $sidebarPath -Raw -Encoding UTF8

if ($check -match '\{!isCollapsed && <BrandBadge') {
    Write-Host "OK: BrandBadge is conditional." -ForegroundColor Green
} else {
    Write-Host "WARNING: BrandBadge conditional not confirmed - check manually." -ForegroundColor Red
}

if ($check -match '\{!isCollapsed && <MobileSectionNav') {
    Write-Host "OK: MobileSectionNav is conditional." -ForegroundColor Green
} else {
    Write-Host "WARNING: MobileSectionNav conditional not confirmed - check manually." -ForegroundColor Red
}

if ($check -match 'overflow-x-hidden') {
    Write-Host "OK: overflow-x-hidden added to sidebar container." -ForegroundColor Green
} else {
    Write-Host "WARNING: overflow-x-hidden not confirmed - check manually." -ForegroundColor Red
}

Write-Host "`nDone. Now run:" -ForegroundColor Cyan
Write-Host "  npm run dev:frontend" -ForegroundColor White
Write-Host "and test the sidebar collapse button (desktop, lg breakpoint and up)." -ForegroundColor White
Write-Host "If build passes locally, commit + push to trigger Vercel deploy." -ForegroundColor White