# make-mobile-responsive.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\make-mobile-responsive.ps1
#
# What this does:
#   1. Adds a SidebarProvider (React context) so Topbar can control the
#      sidebar's open/closed state on mobile.
#   2. Sidebar becomes a slide-in drawer below the `lg` breakpoint (fixed,
#      overlay + backdrop), and stays as the normal always-visible rail on
#      desktop (lg:) - no visual change on desktop.
#   3. Topbar gets a hamburger button (mobile only) and shrinks its
#      spacing/labels on small screens so it doesn't overflow.
#   4. Dashboard layout: main content gets responsive padding.
#   5. SortableTable: wrapped so wide tables scroll horizontally on mobile
#      instead of squashing/breaking layout.
#   6. Dialogs across pages: full-width with proper margins on mobile
#      (max-h + overflow-y-auto so they don't get cut off on short screens).
#   7. Multi-column forms (batches/new, invoices/new, reports) already use
#      grid-cols-1 sm:grid-cols-2 - this script normalizes any remaining
#      fixed-width rows (raw material consumption rows, invoice item rows)
#      to stack vertically on mobile.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Making GhaniFoods frontend mobile responsive ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. lib/sidebar-context.tsx - shared open/close state for mobile drawer
# --------------------------------------------------------------------------

$sidebarCtxPath = Join-Path $FrontendRoot "lib\sidebar-context.tsx"
$sidebarCtxContent = @'
"use client";

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { usePathname } from "next/navigation";

type SidebarContextValue = {
  isOpen: boolean;
  open: () => void;
  close: () => void;
  toggle: () => void;
};

const SidebarContext = createContext<SidebarContextValue | null>(null);

export function SidebarProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const pathname = usePathname();

  // Auto-close the mobile drawer whenever the route changes.
  useEffect(() => {
    setIsOpen(false);
  }, [pathname]);

  return (
    <SidebarContext.Provider
      value={{
        isOpen,
        open: () => setIsOpen(true),
        close: () => setIsOpen(false),
        toggle: () => setIsOpen((v) => !v),
      }}
    >
      {children}
    </SidebarContext.Provider>
  );
}

export function useSidebar() {
  const ctx = useContext(SidebarContext);
  if (!ctx) throw new Error("useSidebar must be used within SidebarProvider");
  return ctx;
}
'@
Write-Utf8NoBom $sidebarCtxPath $sidebarCtxContent

# --------------------------------------------------------------------------
# 2. Dashboard layout - wrap in SidebarProvider, responsive main padding
# --------------------------------------------------------------------------

$dashboardLayoutPath = Join-Path $FrontendRoot "app\(dashboard)\layout.tsx"
$dashboardLayoutContent = @'
import type { ReactNode } from "react";
import { AppSidebar } from "@/components/ui/sidebar-component";
import { Topbar } from "@/components/ui/topbar";
import { SidebarProvider } from "@/lib/sidebar-context";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <SidebarProvider>
      <div className="flex min-h-screen bg-[var(--background)]">
        <AppSidebar />
        <div className="flex-1 flex flex-col min-w-0">
          <Topbar />
          <main className="flex-1 p-4 sm:p-6 overflow-y-auto overflow-x-hidden text-[var(--foreground)]">
            {children}
          </main>
        </div>
      </div>
    </SidebarProvider>
  );
}
'@
Write-Utf8NoBom $dashboardLayoutPath $dashboardLayoutContent

# --------------------------------------------------------------------------
# 3. Sidebar - mobile drawer behavior (fixed + overlay below lg, static rail
#    at lg and above). IconNavigation and DetailSidebar are merged into one
#    slide-in panel on mobile since the two-column rail doesn't fit there.
# --------------------------------------------------------------------------

$sidebarPath = Join-Path $FrontendRoot "components\ui\sidebar-component.tsx"
if (-not (Test-Path $sidebarPath)) {
    Write-Host "ERROR: sidebar-component.tsx not found - cannot continue." -ForegroundColor Red
    exit 1
}
$sidebar = [System.IO.File]::ReadAllText($sidebarPath, [System.Text.Encoding]::UTF8)

