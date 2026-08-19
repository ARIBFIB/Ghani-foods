<#
  Step 13 — Fix build error: Property 'unitCost' does not exist on type 'Wrapper'/'Box'
  ------------------------------------------------------------------------------------
  Root cause: Wrapper and Box are now raw-material-linked (Spec v1.2/v2.2 item 2) -
  they no longer carry their own unitCost field. Their per-unit cost must be derived
  from gramsPerUnit x the underlying RawMaterial's avgUnitCost (with a kg/g
  conversion), exactly as the store's createPackingRun() already does internally
  via the private computePackagingUnitCost() helper.

  finished-cartons/page.tsx's live preview (NewPackingRunDialog) was never updated
  after that data-model change and still reads wrapper.unitCost / box.unitCost,
  which no longer exist -> TypeScript build failure:

    ./app/(dashboard)/finished-cartons/page.tsx:72:87
    Type error: Property 'unitCost' does not exist on type 'Wrapper'.

  Fix (two parts):
   1. lib/store.ts - export the existing computePackagingUnitCost() helper so
      pages can reuse the exact same cost logic instead of duplicating it.
   2. finished-cartons/page.tsx - pull rawMaterials from the store, look up the
      wrapper's/box's underlying raw material, and use
      computePackagingUnitCost(gramsPerUnit, rawMaterial) instead of the
      removed .unitCost field. This keeps the dialog's live preview numerically
      identical to what createPackingRun() actually deducts/costs on confirm.

  Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#>

$ErrorActionPreference = "Stop"

$root = Get-Location
$storePath = Join-Path $root "apps\frontend\lib\store.ts"
$fcPath = Join-Path $root "apps\frontend\app\(dashboard)\finished-cartons\page.tsx"

foreach ($p in @($storePath, $fcPath)) {
    if (-not (Test-Path $p)) {
        Write-Host "ERROR: Could not find $p" -ForegroundColor Red
        Write-Host "Make sure you are running this from the GhaniFoods root folder." -ForegroundColor Red
        exit 1
    }
}

function Write-Utf8NoBom($path, $content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $enc)
}

function Backup-File($path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $bak = "$path.bak-step13-$stamp"
    Copy-Item -Path $path -Destination $bak -Force
    Write-Host "Backed up: $bak" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 1) store.ts - export computePackagingUnitCost
# ---------------------------------------------------------------------------
Backup-File $storePath
$storeSrc = [System.IO.File]::ReadAllText($storePath)
$storeOriginal = $storeSrc

$oldFn = "function computePackagingUnitCost(gramsPerUnit: number, rawMaterial: RawMaterial | undefined): number {"
$newFn = "export function computePackagingUnitCost(gramsPerUnit: number, rawMaterial: RawMaterial | undefined): number {"

if ($storeSrc.Contains($newFn)) {
    Write-Host "computePackagingUnitCost already exported - skipping." -ForegroundColor DarkGray
} elseif ($storeSrc.Contains($oldFn)) {
    $storeSrc = $storeSrc.Replace($oldFn, $newFn)
} else {
    Write-Host "WARNING: computePackagingUnitCost function signature not found in store.ts - skipping export change." -ForegroundColor Yellow
}

if ($storeSrc -eq $storeOriginal) {
    Write-Host "Skipped (already applied or pattern not found): $storePath" -ForegroundColor DarkGray
} else {
    Write-Utf8NoBom $storePath $storeSrc
    Write-Host "Updated: $storePath" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2) finished-cartons/page.tsx - use computePackagingUnitCost instead of
#    the removed wrapper.unitCost / box.unitCost fields.
# ---------------------------------------------------------------------------
Backup-File $fcPath
$fcSrc = [System.IO.File]::ReadAllText($fcPath)
$fcOriginal = $fcSrc

# 2a. Import the helper alongside useStore.
$oldImport = 'import { useStore } from "@/lib/store";'
$newImport = 'import { useStore, computePackagingUnitCost } from "@/lib/store";'

