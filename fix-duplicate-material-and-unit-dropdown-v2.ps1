<#
  fix-duplicate-material-and-unit-dropdown-v2.ps1
  ---------------------------------------------------
  Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  Same two fixes as before, rewritten to be safe against CRLF vs LF line
  ending mismatches (which is why v1 failed to find the blocks).

  1) Duplicate raw materials bug in purchase-receipt-dialog.tsx
  2) Unit dropdown in raw-materials/page.tsx

  Safe to re-run - already-fixed files are skipped.
#>

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Normalize([string]$s) {
    return $s -replace "`r`n", "`n"
}

function Apply-Fix {
    param([string]$RelativePath, [string]$OldBlock, [string]$NewBlock, [string]$AlreadyFixedMarker)

    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "ERROR: Could not find $path" -ForegroundColor Red
        return
    }

    $raw = Get-Content -Raw -LiteralPath $path
    $usesCrlf = $raw -match "`r`n"
    $norm = Normalize $raw

    if ($norm -match [regex]::Escape($AlreadyFixedMarker)) {
        Write-Host "$RelativePath already fixed - skipping." -ForegroundColor Yellow
        return $true
    }

    $oldNorm = (Normalize $OldBlock).Trim()
    $newNorm = (Normalize $NewBlock).Trim()

    if ($norm -notmatch [regex]::Escape($oldNorm)) {
        Write-Host "ERROR: Expected block not found in $RelativePath - skipping (check by hand)." -ForegroundColor Red
        return $false
    }

    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"

    $fixedNorm = $norm.Replace($oldNorm, $newNorm)
    if ($usesCrlf) {
        $fixedOut = $fixedNorm -replace "`n", "`r`n"
    } else {
        $fixedOut = $fixedNorm
    }

    Set-Content -LiteralPath $path -Value $fixedOut -NoNewline
    Write-Host "Fixed: $RelativePath" -ForegroundColor Green
    return $true
}

# ---------------------------------------------------------------------
# 1) Duplicate raw material bug - two separate small edits
# ---------------------------------------------------------------------
$dialogPath = 'apps\frontend\components\ui\purchase-receipt-dialog.tsx'
$fullPath = Join-Path $root $dialogPath

if (-not (Test-Path -LiteralPath $fullPath)) {
    Write-Host "ERROR: Could not find $fullPath" -ForegroundColor Red
} else {
    $raw = Get-Content -Raw -LiteralPath $fullPath
    $usesCrlf = $raw -match "`r`n"
    $norm = Normalize $raw

    if ($norm -match [regex]::Escape('createdThisSubmit')) {
        Write-Host "$dialogPath already fixed - skipping." -ForegroundColor Yellow
    } else {
        $oldLoopStart = (Normalize @'
    const parsedItems: { rawMaterialId: string; qty: number; cost: number }[] = [];

    for (const row of rows) {
'@).Trim()

        $newLoopStart = (Normalize @'
    const parsedItems: { rawMaterialId: string; qty: number; cost: number }[] = [];
    // Tracks new-material names created earlier in *this* submit so a second
    // line with the same new name reuses the id instead of creating a duplicate
    // raw_materials row (rawMaterials from the store won't reflect the insert
    // until the next render, which is too late for this loop).
    const createdThisSubmit = new Map<string, string>();

    for (const row of rows) {
'@).Trim()

        $oldExisting = (Normalize @'
        const existing = rawMaterials.find(
          (m) => m.name.toLowerCase() === row.newName.trim().toLowerCase()
        );
        let newId = existing?.id;
'@).Trim()

        $newExisting = (Normalize @'
        const nameKey = row.newName.trim().toLowerCase();
        const existing = rawMaterials.find((m) => m.name.toLowerCase() === nameKey);
        let newId = existing?.id ?? createdThisSubmit.get(nameKey);
'@).Trim()

        $oldCreate = (Normalize @'
            newId = await addRawMaterial({
              name: row.newName.trim(),
              unit: row.newUnit.trim(),
              lowStockThreshold: Number(row.newThreshold) || 0,
            });
'@).Trim()

        $newCreate = (Normalize @'
            newId = await addRawMaterial({
              name: row.newName.trim(),
              unit: row.newUnit.trim(),
              lowStockThreshold: Number(row.newThreshold) || 0,
            });
            createdThisSubmit.set(nameKey, newId);
'@).Trim()

        $missing = @()
        if ($norm -notmatch [regex]::Escape($oldLoopStart)) { $missing += "loop start" }
        if ($norm -notmatch [regex]::Escape($oldExisting)) { $missing += "existing check" }
        if ($norm -notmatch [regex]::Escape($oldCreate)) { $missing += "addRawMaterial call" }

        if ($missing.Count -gt 0) {
            Write-Host "ERROR: Could not find: $($missing -join ', ') in $dialogPath - skipping (check by hand)." -ForegroundColor Red
        } else {
            Copy-Item -LiteralPath $fullPath -Destination "$fullPath.bak-$stamp"
            $fixed = $norm.Replace($oldLoopStart, $newLoopStart)
            $fixed = $fixed.Replace($oldExisting, $newExisting)
            $fixed = $fixed.Replace($oldCreate, $newCreate)
            if ($usesCrlf) { $fixed = $fixed -replace "`n", "`r`n" }
            Set-Content -LiteralPath $fullPath -Value $fixed -NoNewline
            Write-Host "Fixed: $dialogPath (duplicate raw material bug)" -ForegroundColor Green
        }
    }
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
Apply-Fix -RelativePath 'apps\frontend\app\(dashboard)\raw-materials\page.tsx' -OldBlock $oldUnit -NewBlock $newUnit -AlreadyFixedMarker '<option value="piece">piece</option>' | Out-Null

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd apps\frontend; npm run dev"
Write-Host "  2. Test: create a purchase receipt with TWO new-material lines"
Write-Host "     using the SAME new material name -> confirm only ONE row is"
Write-Host "     created in raw_materials (check the Raw Materials list)."
Write-Host "  3. Test: Add Raw Material -> Unit should now be a dropdown."