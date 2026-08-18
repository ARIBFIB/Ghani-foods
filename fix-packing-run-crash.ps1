# fix-packing-run-crash.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\fix-packing-run-crash.ps1
#
# Fixes: "Application error" / React error #310 when clicking
# "+ New Packing Run" on the Finished Cartons page.
#
# Root cause: apps/frontend/app/(dashboard)/finished-cartons/page.tsx had
# `if (!open) return null;` BEFORE the `useMemo` hook inside
# NewPackingRunDialog. That means useMemo is skipped when the dialog is
# closed and called when it's open - a Rules-of-Hooks violation that
# crashes React. This script moves the early return to AFTER all hooks.

$TargetFile = Join-Path (Get-Location) "apps\frontend\app\(dashboard)\finished-cartons\page.tsx"

if (-not (Test-Path $TargetFile)) {
    Write-Host "ERROR: Could not find $TargetFile" -ForegroundColor Red
    Write-Host "Make sure you run this script from the GhaniFoods project root." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Fixing Packing Run dialog crash ===" -ForegroundColor Cyan

$bytes = [System.IO.File]::ReadAllBytes($TargetFile)
$stream = New-Object System.IO.MemoryStream(,$bytes)
$reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
$content = $reader.ReadToEnd()
$reader.Close()

$oldBlock = @"
  const [cartonsProduced, setCartonsProduced] = useState("10");

  if (!open) return null;

  const batch = productionBatches.find((b) => b.id === batchId);
  const config = cartonConfigurations.find((c) => c.id === configId);
  const wrapper = wrappers.find((w) => w.id === config?.wrapperId);
  const box = boxes.find((b) => b.id === config?.boxId);

  const cartons = Number(cartonsProduced) || 0;
  const boxesNeeded = config ? cartons * config.boxesPerCarton : 0;
  const packetsNeeded = config ? boxesNeeded * config.packetsPerBox : 0;

  const insufficientWrapper = wrapper ? packetsNeeded > wrapper.stockQty : false;
  const insufficientBox = box ? boxesNeeded > box.stockQty : false;

  // Preview estimate - mirrors the store's internal calculation
  const preview = useMemo(() => {
    if (!batch || !config || !wrapper || !box || cartons <= 0) return null;
    const nominalKgPerPacket = 0.05;
    const estimatedKgNeeded = packetsNeeded * nominalKgPerPacket;
    const bulkKgUsed = Math.min(estimatedKgNeeded, batch.leftoverQtyKg);
    const bulkCostShare = batch.bulkCostPerKg * bulkKgUsed;
    const costPerPacket = packetsNeeded > 0 ? bulkCostShare / packetsNeeded + wrapper.unitCost : wrapper.unitCost;
    const costPerBox = config.packetsPerBox * costPerPacket + box.unitCost;
    const costPerCarton = config.boxesPerCarton * costPerBox;
    return { bulkKgUsed, costPerPacket, costPerBox, costPerCarton };
  }, [batch, config, wrapper, box, cartons, packetsNeeded]);
"@

$newBlock = @"
  const [cartonsProduced, setCartonsProduced] = useState("10");

  const batch = productionBatches.find((b) => b.id === batchId);
  const config = cartonConfigurations.find((c) => c.id === configId);
  const wrapper = wrappers.find((w) => w.id === config?.wrapperId);
  const box = boxes.find((b) => b.id === config?.boxId);

  const cartons = Number(cartonsProduced) || 0;
  const boxesNeeded = config ? cartons * config.boxesPerCarton : 0;
  const packetsNeeded = config ? boxesNeeded * config.packetsPerBox : 0;

  const insufficientWrapper = wrapper ? packetsNeeded > wrapper.stockQty : false;
  const insufficientBox = box ? boxesNeeded > box.stockQty : false;

  // Preview estimate - mirrors the store's internal calculation
  // IMPORTANT: this hook must run on every render (even when the dialog is
  // closed) - never put a conditional "return null" before a hook call.
  const preview = useMemo(() => {
    if (!open || !batch || !config || !wrapper || !box || cartons <= 0) return null;
    const nominalKgPerPacket = 0.05;
    const estimatedKgNeeded = packetsNeeded * nominalKgPerPacket;
    const bulkKgUsed = Math.min(estimatedKgNeeded, batch.leftoverQtyKg);
    const bulkCostShare = batch.bulkCostPerKg * bulkKgUsed;
    const costPerPacket = packetsNeeded > 0 ? bulkCostShare / packetsNeeded + wrapper.unitCost : wrapper.unitCost;
    const costPerBox = config.packetsPerBox * costPerPacket + box.unitCost;
    const costPerCarton = config.boxesPerCarton * costPerBox;
    return { bulkKgUsed, costPerPacket, costPerBox, costPerCarton };
  }, [open, batch, config, wrapper, box, cartons, packetsNeeded]);

  if (!open) return null;
"@

if ($content -notmatch [regex]::Escape('if (!open) return null;')) {
    Write-Host "Could not find the expected block - the file may already be fixed or has changed." -ForegroundColor Yellow
    exit 0
}

$updated = $content.Replace($oldBlock, $newBlock)

if ($updated -eq $content) {
    Write-Host "No changes made - the target block text did not match exactly (file may already be patched)." -ForegroundColor Yellow
    exit 0
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($TargetFile, $updated, $utf8NoBom)

Write-Host "Fixed: apps\frontend\app\(dashboard)\finished-cartons\page.tsx" -ForegroundColor Green
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Please review with 'git diff', then commit and redeploy to Vercel." -ForegroundColor Yellow