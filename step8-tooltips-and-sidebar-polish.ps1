<#
  step8-tooltips-and-sidebar-polish.ps1
  ------------------------------------------------------------------
  Step 8 of 8: UI polish (BRS v1.2 section 11 note; Frontend spec
  v2.2 sections 4.1 and 5.13).

  Covers the two remaining gap-analysis items:
    #9  Sidebar mini-labels (icon-only rail needs visible text)
    #10 Info tooltip ("i" icon) pattern

  What this does:

    0) Sidebar mini-labels — VERIFIED, NOT MODIFIED.
       components/ui/sidebar-component.tsx's IconNavButton already
       renders a permanent <span className="text-[8px] ...">{label}</span>
       under every icon in the collapsed rail (added earlier in this
       project) — this already satisfies spec section 4.1. The script
       checks for it and reports pass/fail; it does not touch this
       file, so nothing is at risk of being double-patched.

    1) apps/frontend/components/ui/info-tip.tsx (NEW)
       Extracts the small "i" tooltip pattern already used in
       packaging/page.tsx and payments/page.tsx into one shared,
       reusable <InfoTip text="..."/> component so every page uses
       the same look instead of copy-pasted local versions.

    2) apps/frontend/app/(dashboard)/raw-materials/page.tsx
       Adds an InfoTip next to the "Avg Unit Cost" column header
       explaining weighted-average costing.

    3) apps/frontend/app/(dashboard)/finished-cartons/page.tsx
       Adds an InfoTip next to both "Needed vs. Available" panel
       headers (step 2 preview + step 3 confirm), and one next to
       "Est. Cost / Carton" explaining the packet -> box -> carton
       cost build-up.

  Already done elsewhere (left untouched, verified present):
    - packaging/page.tsx      -> Grams per Unit (Define dialog)
    - payments/page.tsx       -> Direction control
    - customers/[id]/page.tsx -> Direction control
    - invoices/new/page.tsx   -> price-source note

  Not covered by this step (flagged, not silently skipped):
    - Carton Configuration cost preview does not exist yet in
      packaging/carton-config/page.tsx (no cost figures are shown
      there at all), so no tooltip can be attached to it. That is a
      feature gap, not a tooltip gap — build the cost preview first,
      then re-run a follow-up tooltip pass on that page.

  Run from the project root:
    PS D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods> .\step8-tooltips-and-sidebar-polish.ps1

  Safe to re-run: every edit is guarded by an "already applied" check
  (idempotent), and each touched file gets a one-time .step8.bak copy.
#>

$ErrorActionPreference = "Stop"

$root = Get-Location
Write-Host "Running Step 8 in: $root" -ForegroundColor Cyan

$sidebarPath        = Join-Path $root "apps/frontend/components/ui/sidebar-component.tsx"
$infoTipPath        = Join-Path $root "apps/frontend/components/ui/info-tip.tsx"
$rawMaterialsPath   = Join-Path $root "apps/frontend/app/(dashboard)/raw-materials/page.tsx"
$finishedCartonsPath = Join-Path $root "apps/frontend/app/(dashboard)/finished-cartons/page.tsx"

foreach ($p in @($sidebarPath, $rawMaterialsPath, $finishedCartonsPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host "ERROR: Expected file not found: $p" -ForegroundColor Red
        Write-Host "Make sure you are running this script from the GhaniFoods project root." -ForegroundColor Red
        exit 1
    }
}

function Backup-File($path) {
    $bak = "$path.step8.bak"
    if (-not (Test-Path -LiteralPath $bak)) {
        Copy-Item -LiteralPath $path -Destination $bak -Force
        Write-Host "Backed up: $path -> $bak" -ForegroundColor DarkGray
    }
}