if ($fcSrc.Contains($newImport)) {
    Write-Host "computePackagingUnitCost import already present - skipping." -ForegroundColor DarkGray
} elseif ($fcSrc.Contains($oldImport)) {
    $fcSrc = $fcSrc.Replace($oldImport, $newImport)
} else {
    Write-Host "WARNING: expected store import line not found - skipping import change." -ForegroundColor Yellow
}

# 2b. Pull rawMaterials from the store and resolve wrapper/box raw materials.
$oldLookups = @'
  const wrapper = wrappers.find((w) => w.id === config?.wrapperId);
  const box = boxes.find((b) => b.id === config?.boxId);
'@

$newLookups = @'
  const rawMaterials = useStore((s) => s.rawMaterials);
  const wrapper = wrappers.find((w) => w.id === config?.wrapperId);
  const box = boxes.find((b) => b.id === config?.boxId);
  const wrapperRawMaterial = rawMaterials.find((m) => m.id === wrapper?.rawMaterialId);
  const boxRawMaterial = rawMaterials.find((m) => m.id === box?.rawMaterialId);
'@

if ($fcSrc.Contains("const wrapperRawMaterial = rawMaterials.find")) {
    Write-Host "rawMaterial lookups already present - skipping." -ForegroundColor DarkGray
} elseif ($fcSrc.Contains($oldLookups)) {
    $fcSrc = $fcSrc.Replace($oldLookups, $newLookups)
} else {
    Write-Host "WARNING: wrapper/box lookup block not found in expected shape - skipping lookup change." -ForegroundColor Yellow
}

# 2c. Replace the unitCost usages with computePackagingUnitCost(...) calls.
$oldCostLines = @'
    const costPerPacket = packetsNeeded > 0 ? bulkCostShare / packetsNeeded + wrapper.unitCost : wrapper.unitCost;
    const costPerBox = config.packetsPerBox * costPerPacket + box.unitCost;
'@

$newCostLines = @'
    const wrapperUnitCostValue = computePackagingUnitCost(wrapper.gramsPerUnit, wrapperRawMaterial);
    const boxUnitCostValue = computePackagingUnitCost(box.gramsPerUnit, boxRawMaterial);
    const costPerPacket = packetsNeeded > 0 ? bulkCostShare / packetsNeeded + wrapperUnitCostValue : wrapperUnitCostValue;
    const costPerBox = config.packetsPerBox * costPerPacket + boxUnitCostValue;
'@

if ($fcSrc.Contains("const wrapperUnitCostValue = computePackagingUnitCost")) {
    Write-Host "Cost calculation already patched - skipping." -ForegroundColor DarkGray
} elseif ($fcSrc.Contains($oldCostLines)) {
    $fcSrc = $fcSrc.Replace($oldCostLines, $newCostLines)
} else {
    Write-Host "WARNING: costPerPacket/costPerBox lines not found in expected shape - skipping cost-calc change." -ForegroundColor Yellow
    Write-Host "Please check finished-cartons/page.tsx manually around the 'preview' useMemo." -ForegroundColor Yellow
}

if ($fcSrc -eq $fcOriginal) {
    Write-Host "Skipped (already applied or pattern not found): $fcPath" -ForegroundColor DarkGray
} else {
    Write-Utf8NoBom $fcPath $fcSrc
    Write-Host "Updated: $fcPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 13 complete." -ForegroundColor Cyan
Write-Host "  - store.ts: computePackagingUnitCost() is now exported for reuse." -ForegroundColor Cyan
Write-Host "  - finished-cartons/page.tsx: live preview now derives wrapper/box unit cost from" -ForegroundColor Cyan
Write-Host "    gramsPerUnit x underlying raw material cost, matching what createPackingRun() actually" -ForegroundColor Cyan
Write-Host "    computes and deducts on confirm - no more 'unitCost does not exist' type error." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: cd apps/frontend, run npm run build (or npm run dev), and verify /finished-cartons compiles" -ForegroundColor Yellow
Write-Host "and the packing-run preview's cost figures still look sane." -ForegroundColor Yellow