# Add the sidebar-context import
if ($sidebar -notmatch 'useSidebar') {
    $sidebar = $sidebar -replace '(import \{ GhaniLogo \} from "\./ghani-logo";)', "`$1`nimport { useSidebar } from `"@/lib/sidebar-context`";`nimport { Close as CloseIcon } from `"@carbon/icons-react`";"
}

# IconNavigation: hide on mobile (its role is taken over by the topbar hamburger + drawer), show at lg+
$oldIconNavOpen = '  return (
    <aside className="bg-[var(--background)] flex flex-col gap-2 items-center p-4 w-16 h-screen border-r border-[var(--surface-border)]">'
$newIconNavOpen = '  return (
    <aside className="hidden lg:flex bg-[var(--background)] flex-col gap-2 items-center p-4 w-16 h-screen border-r border-[var(--surface-border)]">'
$sidebar = $sidebar.Replace($oldIconNavOpen, $newIconNavOpen)

# DetailSidebar: becomes a fixed slide-in drawer on mobile, static on lg+
$oldDetailReturn = '  return (
    <aside
      className={`bg-[var(--background)] flex flex-col gap-4 items-start p-4 transition-all duration-500 h-screen border-r border-[var(--surface-border)] ${
        isCollapsed ? "w-16 min-w-16 !px-0 justify-center" : "w-72"
      }`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >'
$newDetailReturn = '  const { isOpen, close } = useSidebar();

  return (
    <>
      {/* Mobile backdrop */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/60 lg:hidden"
          onClick={close}
          aria-hidden="true"
        />
      )}

      <aside
        className={`bg-[var(--background)] flex flex-col gap-4 items-start p-4 transition-all duration-300 h-screen border-r border-[var(--surface-border)]
          fixed inset-y-0 left-0 z-50 w-72 max-w-[85vw]
          ${isOpen ? "translate-x-0" : "-translate-x-full"}
          lg:static lg:z-auto lg:translate-x-0 lg:transition-[width] lg:duration-500
          ${isCollapsed ? "lg:w-16 lg:min-w-16 lg:!px-0 lg:justify-center" : "lg:w-72"}
        `}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <button
          type="button"
          onClick={close}
          aria-label="Close menu"
          className="lg:hidden absolute top-4 right-4 flex items-center justify-center size-8 rounded-lg hover:bg-[var(--surface-hover)] text-[var(--text-muted)]"
        >
          <CloseIcon size={18} />
        </button>'
$sidebar = $sidebar.Replace($oldDetailReturn, $newDetailReturn)

# Close the extra wrapping <> we opened above (DetailSidebar's original closing was just </aside>);
# find the end of DetailSidebar's JSX and close the fragment right after it.
$oldDetailClose = '      {!isCollapsed && (
        <div className="w-full mt-auto pt-2 border-t border-[var(--surface-border)]">
          <div className="flex items-center gap-2 px-2 py-2">
            <AvatarCircle />
            <div className="text-[14px] text-[var(--foreground)]">Owner / Admin</div>
          </div>
        </div>
      )}
    </aside>
  );
}'
$newDetailClose = '      {!isCollapsed && (
        <div className="w-full mt-auto pt-2 border-t border-[var(--surface-border)]">
          <div className="flex items-center gap-2 px-2 py-2">
            <AvatarCircle />
            <div className="text-[14px] text-[var(--foreground)]">Owner / Admin</div>
          </div>
        </div>
      )}
      </aside>
    </>
  );
}'
$sidebar = $sidebar.Replace($oldDetailClose, $newDetailClose)

# AppSidebar wrapper: on mobile only the drawer renders (icon rail is hidden via lg:flex above),
# no structural change needed here since IconNavigation self-hides.

Write-Utf8NoBom $sidebarPath $sidebar

# --------------------------------------------------------------------------
# 4. Topbar - hamburger button (mobile), responsive spacing/labels
# --------------------------------------------------------------------------

