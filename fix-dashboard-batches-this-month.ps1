<#
  fix-dashboard-batches-this-month.ps1
  ------------------------------------------------------------------
  Run this from the project ROOT:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  BUG:
    On the Dashboard, "Batches This Month" always shows 6, no matter
    what - even right after deleting ALL data via the Danger Zone.

  ROOT CAUSE:
    apps/frontend/app/(dashboard)/page.tsx has this KPI card:
        <KpiCard label="Batches This Month" value={6} />
    The "6" is a hardcoded literal - it was never wired up to the
    actual productionBatches data from the store. Every other KPI
    card (Total Raw Material Value, Finished Cartons Ready, Total
    Receivables) IS calculated live from the store; this one alone
    was left as a placeholder number and never finished.

  FIX:
    Adds a real "batchesThisMonth" calculation to the existing kpis
    useMemo (counts productionBatches whose batchDate falls in the
    current calendar month/year), and wires the KPI card to use it
    instead of the hardcoded 6.

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
Write-Host "  Fix: 'Batches This Month' hardcoded as 6" -ForegroundColor Cyan
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

$dashboardPath = Join-Path $root "apps\frontend\app\(dashboard)\page.tsx"

Write-Host "`n[1/2] apps/frontend/app/(dashboard)/page.tsx"
Backup-File $dashboardPath

# 1) Extend the kpis useMemo to actually compute batchesThisMonth from
#    real data, instead of leaving it out entirely.
Edit-File $dashboardPath `
@'
  const kpis = useMemo(() => {
    const totalRawMaterialValue = rawMaterials.reduce((sum, m) => sum + m.quantityInStock * m.avgUnitCost, 0);
    const finishedCartonsReady = finishedCartons.reduce((sum, c) => sum + c.stockQty, 0);
    const totalReceivables = customers.reduce((sum, c) => sum + Math.max(0, c.currentBalance), 0);
    return { totalRawMaterialValue, finishedCartonsReady, totalReceivables };
  }, [rawMaterials, finishedCartons, customers]);
'@ `
@'
  const kpis = useMemo(() => {
    const totalRawMaterialValue = rawMaterials.reduce((sum, m) => sum + m.quantityInStock * m.avgUnitCost, 0);
    const finishedCartonsReady = finishedCartons.reduce((sum, c) => sum + c.stockQty, 0);
    const totalReceivables = customers.reduce((sum, c) => sum + Math.max(0, c.currentBalance), 0);
    const now = new Date();
    const batchesThisMonth = productionBatches.filter((b) => {
      const d = new Date(b.batchDate);
      return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
    }).length;
    return { totalRawMaterialValue, finishedCartonsReady, totalReceivables, batchesThisMonth };
  }, [rawMaterials, finishedCartons, customers, productionBatches]);
'@ `
"page.tsx: compute batchesThisMonth from real productionBatches data"

# 2) Point the KPI card at the real computed value instead of the
#    hardcoded literal 6.
Edit-File $dashboardPath `
@'
        <KpiCard label="Batches This Month" value={6} />
'@ `
@'
        <KpiCard label="Batches This Month" value={kpis.batchesThisMonth} />
'@ `
"page.tsx: wire KpiCard to kpis.batchesThisMonth instead of hardcoded 6"

# 3) Make sure productionBatches is actually pulled from the store on
#    this page (it's needed for the calculation above). Only added if
#    not already present - most versions of this page already read
#    several store slices here, so this just ensures the one we need
#    for the fix exists too.
$content = Get-Content -Raw -LiteralPath $dashboardPath
if ($content -notmatch 'const productionBatches = useStore') {
    Edit-File $dashboardPath `
@'
  const rawMaterials = useStore((s) => s.rawMaterials);
'@ `
@'
  const rawMaterials = useStore((s) => s.rawMaterials);
  const productionBatches = useStore((s) => s.productionBatches);
'@ `
"page.tsx: add missing productionBatches store selector"
} else {
    Write-Host "  OK   [productionBatches selector already present]" -ForegroundColor Green
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  DONE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host @"

Next steps:
  1. cd apps\frontend
  2. npm run build   (or just refresh dev server)
  3. Visit / (Dashboard) and confirm "Batches This Month" now shows
     the REAL count of batches created in the current calendar month
     - 0 right after a full data delete, and increasing correctly as
     you create new batches this month.

If anything looks off, the original file is backed up right next to
it as page.tsx.bak-$ts
"@ -ForegroundColor Yellow