<#
  fix-invoice-creation-bug-v2.ps1
  Purpose: REAL fix for "Failed to load resource: 500 ... Error: finished
  carton not found" when saving a New Invoice.

  Root cause (confirmed from apps/backend/supabase/migrations/0002_functions.sql):

    fn_create_invoice() reads each line's item id as:
      (v_line->>'finishedCartonId')::uuid

    It does NOT read 'itemId', 'item_id', or any snake_case variant of the
    item id. The previous fix (fix-invoice-creation-bug.ps1) sent itemId +
    item_id, but never finishedCartonId - so the JSON lookup always
    returned NULL, and the function always raised "finished carton not
    found", even for a valid, in-stock item.

    The SQL function also reads plain 'qty' and 'unitPrice' (already sent
    correctly) and does NOT read priceSourceNote at all (it builds its own
    note server-side), so that field is dropped as unnecessary payload.

    Bonus bug also fixed here: createInvoice() falls back to
    `data.invoiceId` when `data.invoiceNumber` is missing, but the SQL
    function never returns a field called invoiceId - it returns `id`.
    Fixed to fall back to `data.id`.

  This script REPLACES the createInvoice() block in
  apps/frontend/lib/store.ts (handles both the already-patched dual-key
  version and the original pre-patch version, whichever is present).

  Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\fix-invoice-creation-bug-v2.ps1
    .\fix-invoice-creation-bug-v2.ps1 -WhatIf
#>

param(
    [switch]$WhatIf
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

Write-Step "[1/1] Fixing createInvoice() in apps/frontend/lib/store.ts..."

$storePath = Join-Path $root "apps\frontend\lib\store.ts"
if (-not (Test-Path -LiteralPath $storePath)) {
    Write-Fail "Not found: $storePath"
    exit 1
}

$original = Get-Content -LiteralPath $storePath -Raw -Encoding UTF8
$content = $original

$newBlock = "createInvoice: async (input) => {`r`n    // fn_create_invoice (apps/backend/supabase/migrations/0002_functions.sql)`r`n    // reads each line as v_line->>'finishedCartonId', v_line->>'qty',`r`n    // v_line->>'unitPrice'. It does NOT read itemId / item_id / unit_price /`r`n    // priceSourceNote - sending those instead of finishedCartonId is exactly`r`n    // why every invoice failed with `"finished carton not found`".`r`n    const normalizedLines = input.lines.map((l) => ({`r`n      finishedCartonId: l.itemId,`r`n      qty: l.qty,`r`n      unitPrice: l.unitPrice,`r`n    }));`r`n    const { data, error } = await supabase.rpc(`"fn_create_invoice`", {`r`n      p_customer_id: input.customerId,`r`n      p_lines: normalizedLines,`r`n    });`r`n    if (error || !data) throw new Error(error?.message ?? `"Failed to create invoice`");`r`n    await Promise.all([get().loadCustomersModule(), get().loadFinishedCartons()]);`r`n    return (data as any).invoiceNumber ?? (data as any).id;`r`n  },"

# Case A: the already-patched dual-key version (from fix-invoice-creation-bug.ps1)
$patchedBlock = "createInvoice: async (input) => {`r`n    // Send both camelCase and snake_case keys per line - the DB / RPC side`r`n    // uses snake_case column names everywhere else in this project, but the`r`n    // frontend's own domain type is camelCase. Sending both avoids a silent`r`n    // key-name mismatch causing `"finished carton not found`" even when a`r`n    // valid, in-stock item was selected.`r`n    const normalizedLines = input.lines.map((l) => ({`r`n      itemId: l.itemId,`r`n      item_id: l.itemId,`r`n      qty: l.qty,`r`n      unitPrice: l.unitPrice,`r`n      unit_price: l.unitPrice,`r`n      priceSourceNote: l.priceSourceNote,`r`n      price_source_note: l.priceSourceNote,`r`n    }));`r`n    const { data, error } = await supabase.rpc(`"fn_create_invoice`", {`r`n      p_customer_id: input.customerId,`r`n      p_lines: normalizedLines,`r`n    });`r`n    if (error || !data) throw new Error(error?.message ?? `"Failed to create invoice`");`r`n    await Promise.all([get().loadCustomersModule(), get().loadFinishedCartons()]);`r`n    return (data as any).invoiceNumber ?? (data as any).invoiceId;`r`n  },"

# Case B: the original pre-patch version (never had fix-invoice-creation-bug.ps1 applied)
$originalBlock = "createInvoice: async (input) => {`r`n    const { data, error } = await supabase.rpc(`"fn_create_invoice`", {`r`n      p_customer_id: input.customerId,`r`n      p_lines: input.lines,`r`n    });`r`n    if (error || !data) throw new Error(error?.message ?? `"Failed to create invoice`");`r`n    await Promise.all([get().loadCustomersModule(), get().loadFinishedCartons()]);`r`n    return (data as any).invoiceNumber ?? (data as any).invoiceId;`r`n  },"

if ($content.Contains($patchedBlock)) {
    $content = $content.Replace($patchedBlock, $newBlock)
    Write-Ok "Found the dual-key (previously patched) version - replacing with correct fix."
}
elseif ($content.Contains($originalBlock)) {
    $content = $content.Replace($originalBlock, $newBlock)
    Write-Ok "Found the original (pre-patch) version - replacing with correct fix."
}
else {
    Write-Fail "Expected createInvoice block not found verbatim (file may have changed since last known version)."
    Write-Host "  No changes made. Paste current apps/frontend/lib/store.ts createInvoice section for a precise patch." -ForegroundColor Red
    exit 1
}

if ($content -eq $original) {
    Write-Skip "No change needed: $storePath"
}
elseif ($WhatIf) {
    Write-Ok "[WhatIf] Would update: $storePath"
}
else {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($storePath, $content, $utf8NoBom)
    Write-Ok "Updated: $storePath"
}

if (-not $WhatIf) {
    Write-Step "Verifying frontend build..."
    $frontendPath = Join-Path $root "apps\frontend"
    if (Test-Path -LiteralPath $frontendPath) {
        Push-Location $frontendPath
        try {
            npm run build
            if ($LASTEXITCODE -ne 0) { Write-Fail "Frontend build failed - paste the error." }
            else { Write-Ok "Frontend build passed." }
        } finally { Pop-Location }
    }
}
else {
    Write-Step "Skipped build verification (-WhatIf mode)"
}

Write-Host ""
Write-Host "Done. Redeploy the frontend and test creating an invoice again." -ForegroundColor Cyan
Write-Host "This time the RPC payload key names match exactly what fn_create_invoice reads," -ForegroundColor Cyan
Write-Host "so a valid, in-stock item should invoice successfully." -ForegroundColor Cyan