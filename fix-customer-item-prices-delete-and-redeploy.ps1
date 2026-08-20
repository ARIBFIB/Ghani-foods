#
# fix-customer-item-prices-delete-and-redeploy.ps1
# ----------------------------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes: "Delete failed for customer_item_prices: column
# customer_item_prices.id does not exist"
#
# ROOT CAUSE: per 0001_init_schema.sql, customer_item_prices has a
# COMPOSITE primary key (customer_id, item_id) - it has no "id" column.
# The delete loop in data-delete/index.ts assumed every table has an
# "id" column and used `.delete().not("id", "is", null)` for all of them.
#
# FIX: special-case customer_item_prices to delete-all using its
# customer_id column instead.
#
# Safe to re-run.
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
        Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
    } else {
        Write-Host "  ERROR: File not found: $path" -ForegroundColor Red
        exit 1
    }
}

$deleteFnPath = Join-Path $root "apps\backend\supabase\functions\data-delete\index.ts"
if (-not (Test-Path -LiteralPath $deleteFnPath)) {
    Write-Host "ERROR: Could not find $deleteFnPath" -ForegroundColor Red
    exit 1
}

$content = Get-Content -Raw -LiteralPath $deleteFnPath

# -----------------------------------------------------------------
# 1. Fix the BACKUP fetch loop's sheet naming (unaffected - select("*")
#    works fine without an id column) - no change needed there.
#
# 2. Fix the DELETE loop to special-case customer_item_prices.
# -----------------------------------------------------------------
$oldDeleteLoop = 'for (const table of DELETE_ORDER) {
      const count = snapshots[table]?.length ?? 0;
      // Delete-all trick: match a condition that''s always true for the primary key.
      const { error } = await supabase.from(table).delete().not("id", "is", null);
      if (error) throw new Error(`Delete failed for ${table}: ${error.message}`);
      deleted[table] = count;
    }'

$newDeleteLoop = 'for (const table of DELETE_ORDER) {
      const count = snapshots[table]?.length ?? 0;
      // Delete-all trick: match a condition that''s always true for the primary key.
      // customer_item_prices has a COMPOSITE primary key (customer_id, item_id) -
      // it has no "id" column, so it needs a different always-true condition.
      const { error } =
        table === "customer_item_prices"
          ? await supabase.from(table).delete().not("customer_id", "is", null)
          : await supabase.from(table).delete().not("id", "is", null);
      if (error) throw new Error(`Delete failed for ${table}: ${error.message}`);
      deleted[table] = count;
    }'

if ($content -match [regex]::Escape('table === "customer_item_prices"')) {
    Write-Host "data-delete/index.ts already has the customer_item_prices fix - skipping." -ForegroundColor Yellow
}
elseif ($content -match [regex]::Escape($oldDeleteLoop)) {
    Backup-File $deleteFnPath
    $updated = $content.Replace($oldDeleteLoop, $newDeleteLoop)
    Set-Content -LiteralPath $deleteFnPath -Value $updated -NoNewline
    Write-Host "data-delete/index.ts -> delete loop now special-cases customer_item_prices." -ForegroundColor Green
}
else {
    Write-Host "ERROR: Could not find the expected delete loop block." -ForegroundColor Red
    Write-Host "Open the file and check it manually: $deleteFnPath" -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------
# Redeploy
# -----------------------------------------------------------------
$backendDir = Join-Path $root "apps\backend"
Push-Location $backendDir
try {
    Write-Host ""
    Write-Host "Deploying data-delete..." -ForegroundColor Cyan
    & supabase functions deploy data-delete --no-verify-jwt
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Hard-refresh https://ghani-foods.vercel.app/settings?tab=export (Ctrl+Shift+R) and try Delete All Data again." -ForegroundColor Green
Write-Host ""
Write-Host "NOTE: if a NEW error appears (missing column/table), share it and" -ForegroundColor Yellow
Write-Host "I'll fix that one too." -ForegroundColor Yellow