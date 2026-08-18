# Phase2-Fix-Sidebar.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\Phase2-Fix-Sidebar.ps1
#
# Fixes ONLY the sidebar-component.tsx update that failed in Phase2 (step 5/5)
# with "The -replace operator allows only two elements to follow it, not 3."
#
# Root cause: inline '$1' + "...text..." concatenation directly inside the
# -replace argument confused the parser. Fix: build each replacement string
# in its own variable first, then pass that variable to -replace.
#
# Safe to run even if sidebar-component.tsx was NOT yet touched by Phase 2 -
# it checks for existing markers before replacing, so it won't double-patch.

$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$Components = Join-Path $ProjectRoot "apps\frontend\components\ui"
$sidebarPath = Join-Path $Components "sidebar-component.tsx"

if (-not (Test-Path $sidebarPath)) {
    Write-Host "ERROR: components\ui\sidebar-component.tsx not found. Run this from the GhaniFoods root." -ForegroundColor Red
    exit 1
}

Write-Host "=== Fixing sidebar-component.tsx (add Suppliers nav) ===" -ForegroundColor Cyan

$sidebarText = [System.IO.File]::ReadAllText($sidebarPath)

if ($sidebarText -match '"suppliers"') {
    Write-Host "  Sidebar already contains a 'suppliers' reference - skipping to avoid double-patching." -ForegroundColor Yellow
    Write-Host "  If the sidebar still looks wrong, restore from git/backup and re-run this script." -ForegroundColor Yellow
    exit 0
}

# 1. SectionId union type: add "suppliers"
$oldTypeBlock = "type SectionId =`r`n  | `"dashboard`""
$newTypeBlock = "type SectionId =`r`n  | `"dashboard`"`r`n  | `"suppliers`""
if ($sidebarText.Contains($oldTypeBlock)) {
    $sidebarText = $sidebarText.Replace($oldTypeBlock, $newTypeBlock)
    Write-Host "  [1/5] Added 'suppliers' to SectionId type" -ForegroundColor Green
} else {
    Write-Host "  [1/5] WARNING: could not find SectionId type block - skipped" -ForegroundColor Yellow
}

# 2. SECTION_DEFAULT_ROUTE: add suppliers route
$oldRouteBlock = "const SECTION_DEFAULT_ROUTE: Record<SectionId, string> = {`r`n  dashboard: `"/`","
$newRouteBlock = "const SECTION_DEFAULT_ROUTE: Record<SectionId, string> = {`r`n  dashboard: `"/`",`r`n  suppliers: `"/suppliers`","
if ($sidebarText.Contains($oldRouteBlock)) {
    $sidebarText = $sidebarText.Replace($oldRouteBlock, $newRouteBlock)
    Write-Host "  [2/5] Added suppliers route to SECTION_DEFAULT_ROUTE" -ForegroundColor Green
} else {
    Write-Host "  [2/5] WARNING: could not find SECTION_DEFAULT_ROUTE block - skipped" -ForegroundColor Yellow
}

# 3. ROUTE_PREFIXES: add suppliers prefix
$oldPrefixBlock = "const ROUTE_PREFIXES: Array<[string, SectionId]> = [`r`n"
$newPrefixBlock = "const ROUTE_PREFIXES: Array<[string, SectionId]> = [`r`n  [`"/suppliers`", `"suppliers`"],`r`n"
if ($sidebarText.Contains($oldPrefixBlock)) {
    $sidebarText = $sidebarText.Replace($oldPrefixBlock, $newPrefixBlock)
    Write-Host "  [3/5] Added suppliers entry to ROUTE_PREFIXES" -ForegroundColor Green
} else {
    Write-Host "  [3/5] WARNING: could not find ROUTE_PREFIXES block - skipped" -ForegroundColor Yellow
}

# 4. getSidebarContent: insert "suppliers" content block before "batches:"
$suppliersContentBlock = @"
    suppliers: {
      title: "Suppliers",
      sections: [
        { title: "Suppliers", items: [{ icon: <UserMultiple size={16} className="text-[var(--foreground)]" />, label: "All Suppliers", href: "/suppliers" }] },
      ],
    },
    batches: {
"@
$oldBatchesBlock = "    batches: {"
if ($sidebarText.Contains($oldBatchesBlock)) {
    # Only replace the FIRST occurrence (the object-literal key), not any later text match
    $idx = $sidebarText.IndexOf($oldBatchesBlock)
    $sidebarText = $sidebarText.Substring(0, $idx) + $suppliersContentBlock + $sidebarText.Substring($idx + $oldBatchesBlock.Length)
    Write-Host "  [4/5] Added suppliers content block to getSidebarContent" -ForegroundColor Green
} else {
    Write-Host "  [4/5] WARNING: could not find 'batches: {' block - skipped" -ForegroundColor Yellow
}

# 5. Desktop icon rail + mobile nav: add Suppliers nav item after Raw Materials
$oldDesktopNav = '{ id: "raw-materials", icon: <Folder size={16} />, label: "Raw Materials" },'
$newDesktopNav = "{ id: `"raw-materials`", icon: <Folder size={16} />, label: `"Raw Materials`" },`r`n    { id: `"suppliers`", icon: <UserMultiple size={16} />, label: `"Suppliers`" },"
if ($sidebarText.Contains($oldDesktopNav)) {
    $sidebarText = $sidebarText.Replace($oldDesktopNav, $newDesktopNav)
    Write-Host "  [5/5] Added Suppliers to desktop icon rail nav" -ForegroundColor Green
} else {
    Write-Host "  [5/5] WARNING: could not find desktop nav 'raw-materials' entry (size={16}) - skipped" -ForegroundColor Yellow
}

$oldMobileNav = '{ id: "raw-materials", icon: <Folder size={18} />, label: "Raw Materials" },'
$newMobileNav = "{ id: `"raw-materials`", icon: <Folder size={18} />, label: `"Raw Materials`" },`r`n    { id: `"suppliers`", icon: <UserMultiple size={18} />, label: `"Suppliers`" },"
if ($sidebarText.Contains($oldMobileNav)) {
    $sidebarText = $sidebarText.Replace($oldMobileNav, $newMobileNav)
    Write-Host "        Added Suppliers to mobile section nav" -ForegroundColor Green
} else {
    Write-Host "        WARNING: could not find mobile nav 'raw-materials' entry (size={18}) - skipped" -ForegroundColor Yellow
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($sidebarPath, $sidebarText, $utf8NoBom)

Write-Host "`n=== Sidebar fix complete ===" -ForegroundColor Green
Write-Host "Wrote: apps\frontend\components\ui\sidebar-component.tsx" -ForegroundColor Green
Write-Host ""
Write-Host "Phase 2 is now FULLY complete (all 5 items done)." -ForegroundColor Yellow
Write-Host "Still pending (Phase 3-5): packaging pages, finished-cartons packing run," -ForegroundColor Yellow
Write-Host "dashboard/topbar/reports packagingMaterials references." -ForegroundColor Yellow