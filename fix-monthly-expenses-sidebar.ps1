<#
  fix-monthly-expenses-sidebar.ps1
  ------------------------------------------------------------------
  Run this from the project ROOT:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  BUG:
    Visiting /monthly-expenses correctly opens the page, but the left
    sidebar falls back to the "Dashboard" section instead of staying
    on "Batches" (which is where the "Costs -> Monthly Expenses" link
    lives). This is because ROUTE_PREFIXES in sidebar-component.tsx
    has no entry for "/monthly-expenses", so getSectionFromPathname()
    can't match it and defaults to "dashboard".

  FIX:
    Adds ["/monthly-expenses", "batches"] to ROUTE_PREFIXES so the
    sidebar correctly stays on the Batches section (showing the
    Costs -> Monthly Expenses link as active/available) whenever the
    user is on /monthly-expenses.

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
Write-Host "  Fix: Monthly Expenses sidebar section highlight" -ForegroundColor Cyan
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

$sidebarPath = Join-Path $root "apps\frontend\components\ui\sidebar-component.tsx"

Write-Host "`n[1/1] apps/frontend/components/ui/sidebar-component.tsx"
Backup-File $sidebarPath

Edit-File $sidebarPath `
@'
const ROUTE_PREFIXES: Array<[string, SectionId]> = [
  ["/suppliers", "suppliers"],
  ["/raw-materials", "raw-materials"],
  ["/receipts", "receipts"],
  ["/packaging", "raw-materials"],
  ["/packaging/carton-config", "raw-materials"],
  ["/batches", "batches"],
  ["/finished-cartons", "finished-cartons"],
'@ `
@'
const ROUTE_PREFIXES: Array<[string, SectionId]> = [
  ["/suppliers", "suppliers"],
  ["/raw-materials", "raw-materials"],
  ["/receipts", "receipts"],
  ["/packaging", "raw-materials"],
  ["/packaging/carton-config", "raw-materials"],
  ["/batches", "batches"],
  ["/monthly-expenses", "batches"],
  ["/finished-cartons", "finished-cartons"],
'@ `
"sidebar-component.tsx: map /monthly-expenses -> batches section"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  DONE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host @"

Next steps:
  1. cd apps\frontend
  2. npm run build   (or just refresh dev server)
  3. Visit /monthly-expenses in the browser and confirm the sidebar
     now stays on the "Batches" section (Costs -> Monthly Expenses)
     instead of falling back to Dashboard.

If anything looks off, the original file is backed up right next to
it as sidebar-component.tsx.bak-$ts
"@ -ForegroundColor Yellow