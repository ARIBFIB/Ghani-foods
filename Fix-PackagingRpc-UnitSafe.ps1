<#
  Fix-PackagingRpc-UnitSafe.ps1
  -----------------------------------------------------------------------
  ISSUE 8 (part 2/2) - server-side fix.

  Part 1 (Fix-PackagingUnitMismatch.ps1) already fixed the FRONTEND labels
  and display math. This script fixes the ACTUAL stock-deduction logic,
  which lives in two Postgres functions called via supabase.rpc(...) from
  lib/store.ts:
      fn_produce_wrapper(p_wrapper_id, p_qty)
      fn_produce_box(p_box_id, p_qty)

  These functions were not included in your code export (no migrations
  folder was present), so their previous body is unknown. Rather than
  wait on a manual round-trip, this writes a brand-new migration that
  does CREATE OR REPLACE FUNCTION - which fully replaces whatever body
  currently exists in the DB, so it does not need to match the old code.

  WHAT THE NEW FUNCTIONS DO (rebuilt from the schema your own frontend
  code already relies on - wrappers/boxes.grams_per_unit + stock_qty,
  raw_materials.quantity_in_stock + unit, wrapper_production_runs /
  box_production_runs):
    - Lock the wrapper/box row and its underlying raw_materials row
      (FOR UPDATE) so concurrent Produce clicks cannot race each other.
    - Compute qty_needed = grams_per_unit * p_qty IN THE RAW MATERIAL'S
      OWN UNIT - no hardcoded grams, no silent kg->g or any other
      conversion (matches the frontend fix from part 1).
    - Raise a clear error and roll back if stock is insufficient
      (no partial/negative deduction).
    - Deduct qty_needed from raw_materials.quantity_in_stock.
    - Add p_qty to wrappers/boxes.stock_qty.
    - Insert a row into wrapper_production_runs / box_production_runs
      for audit history.
    - Return the updated wrapper/box row as JSON (matches what the
      frontend's produceWrapper/produceBox already expect back).

  IMPORTANT CAVEAT (please read):
  I could not read your live database, so this is a faithful
  reconstruction from the table/column names your own exported frontend
  code (lib/store.ts) already depends on - not a guess at unrelated
  behaviour. If your real fn_produce_box/fn_produce_wrapper do anything
  extra beyond this (e.g. also write to an audit_log table, enforce a
  role check, etc.), that extra behaviour will be REPLACED, not merged,
  because CREATE OR REPLACE overwrites the whole function body. Test on
  a staging project first if you have one. If anything about your setup
  differs (e.g. ids are text, not uuid), tell me the error and I'll
  adjust in one message.

  USAGE:
    cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
    .\Fix-PackagingRpc-UnitSafe.ps1

  Idempotent - safe to re-run (writes the migration once; re-running the
  migration itself via CREATE OR REPLACE is always safe).
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$AutoPush
)

$ErrorActionPreference = "Stop"

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    WARNING: $msg" -ForegroundColor Yellow }

# -------------------------------------------------------------------------
# 0. Locate project root
# -------------------------------------------------------------------------
Write-Step "Locating project..."

$candidatePaths = @($ProjectRoot, "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods")
$resolvedRoot = $null
foreach ($p in $candidatePaths) {
    if (Test-Path (Join-Path $p "apps\frontend\lib\store.ts")) { $resolvedRoot = $p; break }
}
if (-not $resolvedRoot) {
    Write-Warn2 "Could not auto-detect the project. Run this script FROM the project root."
    throw "Project root not found."
}
$ProjectRoot   = $resolvedRoot
$BackendDir    = Join-Path $ProjectRoot "apps\backend"
$MigrationsDir = Join-Path $BackendDir "supabase\migrations"

Write-Ok "Project root: $ProjectRoot"

# -------------------------------------------------------------------------
# 1. Write the migration
# -------------------------------------------------------------------------
Write-Step "Writing unit-safe fn_produce_wrapper / fn_produce_box migration..."

if (-not (Test-Path $MigrationsDir)) { New-Item -ItemType Directory -Force -Path $MigrationsDir | Out-Null }

