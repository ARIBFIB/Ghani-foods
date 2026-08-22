<#
  fix-invoice-creation-bug.ps1
  Purpose: Fix "Failed to load resource: 500 ... Error: finished carton
  not found" when saving a New Invoice.

  Root cause: apps/frontend/lib/store.ts's createInvoice() calls the
  Postgres RPC fn_create_invoice with p_lines containing camelCase keys
  (itemId, unitPrice, priceSourceNote) - matching the frontend's own
  domain types. Every table/column in this project's actual database is
  snake_case (confirmed by every row-mapper in store.ts converting
  snake_case DB columns -> camelCase JS fields). The SQL function
  fn_create_invoice almost certainly reads each line's item id as
  line->>'item_id' (snake_case, matching DB convention), not 'itemId'.
  That lookup comes back NULL, so its "select ... where id = ..." on
  finished_cartons matches nothing, and the function raises
  "finished carton not found" even though a valid, in-stock item was
  selected in the UI.

  Fix: send BOTH camelCase and snake_case keys for every line, so the
  RPC finds a match regardless of which convention its SQL body reads.
  Extra unused JSON keys are harmless to a Postgres function reading
  jsonb - this is a safe, non-breaking change.

  NOTE: this script cannot see or edit the actual SQL function
  (fn_create_invoice lives in your Supabase project's migrations,
  which weren't included in the code export). If this fix does not
  resolve the error, open Supabase Dashboard -> SQL Editor and run:
    select prosrc from pg_proc where proname = 'fn_create_invoice';
  to see exactly which JSON keys the function reads, and paste that
  back for a precise fix.

  Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\fix-invoice-creation-bug.ps1
    .\fix-invoice-creation-bug.ps1 -WhatIf
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

$oldBlock = "createInvoice: async (input) => {`r`n    const { data, error } = await supabase.rpc(`"fn_create_invoice`", {`r`n      p_customer_id: input.customerId,`r`n      p_lines: input.lines,`r`n    });"

$newBlock = "createInvoice: async (input) => {`r`n    // Send both camelCase and snake_case keys per line - the DB / RPC side`r`n    // uses snake_case column names everywhere else in this project, but the`r`n    // frontend's own domain type is camelCase. Sending both avoids a silent`r`n    // key-name mismatch causing `"finished carton not found`" even when a`r`n    // valid, in-stock item was selected.`r`n    const normalizedLines = input.lines.map((l) => ({`r`n      itemId: l.itemId,`r`n      item_id: l.itemId,`r`n      qty: l.qty,`r`n      unitPrice: l.unitPrice,`r`n      unit_price: l.unitPrice,`r`n      priceSourceNote: l.priceSourceNote,`r`n      price_source_note: l.priceSourceNote,`r`n    }));`r`n    const { data, error } = await supabase.rpc(`"fn_create_invoice`", {`r`n      p_customer_id: input.customerId,`r`n      p_lines: normalizedLines,`r`n    });"

if ($content.Contains($oldBlock)) {
    $content = $content.Replace($oldBlock, $newBlock)
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
Write-Host "Done. Test creating an invoice again after deploying." -ForegroundColor Cyan
Write-Host "If it STILL fails with 'finished carton not found', the SQL function needs a direct look -" -ForegroundColor Yellow
Write-Host "run this in Supabase SQL Editor and share the output:" -ForegroundColor Yellow
Write-Host "  select prosrc from pg_proc where proname = 'fn_create_invoice';" -ForegroundColor Yellow