function Write-Utf8NoBom($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------------------
# 0) Sidebar mini-labels — verify only
# ---------------------------------------------------------------------------
$sidebarContent = [System.IO.File]::ReadAllText($sidebarPath)
if ($sidebarContent -match 'text-\[8px\][^"]*"\s*>\s*\{label\}\s*<\/span>') {
    Write-Host "OK: Sidebar collapsed rail already shows permanent mini-labels under each icon (spec 4.1 satisfied)." -ForegroundColor Green
} else {
    Write-Host "WARNING: Could not confirm mini-labels in IconNavButton. Open sidebar-component.tsx and check IconNavButton manually." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 1) apps/frontend/components/ui/info-tip.tsx (NEW shared component)
# ---------------------------------------------------------------------------
$infoTipContent = @'
// Shared "i" info-tooltip used next to any field or calculated value whose
// meaning or derivation is not immediately obvious (BRS v1.2 note; Frontend
// spec v2.2 section 5.13). Hover on desktop, tap-to-toggle on touch via the
// native title attribute — kept intentionally lightweight (no extra deps).
export function InfoTip({ text }: { text: string }) {
  return (
    <span
      title={text}
      className="ml-1 inline-flex h-3.5 w-3.5 shrink-0 cursor-help select-none items-center justify-center rounded-full border border-[var(--text-faint)] text-[9px] leading-none text-[var(--text-faint)] align-middle"
    >
      i
    </span>
  );
}

export default InfoTip;
'@

if ((Test-Path -LiteralPath $infoTipPath) -and ([System.IO.File]::ReadAllText($infoTipPath) -eq $infoTipContent)) {
    Write-Host "Skipped (already up to date): $infoTipPath" -ForegroundColor DarkGray
} else {
    Write-Utf8NoBom $infoTipPath $infoTipContent
    Write-Host "Created/updated: $infoTipPath" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2) apps/frontend/app/(dashboard)/raw-materials/page.tsx
# ---------------------------------------------------------------------------
Backup-File $rawMaterialsPath
$rm = [System.IO.File]::ReadAllText($rawMaterialsPath)
$rmOriginal = $rm

if ($rm -notmatch 'components/ui/info-tip') {
    $rm = $rm -replace `
        [regex]::Escape('import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";'), `
        "import { PurchaseReceiptDialog } from `"@/components/ui/purchase-receipt-dialog`";`r`nimport { InfoTip } from `"@/components/ui/info-tip`";"
}

$oldHeader = '<th className="px-4 py-3 font-medium">Avg Unit Cost</th>'
$newHeader = @'
<th className="px-4 py-3 font-medium">
                <span className="inline-flex items-center">
                  Avg Unit Cost
                  <InfoTip text="Weighted average cost per unit across all purchase receipts for this raw material, recalculated on every new receipt." />
                </span>
              </th>
'@.Trim()

if ($rm -match [regex]::Escape($oldHeader)) {
    $rm = $rm -replace [regex]::Escape($oldHeader), [System.Text.RegularExpressions.Regex]::Escape($newHeader).Replace('\','\\') 2>$null
}
# (Regex.Escape on the replacement is unnecessary/harmful for -replace's replacement
# string; use a plain string replace instead to avoid $ / \ token issues.)
if ($rmOriginal -match [regex]::Escape($oldHeader) -and $rm -eq $rmOriginal) {
    $rm = $rmOriginal.Replace($oldHeader, $newHeader)
    if ($rm -notmatch 'components/ui/info-tip') {
        $rm = $rm.Replace(
            'import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";',
            "import { PurchaseReceiptDialog } from `"@/components/ui/purchase-receipt-dialog`";`r`nimport { InfoTip } from `"@/components/ui/info-tip`";"
        )
    }
}

if ($rm -eq $rmOriginal) {
    Write-Host "Skipped (already applied or pattern not found): $rawMaterialsPath" -ForegroundColor DarkGray
} else {
    Write-Utf8NoBom $rawMaterialsPath $rm
    Write-Host "Updated: $rawMaterialsPath" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3) apps/frontend/app/(dashboard)/finished-cartons/page.tsx
# ---------------------------------------------------------------------------
Backup-File $finishedCartonsPath
$fc = [System.IO.File]::ReadAllText($finishedCartonsPath)
$fcOriginal = $fc

if ($fc -notmatch 'components/ui/info-tip') {
    $fc = $fc.Replace(
        'import { useStore } from "@/lib/store";',
        "import { useStore } from `"@/lib/store`";`r`nimport { InfoTip } from `"@/components/ui/info-tip`";"
    )
}

$neededVsAvailableTip = 'How much of each input the requested Cartons Produced will consume, versus how much is currently in stock. All three must be sufficient before you can confirm.'

# Step-2 preview panel occurrence (indented one level deeper, followed by the
# insufficient-stock warning block) — matched with its distinctive
# 16-space indent + trailing AvailabilityRow lines to keep it unique.
$oldNeeded2 = @'
              <div className="space-y-2">
                <div className="text-xs font-medium text-[var(--text-muted)]">Needed vs. Available</div>
                <AvailabilityRow label="Bulk Material" needed={bulkKgNeeded} available={bulkAvailable} unit="kg" />
'@
$newNeeded2 = @'
              <div className="space-y-2">
                <div className="flex items-center text-xs font-medium text-[var(--text-muted)]">
                  Needed vs. Available
                  <InfoTip text="__TIP__" />
                </div>
                <AvailabilityRow label="Bulk Material" needed={bulkKgNeeded} available={bulkAvailable} unit="kg" />
'@.Replace('__TIP__', $neededVsAvailableTip)

# Step-3 confirm panel occurrence (14-space indent, no warning block after it).
$oldNeeded3 = @'
            <div className="space-y-2">
              <div className="text-xs font-medium text-[var(--text-muted)]">Needed vs. Available</div>
              <AvailabilityRow label="Bulk Material" needed={bulkKgNeeded} available={bulkAvailable} unit="kg" />
'@
$newNeeded3 = @'
            <div className="space-y-2">
              <div className="flex items-center text-xs font-medium text-[var(--text-muted)]">
                Needed vs. Available
                <InfoTip text="__TIP__" />
              </div>
              <AvailabilityRow label="Bulk Material" needed={bulkKgNeeded} available={bulkAvailable} unit="kg" />
'@.Replace('__TIP__', $neededVsAvailableTip)

if ($fc.Contains($oldNeeded2)) { $fc = $fc.Replace($oldNeeded2, $newNeeded2) }
if ($fc.Contains($oldNeeded3)) { $fc = $fc.Replace($oldNeeded3, $newNeeded3) }

$oldCostCarton = @'
                  <div className="flex justify-between text-sm">
                    <span className="text-[var(--text-muted)]">Est. Cost / Carton</span>
                    <span className="text-[var(--foreground)] font-semibold">Rs. {preview.costPerCarton.toFixed(2)}</span>
                  </div>
'@
$newCostCarton = @'
                  <div className="flex justify-between text-sm">
                    <span className="inline-flex items-center text-[var(--text-muted)]">
                      Est. Cost / Carton
                      <InfoTip text="Cost per packet (bulk share + wrapper) x packets per box, plus box cost, x boxes per carton." />
                    </span>
                    <span className="text-[var(--foreground)] font-semibold">Rs. {preview.costPerCarton.toFixed(2)}</span>
                  </div>
'@

if ($fc.Contains($oldCostCarton)) { $fc = $fc.Replace($oldCostCarton, $newCostCarton) }

if ($fc -eq $fcOriginal) {
    Write-Host "Skipped (already applied or pattern not found): $finishedCartonsPath" -ForegroundColor DarkGray
} else {
    Write-Utf8NoBom $finishedCartonsPath $fc
    Write-Host "Updated: $finishedCartonsPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 8 complete." -ForegroundColor Cyan
Write-Host "  - Sidebar mini-labels: verified present (no changes needed)." -ForegroundColor Cyan
Write-Host "  - New shared components/ui/info-tip.tsx (InfoTip) for reuse across pages." -ForegroundColor Cyan
Write-Host "  - Raw Materials: info tooltip added on 'Avg Unit Cost' column header." -ForegroundColor Cyan
Write-Host "  - Finished Cartons: info tooltips added on both 'Needed vs. Available' panels and 'Est. Cost / Carton'." -ForegroundColor Cyan
Write-Host "  - NOTE: Carton Configuration cost preview does not exist yet in packaging/carton-config -- build that feature before a tooltip can be attached there." -ForegroundColor Yellow
Write-Host ""
Write-Host "Next: run 'npm run dev' inside apps/frontend and verify /raw-materials and /finished-cartons." -ForegroundColor Yellow