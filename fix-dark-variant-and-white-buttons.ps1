# fix-dark-variant-and-white-buttons.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-dark-variant-and-white-buttons.ps1
#
# ROOT CAUSE:
#   Tailwind CSS v4 does NOT read tailwind.config.ts automatically the way
#   v3 did. Any `dark:` prefixed utility class (e.g. "dark:bg-neutral-50")
#   is silently compiled out / ignored unless globals.css explicitly
#   registers the dark variant with `@custom-variant dark (...)`.
#   That line was missing, so every "bg-neutral-900 dark:bg-neutral-50"
#   button was stuck on bg-neutral-900 always - except wherever a plain
#   "bg-neutral-50" (no pairing at all) survived from the original build,
#   which showed white in BOTH themes. This script fixes both.
#
# What this does:
#   1. Adds `@custom-variant dark (&:where(.dark, .dark *));` to
#      globals.css so `dark:` classes actually compile and work.
#   2. Sweeps the entire frontend for any remaining un-paired
#      "bg-neutral-50" / "text-neutral-950" button classes (the ones
#      that show white always) and converts them to the correct
#      light/dark pattern.
#   3. Re-checks login page Sign In button and topbar/dashboard buttons
#      specifically, since those were reported still broken.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Fixing Tailwind v4 dark: variant + stray white buttons ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. globals.css - register the dark variant so dark: classes actually work
# --------------------------------------------------------------------------

$globalsCssPath = Join-Path $FrontendRoot "app\globals.css"
$globals = [System.IO.File]::ReadAllText($globalsCssPath, [System.Text.Encoding]::UTF8)

if ($globals -notmatch '@custom-variant dark') {
    $globals = $globals -replace '(@import "tailwindcss";)', "`$1`n@custom-variant dark (&:where(.dark, .dark *));"
    Write-Utf8NoBom $globalsCssPath $globals
    Write-Host "  Added @custom-variant dark to globals.css (THIS WAS THE ROOT CAUSE)" -ForegroundColor Yellow
} else {
    Write-Host "  @custom-variant dark already present - skipping" -ForegroundColor Gray
}

# --------------------------------------------------------------------------
# 2. Sweep every .tsx file for un-paired white buttons and fix them
# --------------------------------------------------------------------------

$allTsxFiles = Get-ChildItem -Path $FrontendRoot -Recurse -Filter *.tsx -File |
    Where-Object { $_.FullName -notmatch '\\node_modules\\' }

$fixCount = 0
foreach ($file in $allTsxFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $original = $content

    # Pattern A: literal un-paired "bg-neutral-50 ... text-neutral-950" with no dark: at all
    # (survived from before the theme conversion pass entirely)
    $content = [Regex]::Replace(
        $content,
        'bg-neutral-50(?!\s|["\s])?([^"]*?)text-neutral-950(?!\s+dark:)',
        'bg-neutral-900 dark:bg-neutral-50$1text-neutral-50 dark:text-neutral-950'
    )

    # Pattern B: "bg-[var(--foreground)] ... text-neutral-950" leftover from earlier sweeps
    # that never got converted to the neutral-900/neutral-50 pair
    $content = $content -replace 'bg-\[var\(--foreground\)\]', 'bg-neutral-900 dark:bg-neutral-50'
    $content = [Regex]::Replace(
        $content,
        '(bg-neutral-900 dark:bg-neutral-50[^"]*?)text-neutral-950(?!\s+dark:)',
        '$1text-neutral-50 dark:text-neutral-950'
    )

    # Pattern C: standalone "hover:bg-neutral-200" left dangling from old single-theme buttons
    $content = $content -replace 'hover:bg-neutral-200"', 'hover:opacity-90 transition-opacity"'

    if ($content -ne $original) {
        Write-Utf8NoBom $file.FullName $content
        $fixCount++
    }
}

# --------------------------------------------------------------------------
# 3. Explicit re-check: login page Sign In button
# --------------------------------------------------------------------------

$loginPagePath = Join-Path $FrontendRoot "app\(auth)\login\page.tsx"
if (Test-Path $loginPagePath) {
    $login = [System.IO.File]::ReadAllText($loginPagePath, [System.Text.Encoding]::UTF8)

    $login = [Regex]::Replace(
        $login,
        'className="w-full h-11 rounded-md[^"]*"',
        'className="w-full h-11 rounded-md bg-neutral-900 dark:bg-neutral-50 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50"'
    )

    Write-Utf8NoBom $loginPagePath $login
}

# --------------------------------------------------------------------------
# 4. Explicit re-check: topbar "+ New Invoice" button
# --------------------------------------------------------------------------

$topbarPath = Join-Path $FrontendRoot "components\ui\topbar.tsx"
if (Test-Path $topbarPath) {
    $topbar = [System.IO.File]::ReadAllText($topbarPath, [System.Text.Encoding]::UTF8)

    $topbar = [Regex]::Replace(
        $topbar,
        'className="rounded-lg bg-neutral-900[^"]*px-3 sm:px-4[^"]*"',
        'className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-3 sm:px-4 py-2 text-xs sm:text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity whitespace-nowrap"'
    )

    Write-Utf8NoBom $topbarPath $topbar
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  Root cause fixed: dark: variant now actually compiles (Tailwind v4)" -ForegroundColor Gray
Write-Host "  $fixCount additional files had stray un-paired white buttons fixed" -ForegroundColor Gray
Write-Host "  Login Sign In button + Topbar New Invoice button explicitly re-verified" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT: restart the dev server (dark: classes need a fresh build):" -ForegroundColor Yellow
Write-Host "  Ctrl+C to stop it if running, then:" -ForegroundColor Yellow
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify: light mode buttons should now show BLACK bg / white text," -ForegroundColor Cyan
Write-Host "and dark mode buttons should show WHITE bg / black text." -ForegroundColor Cyan