$topbarPath = Join-Path $FrontendRoot "components\ui\topbar.tsx"
if (-not (Test-Path $topbarPath)) {
    Write-Host "ERROR: topbar.tsx not found - cannot continue." -ForegroundColor Red
    exit 1
}
$topbar = [System.IO.File]::ReadAllText($topbarPath, [System.Text.Encoding]::UTF8)

if ($topbar -notmatch 'useSidebar') {
    $topbar = $topbar -replace '(import \{ AnimatedThemeToggler \} from "@/components/ui/animated-theme-toggler";)', "`$1`nimport { useSidebar } from `"@/lib/sidebar-context`";`nimport { Menu as MenuIcon } from `"@carbon/icons-react`";"
}

$oldTopbarReturn = 'export function Topbar() {
  return (
    <div className="flex items-center justify-end gap-3 border-b border-[var(--surface-border)] bg-[var(--background)] px-6 py-3 sticky top-0 z-30">
      <Link href="/invoices/new"
        className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
        + New Invoice
      </Link>
      <AnimatedThemeToggler />
      <NotificationBell />
      <UserMenu />
    </div>
  );
}'
$newTopbarReturn = 'export function Topbar() {
  const { toggle } = useSidebar();

  return (
    <div className="flex items-center justify-between lg:justify-end gap-2 sm:gap-3 border-b border-[var(--surface-border)] bg-[var(--background)] px-3 sm:px-6 py-3 sticky top-0 z-30">
      <button
        type="button"
        onClick={toggle}
        aria-label="Open menu"
        className="lg:hidden flex items-center justify-center size-9 rounded-lg hover:bg-[var(--surface-hover)] text-[var(--foreground)] shrink-0"
      >
        <MenuIcon size={20} />
      </button>

      <div className="flex items-center gap-2 sm:gap-3 ml-auto">
        <Link href="/invoices/new"
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-3 sm:px-4 py-2 text-xs sm:text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity whitespace-nowrap">
          <span className="hidden sm:inline">+ New Invoice</span>
          <span className="sm:hidden">+ Invoice</span>
        </Link>
        <AnimatedThemeToggler />
        <NotificationBell />
        <UserMenu />
      </div>
    </div>
  );
}'
$topbar = $topbar.Replace($oldTopbarReturn, $newTopbarReturn)

Write-Utf8NoBom $topbarPath $topbar

# --------------------------------------------------------------------------
# 5. SortableTable - horizontal scroll wrapper so tables don't break layout
#    on narrow screens instead of squashing columns unreadably.
# --------------------------------------------------------------------------

