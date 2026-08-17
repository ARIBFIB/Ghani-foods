# fix-mobile-sidebar-navigation.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-mobile-sidebar-navigation.ps1
#
# ROOT CAUSE:
#   Desktop uses TWO panels: IconNavigation (icons for all 9 sections -
#   Raw Materials, Batches, Customers, etc.) + DetailSidebar (sub-items
#   for whichever section is currently active). On mobile, IconNavigation
#   is hidden ("hidden lg:flex") and only DetailSidebar renders in the
#   drawer - so there was no way to switch to a different section at all,
#   only to navigate within the current one (e.g. Dashboard).
#
# FIX:
#   Add a "Sections" list at the top of the mobile drawer with all 9
#   section links (Dashboard, Raw Materials, Batches, Finished Cartons,
#   Customers, Invoices, Payments, Reports, Settings). Tapping one
#   navigates there AND updates the sub-items shown below it. Desktop
#   layout is completely unchanged - this list only renders below `lg`.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Adding full section navigation to mobile sidebar drawer ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

$sidebarPath = Join-Path $FrontendRoot "components\ui\sidebar-component.tsx"
if (-not (Test-Path $sidebarPath)) {
    Write-Host "ERROR: sidebar-component.tsx not found." -ForegroundColor Red
    exit 1
}

$sidebar = [System.IO.File]::ReadAllText($sidebarPath, [System.Text.Encoding]::UTF8)

# --------------------------------------------------------------------------
# 1. Add a MobileSectionNav component (renders only below lg) right after
#    the IconNavigation function definition.
# --------------------------------------------------------------------------

$mobileSectionNavFn = @'

function MobileSectionNav({ activeSection }: { activeSection: SectionId }) {
  const router = useRouter();

  const navItems: Array<{ id: SectionId; icon: React.ReactNode; label: string }> = [
    { id: "dashboard", icon: <Dashboard size={18} />, label: "Dashboard" },
    { id: "raw-materials", icon: <Folder size={18} />, label: "Raw Materials" },
    { id: "batches", icon: <Task size={18} />, label: "Batches" },
    { id: "finished-cartons", icon: <Archive size={18} />, label: "Finished Cartons" },
    { id: "customers", icon: <UserMultiple size={18} />, label: "Customers" },
    { id: "invoices", icon: <DocumentAdd size={18} />, label: "Invoices" },
    { id: "payments", icon: <ChartBar size={18} />, label: "Payments" },
    { id: "reports", icon: <Analytics size={18} />, label: "Reports" },
    { id: "settings", icon: <SettingsIcon size={18} />, label: "Settings" },
  ];

  const goTo = (section: SectionId) => router.push(SECTION_DEFAULT_ROUTE[section]);

  return (
    <div className="w-full lg:hidden flex flex-col gap-1">
      <div className="px-2 py-1 text-[14px] text-[var(--text-muted)]">Sections</div>
      <div className="grid grid-cols-1 gap-1">
        {navItems.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => goTo(item.id)}
            className={`flex items-center gap-3 rounded-lg px-4 py-2.5 text-left transition-colors duration-300 ${
              activeSection === item.id
                ? "bg-[var(--surface-hover)] text-[var(--foreground)]"
                : "text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
            }`}
          >
            <span className="shrink-0">{item.icon}</span>
            <span className="text-[14px]">{item.label}</span>
          </button>
        ))}
      </div>
      <div className="h-px w-full bg-[var(--surface-border)] my-2" />
    </div>
  );
}
'@

if ($sidebar -notmatch 'function MobileSectionNav') {
    # Insert right after the IconNavigation function's closing brace + blank line,
    # i.e. right before "function SectionTitle("
    $anchor = 'function SectionTitle({'
    if ($sidebar -notmatch [Regex]::Escape($anchor)) {
        Write-Host "ERROR: could not find insertion anchor (SectionTitle). Aborting to avoid corrupting the file." -ForegroundColor Red
        exit 1
    }
    $sidebar = $sidebar -replace [Regex]::Escape($anchor), "$mobileSectionNavFn`nfunction SectionTitle({"
} else {
    Write-Host "  MobileSectionNav already present - skipping insertion" -ForegroundColor Gray
}

# --------------------------------------------------------------------------
# 2. Render <MobileSectionNav /> inside DetailSidebar, right after
#    BrandBadge + SectionTitle, before the search box.
# --------------------------------------------------------------------------

$oldRenderAnchor = '        <BrandBadge />
        <SectionTitle title={content.title} onToggleCollapse={toggleCollapse} isCollapsed={isCollapsed} />
        <div className="w-full lg:hidden">
          <SearchContainer isCollapsed={false} />
        </div>'

$newRenderAnchor = '        <BrandBadge />
        <MobileSectionNav activeSection={activeSection} />
        <SectionTitle title={content.title} onToggleCollapse={toggleCollapse} isCollapsed={isCollapsed} />
        <div className="w-full lg:hidden">
          <SearchContainer isCollapsed={false} />
        </div>'

if ($sidebar -match [Regex]::Escape($oldRenderAnchor)) {
    $sidebar = $sidebar.Replace($oldRenderAnchor, $newRenderAnchor)
} elseif ($sidebar -notmatch '<MobileSectionNav') {
    Write-Host "WARNING: exact render anchor not found - attempting a looser insertion." -ForegroundColor Yellow
    $sidebar = $sidebar -replace '(<BrandBadge />)', "`$1`n        <MobileSectionNav activeSection={activeSection} />"
}

Write-Utf8NoBom $sidebarPath $sidebar

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  Mobile drawer now shows a 'Sections' list at the top with all" -ForegroundColor Gray
Write-Host "    9 sections (Dashboard, Raw Materials, Batches, Finished" -ForegroundColor Gray
Write-Host "    Cartons, Customers, Invoices, Payments, Reports, Settings)" -ForegroundColor Gray
Write-Host "  Tapping a section navigates there and updates the sub-items" -ForegroundColor Gray
Write-Host "    shown below it (e.g. tap Raw Materials -> see All Raw" -ForegroundColor Gray
Write-Host "    Materials / Packaging Materials sub-links)" -ForegroundColor Gray
Write-Host "  Desktop (lg+) is completely unchanged - this list is mobile-only" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT: restart the dev server:" -ForegroundColor Yellow
Write-Host "  Ctrl+C, then:" -ForegroundColor Yellow
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify: open mobile drawer -> tap 'Raw Materials' under Sections -> should navigate there." -ForegroundColor Cyan