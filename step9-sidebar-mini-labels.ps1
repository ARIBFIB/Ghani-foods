<#
  Step 9 — Sidebar mini-labels (spec v2.2 section 4.1)
  ------------------------------------------------------------------
  Gap found: IconNavigation (the 76px icon rail) already shows an
  always-visible mini text label under each icon - that part is fine.

  The real gap is in DetailSidebar -> MenuItem: when the expanded
  sidebar is toggled to its "collapsed" state (the chevron button),
  MenuItem hides its label completely (opacity-0 w-0), leaving
  icon-only buttons with NO text at all. Spec requires that no state
  of the sidebar be icon-only-with-no-text.

  Fix: add a small 8px mini-label under the icon in MenuItem,
  visible only when isCollapsed is true (mirroring the pattern
  already used in IconNavButton).

  Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#>

$ErrorActionPreference = "Stop"

$root = Get-Location
$sidebarPath = Join-Path $root "apps\frontend\components\ui\sidebar-component.tsx"

if (-not (Test-Path $sidebarPath)) {
    Write-Host "ERROR: Could not find $sidebarPath" -ForegroundColor Red
    Write-Host "Make sure you are running this from the GhaniFoods root folder." -ForegroundColor Red
    exit 1
}

function Write-Utf8NoBom($path, $content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $enc)
}

function Backup-File($path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $bak = "$path.bak-step9-$stamp"
    Copy-Item -Path $path -Destination $bak -Force
    Write-Host "Backed up: $bak" -ForegroundColor DarkGray
}

Backup-File $sidebarPath
$src = [System.IO.File]::ReadAllText($sidebarPath)
$original = $src

# ---------------------------------------------------------------------------
# Patch MenuItem: add a mini text label under the icon when isCollapsed.
# ---------------------------------------------------------------------------
$oldMenuItemContent = @'
    <div
      className={`rounded-lg cursor-pointer transition-all duration-500 flex items-center relative ${
        isActive ? "bg-[var(--surface-hover)]" : "hover:bg-[var(--surface-hover)]"
      } ${isCollapsed ? "w-10 min-w-10 h-10 justify-center p-4" : "w-full h-10 px-4 py-2"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      title={isCollapsed ? item.label : undefined}
    >
      <div className="flex items-center justify-center shrink-0">{item.icon}</div>
      <div
        className={`flex-1 relative transition-opacity duration-500 overflow-hidden ${isCollapsed ? "opacity-0 w-0" : "opacity-100 ml-3"}`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div className="text-[14px] text-[var(--foreground)] leading-[20px] truncate">{item.label}</div>
      </div>
    </div>
'@

$newMenuItemContent = @'
    <div
      className={`rounded-lg cursor-pointer transition-all duration-500 flex relative ${
        isActive ? "bg-[var(--surface-hover)]" : "hover:bg-[var(--surface-hover)]"
      } ${isCollapsed ? "w-14 min-w-14 h-12 flex-col items-center justify-center gap-0.5 px-1 py-1" : "w-full h-10 items-center px-4 py-2"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      title={isCollapsed ? item.label : undefined}
    >
      <div className="flex items-center justify-center shrink-0">{item.icon}</div>
      {isCollapsed ? (
        <span className="text-[8px] leading-none text-center px-0.5 text-[var(--foreground)] truncate max-w-14">
          {item.label}
        </span>
      ) : (
        <div
          className="flex-1 relative transition-opacity duration-500 overflow-hidden opacity-100 ml-3"
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          <div className="text-[14px] text-[var(--foreground)] leading-[20px] truncate">{item.label}</div>
        </div>
      )}
    </div>
'@

if ($src.Contains($oldMenuItemContent)) {
    $src = $src.Replace($oldMenuItemContent, $newMenuItemContent)
} else {
    $marker = "text-[8px] leading-none text-center px-0.5 text-[var(--foreground)] truncate max-w-14"
    if ($src.Contains($marker)) {
        Write-Host "MenuItem mini-label already present - skipping." -ForegroundColor DarkGray
    } else {
        Write-Host "WARNING: MenuItem block pattern not found - file may already differ from expected shape." -ForegroundColor Yellow
        Write-Host "No changes made to MenuItem. Please diff manually if needed." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Also widen the collapsed rail slightly so the 2-line icon+label button
# (w-14 h-12, matching IconNavButton) is not cramped at lg:w-16.
# ---------------------------------------------------------------------------
$oldCollapsedWidth = '${isCollapsed ? "lg:w-16 lg:min-w-16 lg:!px-0 lg:justify-center" : "lg:w-72"}'
$newCollapsedWidth = '${isCollapsed ? "lg:w-20 lg:min-w-20 lg:!px-0 lg:justify-center" : "lg:w-72"}'

if ($src.Contains($oldCollapsedWidth)) {
    $src = $src.Replace($oldCollapsedWidth, $newCollapsedWidth)
} else {
    Write-Host "Collapsed-width class not found in expected shape - skipping that tweak (non-critical)." -ForegroundColor DarkGray
}

if ($src -eq $original) {
    Write-Host "Skipped (already applied or pattern not found): $sidebarPath" -ForegroundColor DarkGray
} else {
    Write-Utf8NoBom $sidebarPath $src
    Write-Host "Updated: $sidebarPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 9 complete." -ForegroundColor Cyan
Write-Host "  - IconNavigation (76px rail): already had always-visible mini-labels, no change needed." -ForegroundColor Cyan
Write-Host "  - DetailSidebar/MenuItem: now shows an 8px mini-label under the icon when the expanded sidebar is collapsed." -ForegroundColor Cyan
Write-Host "  - Collapsed rail width bumped from w-16 to w-20 to fit the two-line icon+label button." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: cd apps\frontend, run npm run dev, then click the sidebar collapse chevron and verify labels remain visible." -ForegroundColor Yellow