$tablePath = Join-Path $FrontendRoot "components\ui\sortable-table.tsx"
if (Test-Path $tablePath) {
    $table = [System.IO.File]::ReadAllText($tablePath, [System.Text.Encoding]::UTF8)

    $oldWrap = '      <div className="overflow-hidden rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">'
    $newWrap = '      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[640px] text-sm">'
    $table = $table.Replace($oldWrap, $newWrap)

    Write-Utf8NoBom $tablePath $table
} else {
    Write-Host "  SKIPPED: sortable-table.tsx not found" -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 6. Sweep dashboard pages: give every "overflow-hidden rounded-xl border"
#    static table wrapper (raw-materials/[id], customers/[id], batches/[id],
#    finished-cartons, invoices/[id]) the same horizontal-scroll treatment,
#    and cap dialog height so short mobile screens can scroll them.
# --------------------------------------------------------------------------

$dashboardAppRoot = Join-Path $FrontendRoot "app\(dashboard)"
$sweepFiles = @()
if (Test-Path $dashboardAppRoot) {
    $sweepFiles += Get-ChildItem -Path $dashboardAppRoot -Recurse -Filter *.tsx -File
}

$sweepCount = 0
foreach ($file in $sweepFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $original = $content

    # Static (non-SortableTable) table wrappers -> allow horizontal scroll
    $content = $content -replace `
        'className="overflow-hidden rounded-xl border border-\[var\(--surface-border\)\]"(\s*>\s*<table className="w-full text-sm")', `
        'className="overflow-x-auto rounded-xl border border-[var(--surface-border)]"$1'

    # Dialog panels -> cap height + allow internal scroll on short mobile screens
    $content = $content -replace `
        '(className="w-full max-w-s[m|q]?[^"]*rounded-xl border border-\[var\(--surface-border\)\] bg-\[var\(--surface\)\] p-5 space-y-4)"', `
        '$1 max-h-[90vh] overflow-y-auto"'

    # Dialog outer backdrop containers -> ensure side padding on very small screens
    $content = $content -replace `
        'className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"', `
        'className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4"'

    if ($content -ne $original) {
        Write-Utf8NoBom $file.FullName $content
        $sweepCount++
    }
}

# --------------------------------------------------------------------------
# 7. Batches/new + Invoices/new: stack the material/item consumption rows
#    vertically on mobile instead of a cramped single row.
# --------------------------------------------------------------------------

$batchesNewPath = Join-Path $FrontendRoot "app\(dashboard)\batches\new\page.tsx"
if (Test-Path $batchesNewPath) {
    $bn = [System.IO.File]::ReadAllText($batchesNewPath, [System.Text.Encoding]::UTF8)
    $bn = $bn -replace 'className="flex items-center gap-2">\s*\n\s*<select value=\{row\.rawMaterialId\}', "className=`"flex flex-col sm:flex-row items-stretch sm:items-center gap-2`">`n                  <select value={row.rawMaterialId}"
    $bn = $bn -replace '(<input value=\{row\.qty\}[^/]*?)\bw-28\b', '$1w-full sm:w-28'
    Write-Utf8NoBom $batchesNewPath $bn
}

$invoicesNewPath = Join-Path $FrontendRoot "app\(dashboard)\invoices\new\page.tsx"
if (Test-Path $invoicesNewPath) {
    $inv = [System.IO.File]::ReadAllText($invoicesNewPath, [System.Text.Encoding]::UTF8)
    $inv = $inv -replace 'className="flex items-center gap-2">\s*\n\s*<select value=\{line\.itemId\}', "className=`"flex flex-col sm:flex-row items-stretch sm:items-center gap-2`">`n                  <select value={line.itemId}"
    $inv = $inv -replace '(<input value=\{line\.qty\}[^/]*?)\bw-20\b', '$1w-full sm:w-20'
    $inv = $inv -replace '(<input value=\{line\.unitPrice\}[^/]*?)\bw-28\b', '$1w-full sm:w-28'
    Write-Utf8NoBom $invoicesNewPath $inv
}

# --------------------------------------------------------------------------
# 8. Reports page - date filters wrap on mobile instead of overflowing
# --------------------------------------------------------------------------

$reportsPath = Join-Path $FrontendRoot "app\(dashboard)\reports\page.tsx"
if (Test-Path $reportsPath) {
    $rep = [System.IO.File]::ReadAllText($reportsPath, [System.Text.Encoding]::UTF8)
    $rep = $rep -replace 'className="flex flex-wrap items-end gap-3 rounded-xl border border-\[var\(--surface-border\)\] bg-\[var\(--surface\)\] p-4"', 'className="flex flex-col sm:flex-row flex-wrap items-stretch sm:items-end gap-3 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4"'
    Write-Utf8NoBom $reportsPath $rep
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  Sidebar is now a slide-in drawer below the lg breakpoint" -ForegroundColor Gray
Write-Host "    (hamburger in topbar opens it, tap backdrop or X to close)" -ForegroundColor Gray
Write-Host "  Desktop (lg and above) layout is UNCHANGED" -ForegroundColor Gray
Write-Host "  Topbar labels shrink on small screens; hamburger only shows on mobile" -ForegroundColor Gray
Write-Host "  Tables scroll horizontally instead of squashing on narrow screens" -ForegroundColor Gray
Write-Host "  Dialogs cap at 90vh with internal scroll for short mobile screens" -ForegroundColor Gray
Write-Host "  Batch/Invoice item rows stack vertically on mobile" -ForegroundColor Gray
Write-Host "  $sweepCount page files swept for table/dialog responsive fixes" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify locally:" -ForegroundColor Cyan
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host "Then open Chrome DevTools -> toggle device toolbar -> test at 375px/414px width." -ForegroundColor Gray