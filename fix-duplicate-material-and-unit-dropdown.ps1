<#
  fix-duplicate-material-and-unit-dropdown.ps1
  -----------------------------------------------
  Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  Fixes two client-reported issues:

  1) DUPLICATE RAW MATERIALS BUG (critical)
     File: apps/frontend/components/ui/purchase-receipt-dialog.tsx
     When a purchase receipt had two "new material" lines with the same
     new name, the second line didn't see the material created by the
     first line (React state hadn't re-rendered yet inside the same
     submit loop), so it created a second duplicate raw_materials row.
     Fix: track names created during this submit in a local map, checked
     alongside the existing rawMaterials list.

  2) UNIT DROPDOWN (data quality)
     File: apps/frontend/app/(dashboard)/raw-materials/page.tsx
     "Unit" was a free-text input (kg, Kg, KG, kilogram... all different
     strings). Replaced with a fixed dropdown: kg, g, litre, ml, piece.

  Safe to re-run - already-fixed files are skipped.
#>

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Apply-Fix {
    param([string]$RelativePath, [string]$OldBlock, [string]$NewBlock, [string]$AlreadyFixedMarker)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "ERROR: Could not find $path" -ForegroundColor Red
        return
    }
    $content = Get-Content -Raw -LiteralPath $path
    if ($content -match [regex]::Escape($AlreadyFixedMarker)) {
        Write-Host "$RelativePath already fixed - skipping." -ForegroundColor Yellow
        return
    }
    if ($content -notmatch [regex]::Escape($OldBlock.Trim())) {
        Write-Host "ERROR: Expected block not found in $RelativePath - skipping (check by hand)." -ForegroundColor Red
        return
    }
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    $fixed = $content.Replace($OldBlock.Trim(), $NewBlock.Trim())
    Set-Content -LiteralPath $path -Value $fixed -NoNewline
    Write-Host "Fixed: $RelativePath" -ForegroundColor Green
}

# ---------------------------------------------------------------------
# 1) Duplicate raw material bug
# ---------------------------------------------------------------------
$oldDialog = @'
      if (row.mode === "new") {
        if (!row.newName.trim()) {
          setFormError("Enter a name for the new raw material");
          return;
        }
        if (!row.newUnit.trim()) {
          setFormError("Enter a unit for the new raw material");
          return;
        }
        const existing = rawMaterials.find(
          (m) => m.name.toLowerCase() === row.newName.trim().toLowerCase()
        );
        let newId = existing?.id;
        if (!newId) {
          try {
            newId = await addRawMaterial({
              name: row.newName.trim(),
              unit: row.newUnit.trim(),
              lowStockThreshold: Number(row.newThreshold) || 0,
            });
          } catch (err) {
            setFormError(err instanceof Error ? err.message : "Could not create the new raw material");
            return;
          }
        }
        if (!newId) {
          setFormError("Could not create the new raw material");
          return;
        }
        parsedItems.push({ rawMaterialId: newId, qty, cost });
'@

$newDialog = @'
      if (row.mode === "new") {
        if (!row.newName.trim()) {
          setFormError("Enter a name for the new raw material");
          return;
        }
        if (!row.newUnit.trim()) {
          setFormError("Enter a unit for the new raw material");
          return;
        }
        const nameKey = row.newName.trim().toLowerCase();
        const existing = rawMaterials.find((m) => m.name.toLowerCase() === nameKey);
        let newId = existing?.id ?? createdThisSubmit.get(nameKey);
        if (!newId) {
          try {
            newId = await addRawMaterial({
              name: row.newName.trim(),
              unit: row.newUnit.trim(),
              lowStockThreshold: Number(row.newThreshold) || 0,
            });
            createdThisSubmit.set(nameKey, newId);
          } catch (err) {
            setFormError(err instanceof Error ? err.message : "Could not create the new raw material");
            return;
          }
        }
        if (!newId) {
          setFormError("Could not create the new raw material");
          return;
        }
        parsedItems.push({ rawMaterialId: newId, qty, cost });
'@

$oldLoopStart = @'
    const parsedItems: { rawMaterialId: string; qty: number; cost: number }[] = [];

    for (const row of rows) {
'@
$newLoopStart = @'
    const parsedItems: { rawMaterialId: string; qty: number; cost: number }[] = [];
    // Tracks new-material names created earlier in *this* submit so a second
    // line with the same new name reuses the id instead of creating a duplicate
    // raw_materials row (rawMaterials from the store won't reflect the insert
    // until the next render, which is too late for this loop).
    const createdThisSubmit = new Map<string, string>();

    for (const row of rows) {
'@

$dialogPath = 'apps\frontend\components\ui\purchase-receipt-dialog.tsx'
$fullPath = Join-Path $root $dialogPath
if (Test-Path -LiteralPath $fullPath) {
    $content = Get-Content -Raw -LiteralPath $fullPath
    if ($content -match [regex]::Escape('createdThisSubmit')) {
        Write-Host "$dialogPath already fixed - skipping." -ForegroundColor Yellow
    }
    elseif ($content -notmatch [regex]::Escape($oldLoopStart.Trim()) -or $content -notmatch [regex]::Escape($oldDialog.Trim())) {
        Write-Host "ERROR: Expected blocks not found in $dialogPath - skipping (check by hand)." -ForegroundColor Red
    }
    else {
        Copy-Item -LiteralPath $fullPath -Destination "$fullPath.bak-$stamp"
        $fixed = $content.Replace($oldLoopStart.Trim(), $newLoopStart.Trim())
        $fixed = $fixed.Replace($oldDialog.Trim(), $newDialog.Trim())
        Set-Content -LiteralPath $fullPath -Value $fixed -NoNewline
        Write-Host "Fixed: $dialogPath (duplicate raw material bug)" -ForegroundColor Green
    }
} else {
    Write-Host "ERROR: Could not find $fullPath" -ForegroundColor Red
}

# ---------------------------------------------------------------------
# 2) Unit dropdown on raw-materials/page.tsx
# ---------------------------------------------------------------------
$oldUnit = @'
            <input {...register("unit")} placeholder="kg, g, litre..."
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
'@
$newUnit = @'
            <select {...register("unit")}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
              <option value="kg">kg</option>
              <option value="g">g</option>
              <option value="litre">litre</option>
              <option value="ml">ml</option>
              <option value="piece">piece</option>
            </select>
'@
Apply-Fix -RelativePath 'apps\frontend\app\(dashboard)\raw-materials\page.tsx' -OldBlock $oldUnit -NewBlock $newUnit -AlreadyFixedMarker '<option value="piece">piece</option>'

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd apps\frontend; npm run dev"
Write-Host "  2. Test: create a purchase receipt with TWO new-material lines"
Write-Host "     using the SAME new material name -> confirm only ONE row is"
Write-Host "     created in raw_materials (check the Raw Materials list)."
Write-Host "  3. Test: Add Raw Material -> Unit should now be a dropdown."