<#
  wire-raw-materials-module-part2.ps1
  Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
  Fixes the 4 SKIPs from wire-raw-materials-module.ps1. Those were not
  "file not found" - PowerShell's Test-Path/Get-Content treat [id] as a
  wildcard pattern, so the [id] folders were never actually checked.
  This version uses -LiteralPath so [id] is matched literally.
#>

$ErrorActionPreference = "Stop"
$Root     = Get-Location
$Frontend = Join-Path $Root "apps\frontend"

function Patch-File {
    param(
        [string]$RelativePath,
        [string]$OldText,
        [string]$NewText,
        [string]$Label
    )
    $Path = Join-Path $Frontend $RelativePath
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "==> SKIP ($Label): file not found -> $RelativePath" -ForegroundColor Red
        return
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    $normalized = $raw -replace "`r`n", "`n"
    $oldNorm = $OldText -replace "`r`n", "`n"
    $newNorm = $NewText -replace "`r`n", "`n"

    if ($normalized.Contains($oldNorm)) {
        $patched = $normalized.Replace($oldNorm, $newNorm)
        Set-Content -LiteralPath $Path -Value $patched -Encoding UTF8 -NoNewline
        Write-Host "==> Patched: $Label" -ForegroundColor Green
    } else {
        Write-Host "==> SKIP ($Label): anchor text not found (already patched or file changed) -> $RelativePath" -ForegroundColor Yellow
    }
}

# ============================================================================
# raw-materials/[id]/page.tsx
# ============================================================================

Patch-File -RelativePath "app\(dashboard)\raw-materials\[id]\page.tsx" -Label "raw-materials/[id]: import useEffect" `
  -OldText 'import { use, useMemo, useState } from "react";' `
  -NewText 'import { use, useEffect, useMemo, useState } from "react";'

Patch-File -RelativePath "app\(dashboard)\raw-materials\[id]\page.tsx" -Label "raw-materials/[id]: hydrate on mount" `
  -OldText @'
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const [dialogOpen, setDialogOpen] = useState(false);
'@ `
  -NewText @'
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);
'@

# ============================================================================
# suppliers/[id]/page.tsx
# ============================================================================

Patch-File -RelativePath "app\(dashboard)\suppliers\[id]\page.tsx" -Label "suppliers/[id]: import useEffect" `
  -OldText 'import { Fragment, use, useMemo, useState } from "react";' `
  -NewText 'import { Fragment, use, useEffect, useMemo, useState } from "react";'

Patch-File -RelativePath "app\(dashboard)\suppliers\[id]\page.tsx" -Label "suppliers/[id]: hydrate on mount" `
  -OldText @'
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
'@ `
  -NewText @'
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);
'@

Write-Host ""
Write-Host "==> DONE. raw-materials/[id] and suppliers/[id] detail pages now hydrate from Supabase too." -ForegroundColor Green
Write-Host "==> If you still see SKIP above, the anchor text in your actual file differs slightly -" -ForegroundColor Yellow
Write-Host "    paste back the current content of that [id]/page.tsx file and it'll be adjusted." -ForegroundColor Yellow