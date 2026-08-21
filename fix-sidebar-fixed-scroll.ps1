<#
  fix-sidebar-fixed-scroll.ps1
  ------------------------------------------------------------------
  Run this from the project ROOT:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  BUG:
    On pages with tall content (Reports, Settings, etc.), the whole
    page scrolls - including the left sidebar - because the outer
    wrapper in the dashboard layout uses "min-h-screen", which grows
    taller than the viewport and lets the WHOLE BODY scroll. Since
    the sidebar itself isn't pinned to the viewport, it scrolls away
    with the rest of the page.

  FIX:
    Changes the outer wrapper in:
      apps/frontend/app/(dashboard)/layout.tsx
    from "flex min-h-screen ..." to "flex h-screen overflow-hidden ...".
    This locks the whole shell to exactly the viewport height. The
    sidebar (already h-screen) now stays fixed in place, and only
    the <main> area (which already has overflow-y-auto) scrolls.

    Because ALL dashboard pages (Reports, Settings, Batches, etc.)
    share this one layout file, this single fix resolves the issue
    everywhere at once - no need to touch each page individually.

  SAFETY:
    The file is backed up to <file>.bak-<timestamp> before editing.
    The patch only applies if the exact anchor text is found EXACTLY
    ONCE in the file. If not found (e.g. already patched, or the file
    has since changed), the step is SKIPPED with a warning - nothing
    is force-applied or corrupted.
------------------------------------------------------------------#>

$ErrorActionPreference = "Stop"
$root = Get-Location
$ts = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Fix: Sidebar fixed, main content scrollable" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Root: $root`n"

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        $bak = "$path.bak-$ts"
        Copy-Item -LiteralPath $path -Destination $bak -Force
        Write-Host "  Backed up -> $bak" -ForegroundColor DarkGray
    }
}

function Edit-File($path, $old, $new, $label) {
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Warning "SKIP [$label]: file not found -> $path"
        return
    }
    $content = Get-Content -Raw -LiteralPath $path
    $count = ([regex]::Matches($content, [regex]::Escape($old))).Count
    if ($count -eq 1) {
        $newContent = $content.Replace($old, $new)
        Set-Content -LiteralPath $path -Value $newContent -NoNewline -Encoding UTF8
        Write-Host "  OK   [$label]" -ForegroundColor Green
    } elseif ($count -eq 0) {
        Write-Warning "SKIP [$label]: anchor text not found (file may already be patched, or edited) -> $path"
    } else {
        Write-Warning "SKIP [$label]: anchor text found $count times (expected 1, ambiguous) -> $path"
    }
}

$layoutPath = Join-Path $root "apps\frontend\app\(dashboard)\layout.tsx"

Write-Host "`n[1/1] apps/frontend/app/(dashboard)/layout.tsx"
Backup-File $layoutPath

Edit-File $layoutPath `
@'
        <div className="flex min-h-screen bg-[var(--background)]">
'@ `
@'
        <div className="flex h-screen overflow-hidden bg-[var(--background)]">
'@ `
"layout.tsx: lock outer shell to viewport height so sidebar stays fixed"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  DONE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host @"

Next steps:
  1. cd apps\frontend
  2. npm run build   (or just refresh dev server)
  3. Visit /reports, /settings, or any page with tall content and
     confirm the left sidebar now stays fixed in place while only
     the right-side content area scrolls.

This fix applies to ALL dashboard pages at once (Reports, Settings,
Batches, Monthly Expenses, etc.) since they all share this one
layout.tsx file.

If anything looks off, the original file is backed up right next to
it as layout.tsx.bak-$ts
"@ -ForegroundColor Yellow