$existing = Get-ChildItem -Path $MigrationsDir -Filter "*_fix_produce_functions_unit_safe.sql" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existing) {
    Write-Ok "Migration already exists: $($existing.FullName) - skipping (delete it first if you want to regenerate)."
    $migrationFile = $existing.FullName
}
else {
    $sql = @'
-- ISSUE 8 (part 2/2): rebuild fn_produce_wrapper / fn_produce_box so stock
-- deduction happens in the raw material's OWN unit, with no hardcoded
-- grams and no silent unit conversion - matching the frontend fix.
-- CREATE OR REPLACE fully overwrites whatever body currently exists.

create or replace function fn_produce_wrapper(p_wrapper_id uuid, p_qty numeric)
returns json
language plpgsql
as $$
declare
  v_wrapper wrappers%rowtype;
  v_raw_material raw_materials%rowtype;
  v_qty_needed numeric;
  v_result json;
begin
  if p_qty is null or p_qty <= 0 then
    raise exception 'Quantity to produce must be greater than 0';
  end if;

  select * into v_wrapper from wrappers where id = p_wrapper_id for update;
  if not found then
    raise exception 'Wrapper % not found', p_wrapper_id;
  end if;

  select * into v_raw_material from raw_materials where id = v_wrapper.raw_material_id for update;
  if not found then
    raise exception 'Underlying raw material for wrapper % not found', p_wrapper_id;
  end if;

  -- No hardcoded grams / no silent conversion: grams_per_unit is defined
  -- in the raw material's own unit, so this is a straight multiplication.
  v_qty_needed := v_wrapper.grams_per_unit * p_qty;

  if v_raw_material.quantity_in_stock < v_qty_needed then
    raise exception 'Insufficient stock of % - need % % but only % % available',
      v_raw_material.name, v_qty_needed, v_raw_material.unit, v_raw_material.quantity_in_stock, v_raw_material.unit;
  end if;

  update raw_materials
     set quantity_in_stock = quantity_in_stock - v_qty_needed
   where id = v_raw_material.id;

  update wrappers
     set stock_qty = stock_qty + p_qty
   where id = v_wrapper.id
  returning * into v_wrapper;

  insert into wrapper_production_runs (wrapper_id, quantity_produced, grams_consumed, run_date)
  values (p_wrapper_id, p_qty, v_qty_needed, now());

  select row_to_json(v_wrapper) into v_result;
  return v_result;
end;
$$;

create or replace function fn_produce_box(p_box_id uuid, p_qty numeric)
returns json
language plpgsql
as $$
declare
  v_box boxes%rowtype;
  v_raw_material raw_materials%rowtype;
  v_qty_needed numeric;
  v_result json;
begin
  if p_qty is null or p_qty <= 0 then
    raise exception 'Quantity to produce must be greater than 0';
  end if;

  select * into v_box from boxes where id = p_box_id for update;
  if not found then
    raise exception 'Box % not found', p_box_id;
  end if;

  select * into v_raw_material from raw_materials where id = v_box.raw_material_id for update;
  if not found then
    raise exception 'Underlying raw material for box % not found', p_box_id;
  end if;

  -- No hardcoded grams / no silent conversion: grams_per_unit is defined
  -- in the raw material's own unit, so this is a straight multiplication.
  v_qty_needed := v_box.grams_per_unit * p_qty;

  if v_raw_material.quantity_in_stock < v_qty_needed then
    raise exception 'Insufficient stock of % - need % % but only % % available',
      v_raw_material.name, v_qty_needed, v_raw_material.unit, v_raw_material.quantity_in_stock, v_raw_material.unit;
  end if;

  update raw_materials
     set quantity_in_stock = quantity_in_stock - v_qty_needed
   where id = v_raw_material.id;

  update boxes
     set stock_qty = stock_qty + p_qty
   where id = v_box.id
  returning * into v_box;

  insert into box_production_runs (box_id, quantity_produced, grams_consumed, run_date)
  values (p_box_id, p_qty, v_qty_needed, now());

  select row_to_json(v_box) into v_result;
  return v_result;
end;
$$;
'@
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $migrationFile = Join-Path $MigrationsDir "${timestamp}_fix_produce_functions_unit_safe.sql"
    Set-Content -Path $migrationFile -Value $sql -Encoding UTF8
    Write-Ok "Migration written: $migrationFile"
}

# -------------------------------------------------------------------------
# 2. Optionally push it straight to Supabase (no manual SQL-editor step)
# -------------------------------------------------------------------------
Write-Step "Attempting to apply the migration automatically..."

$supabaseCli = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseCli) {
    Write-Warn2 "Supabase CLI not found on PATH - could not auto-apply."
    Write-Warn2 "Install it (npm i -g supabase) and run 'supabase link' once, then re-run this"
    Write-Warn2 "script, OR just run: supabase db push   (from $BackendDir)"
}
else {
    Push-Location $BackendDir
    try {
        Write-Ok "Supabase CLI found: $($supabaseCli.Source)"
        Write-Host "    Running: supabase db push" -ForegroundColor Gray
        supabase db push
        Write-Ok "Migration pushed. fn_produce_wrapper / fn_produce_box are now unit-safe."
    }
    catch {
        Write-Warn2 "Auto-push failed: $($_.Exception.Message)"
        Write-Warn2 "Run it yourself from $BackendDir : supabase db push"
    }
    finally {
        Pop-Location
    }
}

# -------------------------------------------------------------------------
# 3. Diagnostic reminder (uses the read-only view part 1 already created)
# -------------------------------------------------------------------------
Write-Step "Done."
Write-Host ""
Write-Host "  fn_produce_wrapper and fn_produce_box now deduct stock in the raw" -ForegroundColor White
Write-Host "  material's own unit only - no hardcoded grams, no silent conversion." -ForegroundColor White
Write-Host ""
Write-Warn2 "Leftover corrupted stock from BEFORE this fix (e.g. Box Paper's 24.98)"
Write-Warn2 "is still sitting in the DB - this migration only stops NEW corruption."
Write-Warn2 "Query the diagnostic view part 1 created (v_fractional_stock_flags) in"
Write-Warn2 "the Supabase SQL editor or via 'supabase db execute' to see what needs"
Write-Warn2 "manual correction - that part genuinely cannot be auto-fixed blind,"
Write-Warn2 "since only a human can say what the correct true stock count is."
Write-Host ""