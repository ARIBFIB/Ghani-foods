# fix-button-contrast-and-logo.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-button-contrast-and-logo.ps1
#
# What this does:
#   1. Fixes "+ New Invoice" (topbar), "+ Add Raw Material" / "+ New Batch"
#      (dashboard quick actions), and "Sign In" (login) buttons so they
#      have real contrast in BOTH light and dark mode instead of
#      white-bg/white-text or invisible borders.
#   2. Replaces the plain white/black square placeholder logo with a real
#      wheat-grain SVG icon (fits a food/snack business), rendered with
#      currentColor so it's visible in both themes. Used in: sidebar icon
#      rail, sidebar brand badge, and login page.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Fixing button contrast + adding real logo ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. New SVG logo component (wheat grain, currentColor-based)
# --------------------------------------------------------------------------

$logoPath = Join-Path $FrontendRoot "components\ui\ghani-logo.tsx"
$logoContent = @'
export function GhaniLogo({ className = "size-5" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      <path
        d="M12 2C12 2 9.5 4.5 9.5 7.5C9.5 9.15685 10.6193 10 12 10C13.3807 10 14.5 9.15685 14.5 7.5C14.5 4.5 12 2 12 2Z"
        fill="currentColor"
      />
      <path
        d="M7.5 6.5C7.5 6.5 5.5 8.5 5.5 11C5.5 12.3807 6.5 13 7.5 13C8.5 13 9.5 12.3807 9.5 11C9.5 8.5 7.5 6.5 7.5 6.5Z"
        fill="currentColor"
      />
      <path
        d="M16.5 6.5C16.5 6.5 14.5 8.5 14.5 11C14.5 12.3807 15.5 13 16.5 13C17.5 13 18.5 12.3807 18.5 11C18.5 8.5 16.5 6.5 16.5 6.5Z"
        fill="currentColor"
      />
      <path
        d="M12 9C12 9 9.5 11.5 9.5 14.5C9.5 16.1569 10.6193 17 12 17C13.3807 17 14.5 16.1569 14.5 14.5C14.5 11.5 12 9 12 9Z"
        fill="currentColor"
      />
      <path
        d="M12 16V22"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}

export default GhaniLogo;
'@
Write-Utf8NoBom $logoPath $logoContent

# --------------------------------------------------------------------------
# 2. Sidebar - replace placeholder white square with GhaniLogo, fix icon nav
# --------------------------------------------------------------------------

$sidebarPath = Join-Path $FrontendRoot "components\ui\sidebar-component.tsx"
if (Test-Path $sidebarPath) {
    $sidebar = [System.IO.File]::ReadAllText($sidebarPath, [System.Text.Encoding]::UTF8)

    # add import if missing
    if ($sidebar -notmatch 'GhaniLogo') {
        $sidebar = $sidebar -replace '(import React, \{ useState \} from "react";)', "`$1`nimport { GhaniLogo } from `"./ghani-logo`";"
    }

    # InterfacesLogoSquare -> real logo, theme-aware color
    $oldLogoFn = @'
function InterfacesLogoSquare() {
  return (
    <div className="aspect-[24/24] grow min-h-px min-w-px overflow-clip relative shrink-0">
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="size-4 rounded-sm bg-neutral-50" />
      </div>
    </div>
  );
}
'@
    $newLogoFn = @'
function InterfacesLogoSquare() {
  return (
    <div className="aspect-[24/24] grow min-h-px min-w-px overflow-clip relative shrink-0">
      <div className="absolute inset-0 flex items-center justify-center text-[var(--foreground)]">
        <GhaniLogo className="size-5" />
      </div>
    </div>
  );
}
'@
    $sidebar = $sidebar.Replace($oldLogoFn, $newLogoFn)

    Write-Utf8NoBom $sidebarPath $sidebar
} else {
    Write-Host "  SKIPPED: sidebar-component.tsx not found" -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 3. Topbar - fix "+ New Invoice" button contrast (was bg-neutral-50 fixed,
#    now uses a solid brand color that reads correctly in both themes)
# --------------------------------------------------------------------------

$topbarPath = Join-Path $FrontendRoot "components\ui\topbar.tsx"
if (Test-Path $topbarPath) {
    $topbar = [System.IO.File]::ReadAllText($topbarPath, [System.Text.Encoding]::UTF8)

    $oldBtn = 'className="rounded-lg bg-[var(--foreground)] px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"'
    $newBtn = 'className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity"'

    if ($topbar -match [Regex]::Escape($oldBtn)) {
        $topbar = $topbar.Replace($oldBtn, $newBtn)
    } else {
        # fallback: catch whatever variant survived the earlier sweep
        $topbar = [Regex]::Replace(
            $topbar,
            'className="rounded-lg bg-\[var\(--foreground\)\][^"]*"',
            $newBtn
        )
    }

    Write-Utf8NoBom $topbarPath $topbar
} else {
    Write-Host "  SKIPPED: topbar.tsx not found" -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 4. Dashboard page - fix "+ New Invoice" (primary) and outline buttons
#    ("+ Add Raw Material", "+ New Batch") for real contrast both themes
# --------------------------------------------------------------------------

$dashboardPagePath = Join-Path $FrontendRoot "app\(dashboard)\page.tsx"
if (Test-Path $dashboardPagePath) {
    $dash = [System.IO.File]::ReadAllText($dashboardPagePath, [System.Text.Encoding]::UTF8)

    # Outline buttons (Add Raw Material / New Batch)
    $oldOutline = 'className="rounded-lg border border-[var(--surface-border-strong)] px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]"'
    $newOutline = 'className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)] transition-colors"'
    $dash = $dash.Replace($oldOutline, $newOutline)
    # fallback in case sweep left a slightly different class order
    $dash = [Regex]::Replace(
        $dash,
        'className="rounded-lg border border-\[var\(--surface-border-strong\)\][^"]*"',
        $newOutline
    )

    # Primary "+ New Invoice" button
    $oldPrimary = 'className="rounded-lg bg-[var(--foreground)] px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"'
    $newPrimary = 'className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity"'
    $dash = $dash.Replace($oldPrimary, $newPrimary)
    $dash = [Regex]::Replace(
        $dash,
        'className="rounded-lg bg-\[var\(--foreground\)\][^"]*"',
        $newPrimary
    )

    Write-Utf8NoBom $dashboardPagePath $dash
} else {
    Write-Host "  SKIPPED: app\(dashboard)\page.tsx not found" -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 5. Sweep ALL remaining pages/dialogs for the same two broken patterns
#    (primary "save/confirm" buttons and outline buttons use this pattern
#    everywhere - raw-materials, batches, customers, invoices, etc.)
# --------------------------------------------------------------------------

$dashboardAppRoot = Join-Path $FrontendRoot "app\(dashboard)"
$sweepFiles = @()
if (Test-Path $dashboardAppRoot) {
    $sweepFiles += Get-ChildItem -Path $dashboardAppRoot -Recurse -Filter *.tsx -File
}

$primaryPattern = 'className="rounded-lg bg-\[var\(--foreground\)\]([^"]*)"'
$primaryReplacement = 'className="rounded-lg bg-neutral-900 dark:bg-neutral-50 text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity$1"'

$outlinePattern = 'className="rounded-lg border border-\[var\(--surface-border-strong\)\]([^"]*)"'
$outlineReplacement = 'className="rounded-lg border border-neutral-400 dark:border-neutral-600$1"'

$sweepCount = 0
foreach ($file in $sweepFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $original = $content

    $content = [Regex]::Replace($content, $primaryPattern, {
        param($m)
        $rest = $m.Groups[1].Value -replace 'text-neutral-950', '' -replace 'hover:bg-neutral-200', ''
        "className=`"rounded-lg bg-neutral-900 dark:bg-neutral-50 text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity$rest`""
    })
    $content = [Regex]::Replace($content, $outlinePattern, {
        param($m)
        "className=`"rounded-lg border border-neutral-400 dark:border-neutral-600$($m.Groups[1].Value)`""
    })

    if ($content -ne $original) {
        Write-Utf8NoBom $file.FullName $content
        $sweepCount++
    }
}

# --------------------------------------------------------------------------
# 6. Login page - use the same GhaniLogo instead of Grid2x2PlusIcon
# --------------------------------------------------------------------------

$loginPagePath = Join-Path $FrontendRoot "app\(auth)\login\page.tsx"
if (Test-Path $loginPagePath) {
    $login = [System.IO.File]::ReadAllText($loginPagePath, [System.Text.Encoding]::UTF8)

    $login = $login -replace 'import \{ AtSignIcon, LockIcon, Grid2x2PlusIcon \} from "lucide-react";',
        "import { AtSignIcon, LockIcon } from `"lucide-react`";`nimport { GhaniLogo } from `"@/components/ui/ghani-logo`";"

    $login = $login -replace '<Grid2x2PlusIcon className="size-6" />', '<GhaniLogo className="size-6" />'

    # fix Sign In button contrast too
    $oldSignIn = 'className="w-full h-11 rounded-md bg-neutral-900 dark:bg-neutral-50 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 disabled:opacity-50"'
    if ($login -notmatch [Regex]::Escape($oldSignIn)) {
        $login = [Regex]::Replace(
            $login,
            'className="w-full h-11 rounded-md[^"]*"',
            $oldSignIn
        )
    }

    Write-Utf8NoBom $loginPagePath $login
} else {
    Write-Host "  SKIPPED: login page not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  New GhaniLogo SVG created: components\ui\ghani-logo.tsx" -ForegroundColor Gray
Write-Host "  Sidebar + Login now use the real logo (visible both themes)" -ForegroundColor Gray
Write-Host "  Primary buttons (+ New Invoice, Save, Sign In, etc.):" -ForegroundColor Gray
Write-Host "    dark bg in light mode / light bg in dark mode - always readable" -ForegroundColor Gray
Write-Host "  Outline buttons (+ Add Raw Material, + New Batch, Cancel, etc.):" -ForegroundColor Gray
Write-Host "    border-neutral-400 (light) / border-neutral-600 (dark) - visible both" -ForegroundColor Gray
Write-Host "  $sweepCount additional files swept across dashboard pages" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify locally:" -ForegroundColor Cyan
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host "Check: login page logo + toggle, dashboard buttons in both themes." -ForegroundColor Gray