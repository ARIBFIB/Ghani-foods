#
# add-batch-and-monthly-expenses.ps1
# -----------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Adds (BACKEND ONLY - frontend script comes in a follow-up):
#   1. Migration 0007_batch_and_monthly_expenses.sql
#        - batch_expenses table          (per-batch named expenses: labour, misc, etc.)
#        - monthly_expenses table        (accumulative month expenses: electricity, rent, gas)
#        - batch_monthly_overhead_allocations table (FROZEN snapshot of each batch's
#          share once a month is allocated - so future edits/new batches in that
#          month do NOT silently change already-allocated batch costs)
#        - app_settings.overhead_allocation_method column ('equal' | 'proportional_kg')
#        - fn_create_production_batch updated to accept p_other_expenses jsonb
#        - fn_add_batch_expense (add an expense to an existing batch)
#        - fn_allocate_monthly_overhead (equal / proportional_kg allocation, freezes result)
#   2. Backend edge function updates:
#        - batches/index.ts -> passes otherExpenses through to the RPC
#        - NEW batch-expenses/index.ts -> add a named expense to an existing batch
#        - NEW monthly-expenses/index.ts -> CRUD for accumulative monthly expenses
#        - NEW monthly-overhead-allocate/index.ts -> triggers allocation for a month
#
# Safe to re-run - already-applied files are skipped where sensible.
# Backups made before any edit: <file>.bak-<timestamp>
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
        Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
    }
}

function Ensure-Dir($path) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

# ===================================================================
# 1. MIGRATION
# ===================================================================
$migrationsDir = Join-Path $root "apps\backend\supabase\migrations"
if (-not (Test-Path -LiteralPath $migrationsDir)) {
    Write-Host "ERROR: Could not find $migrationsDir - are you in the right folder?" -ForegroundColor Red
    exit 1
}
$migrationPath = Join-Path $migrationsDir "0007_batch_and_monthly_expenses.sql"

if (Test-Path -LiteralPath $migrationPath) {
    Write-Host "0007_batch_and_monthly_expenses.sql already exists - skipping (delete it manually to regenerate)." -ForegroundColor Yellow
}
else {
$migrationSql = @'
-- 0007_batch_and_monthly_expenses.sql
-- ------------------------------------------------------------------
-- Client requirement: raw material cost alone is NOT the batch cost.
-- Labour, electricity, gas, rent etc. must also be reflected, via two
-- routes:
--   (a) per-batch named expenses, added at the same time as the batch
--   (b) accumulative monthly expenses (e.g. "August electricity: 45000")
--       divided across all batches produced that month - either
--       EQUALLY per batch, or PROPORTIONALLY by output_yield_kg.
--       Allocation is FROZEN once run, so later edits to that month's
--       expenses or new batches in that month do not silently change
--       an already-allocated batch's cost. Re-running allocation for
--       the same month replaces the previous (still frozen) snapshot.
-- ------------------------------------------------------------------

-- ===================== SETTINGS =====================
alter table app_settings
  add column if not exists overhead_allocation_method text
    not null default 'equal'
    check (overhead_allocation_method in ('equal', 'proportional_kg'));

-- ===================== PER-BATCH NAMED EXPENSES =====================
create table if not exists batch_expenses (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references production_batches(id) on delete cascade,
  name text not null,
  amount numeric(14,2) not null check (amount >= 0),
  created_at timestamptz not null default now()
);
create index if not exists idx_batch_expenses_batch on batch_expenses(batch_id);

-- ===================== MONTHLY ACCUMULATIVE EXPENSES =====================
create table if not exists monthly_expenses (
  id uuid primary key default gen_random_uuid(),
  month date not null,              -- always stored as first-of-month, e.g. 2026-08-01
  name text not null,               -- "Electricity", "Rent", "Gas", "Labour" etc.
  amount numeric(14,2) not null check (amount >= 0),
  created_at timestamptz not null default now()
);
create index if not exists idx_monthly_expenses_month on monthly_expenses(month);

-- ===================== FROZEN ALLOCATION SNAPSHOT =====================
-- One row per (batch, month) once fn_allocate_monthly_overhead has run.
-- Re-running the function for a month deletes+recreates its rows only
-- (does not touch other months), and updates production_batches.bulk_cost_per_kg
-- by removing the OLD share and applying the NEW share.
create table if not exists batch_monthly_overhead_allocations (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references production_batches(id) on delete cascade,
  month date not null,
  allocation_method text not null check (allocation_method in ('equal', 'proportional_kg')),
  total_month_expense numeric(14,2) not null,
  batch_share numeric(14,2) not null,
  created_at timestamptz not null default now(),
  unique (batch_id, month)
);
create index if not exists idx_bmoa_month on batch_monthly_overhead_allocations(month);

alter table batch_expenses enable row level security;
alter table monthly_expenses enable row level security;
alter table batch_monthly_overhead_allocations enable row level security;

drop policy if exists auth_all_batch_expenses on batch_expenses;
create policy auth_all_batch_expenses on batch_expenses for all to authenticated using (true) with check (true);

drop policy if exists auth_all_monthly_expenses on monthly_expenses;
create policy auth_all_monthly_expenses on monthly_expenses for all to authenticated using (true) with check (true);

drop policy if exists auth_all_bmoa on batch_monthly_overhead_allocations;
create policy auth_all_bmoa on batch_monthly_overhead_allocations for all to authenticated using (true) with check (true);

-- ===================== HELPER: recompute a batch's bulk_cost_per_kg =====================
-- bulk_cost_per_kg = (raw_material_cost + leftover carried-in cost already baked into
-- leftover_qty_kg at creation time... see note below + sum(batch_expenses) + sum(frozen
-- monthly overhead shares)) / leftover_qty_kg (which doubles as "available output kg").
--
-- NOTE: fn_create_production_batch already folds raw material + leftover cost into
-- bulk_cost_per_kg at creation. This helper ADDS batch_expenses + monthly overhead
-- shares on top, using output_yield_kg (not leftover_qty_kg, which drains as bulk is
-- packed) as the stable denominator for spreading these extra costs.
create or replace function fn_recompute_batch_bulk_cost(p_batch_id uuid)
returns void language plpgsql as $$
declare
  v_batch production_batches%rowtype;
  v_raw_and_leftover_total numeric;
  v_expenses_total numeric;
  v_overhead_total numeric;
  v_grand_total numeric;
  v_new_per_kg numeric;
begin
  select * into v_batch from production_batches where id = p_batch_id for update;
  if not found then raise exception 'batch not found' using errcode = 'P0002'; end if;

  -- Reconstruct the raw-material+leftover portion of cost using the CURRENT
  -- leftover_qty_kg as denominator basis (this mirrors what fn_create_production_batch
  -- originally computed before any expenses/overhead were added).
  v_raw_and_leftover_total := v_batch.raw_material_cost;

  select coalesce(sum(amount), 0) into v_expenses_total
    from batch_expenses where batch_id = p_batch_id;

  select coalesce(sum(batch_share), 0) into v_overhead_total
    from batch_monthly_overhead_allocations where batch_id = p_batch_id;

  v_grand_total := v_raw_and_leftover_total + v_expenses_total + v_overhead_total;

  v_new_per_kg := case when v_batch.output_yield_kg > 0
    then v_grand_total / v_batch.output_yield_kg
    else 0 end;

  update production_batches
    set overhead_total = v_expenses_total + v_overhead_total,
        bulk_cost_per_kg = v_new_per_kg
    where id = p_batch_id;
end $$;

-- ===================== UPDATED: fn_create_production_batch =====================
-- Adds p_other_expenses jsonb: [{ "name": "Labour - Ali", "amount": 2000 }, ...]
-- inserted into batch_expenses in the SAME transaction as the batch itself.
create or replace function fn_create_production_batch(
  p_consumptions jsonb, p_output_yield_kg numeric, p_wastage_kg numeric,
  p_leftover_batch_id uuid default null, p_leftover_kg_used numeric default null,
  p_other_expenses jsonb default '[]'::jsonb
) returns jsonb language plpgsql as $$
declare
  v_item jsonb; v_rm raw_materials%rowtype; v_raw_cost numeric := 0;
  v_source production_batches%rowtype; v_leftover_used numeric := 0; v_leftover_cost numeric := 0;
  v_total_cost numeric; v_total_kg numeric; v_bulk_cost_per_kg numeric; v_batch_id uuid;
  v_expense jsonb; v_expenses_total numeric := 0;
begin
  for v_item in select * from jsonb_array_elements(p_consumptions) loop
    select * into v_rm from raw_materials where id = (v_item->>'rawMaterialId')::uuid for update;
    if not found then raise exception 'raw material not found' using errcode = 'P0002'; end if;
    if (v_item->>'qty')::numeric > v_rm.quantity_in_stock then
      raise exception 'insufficient raw material stock' using errcode = '23514';
    end if;
    v_raw_cost := v_raw_cost + ((v_item->>'qty')::numeric * v_rm.avg_unit_cost);
    update raw_materials set quantity_in_stock = quantity_in_stock - (v_item->>'qty')::numeric where id = v_rm.id;
  end loop;

  insert into production_batches (output_yield_kg, wastage_kg, raw_material_cost, status)
  values (p_output_yield_kg, p_wastage_kg, v_raw_cost, 'in_progress') returning id into v_batch_id;

  for v_item in select * from jsonb_array_elements(p_consumptions) loop
    insert into batch_consumptions (batch_id, raw_material_id, qty, unit_cost_at_time)
    select v_batch_id, (v_item->>'rawMaterialId')::uuid, (v_item->>'qty')::numeric, avg_unit_cost
    from raw_materials where id = (v_item->>'rawMaterialId')::uuid;
  end loop;

  if p_leftover_batch_id is not null and p_leftover_kg_used is not null then
    select * into v_source from production_batches where id = p_leftover_batch_id for update;
    if found then
      v_leftover_used := least(p_leftover_kg_used, v_source.leftover_qty_kg);
      v_leftover_cost := v_leftover_used * v_source.bulk_cost_per_kg;
      update production_batches set leftover_qty_kg = leftover_qty_kg - v_leftover_used where id = v_source.id;
    end if;
  end if;

  -- NEW: per-batch named expenses (labour, packaging, misc etc.), added at creation time.
  if p_other_expenses is not null then
    for v_expense in select * from jsonb_array_elements(p_other_expenses) loop
      if (v_expense->>'name') is null or trim(v_expense->>'name') = '' then continue; end if;
      insert into batch_expenses (batch_id, name, amount)
      values (v_batch_id, trim(v_expense->>'name'), coalesce((v_expense->>'amount')::numeric, 0));
      v_expenses_total := v_expenses_total + coalesce((v_expense->>'amount')::numeric, 0);
    end loop;
  end if;

  v_total_cost := v_raw_cost + v_leftover_cost + v_expenses_total;
  v_total_kg := p_output_yield_kg + v_leftover_used;
  v_bulk_cost_per_kg := case when p_output_yield_kg > 0 then v_total_cost / p_output_yield_kg else 0 end;

  update production_batches set
    leftover_qty_kg = v_total_kg,
    bulk_cost_per_kg = v_bulk_cost_per_kg,
    overhead_total = v_expenses_total,
    leftover_source_batch_id = p_leftover_batch_id,
    leftover_kg_consumed = v_leftover_used
  where id = v_batch_id;

  return jsonb_build_object('id', v_batch_id, 'outputYieldKg', p_output_yield_kg, 'wastageKg', p_wastage_kg,
    'leftoverQtyKg', v_total_kg, 'bulkCostPerKg', v_bulk_cost_per_kg, 'otherExpensesTotal', v_expenses_total,
    'status', 'in_progress');
end $$;

-- ===================== NEW: fn_add_batch_expense =====================
-- Adds ONE named expense to an already-existing batch (e.g. added a day
-- later), and recomputes that batch's bulk_cost_per_kg.
create or replace function fn_add_batch_expense(p_batch_id uuid, p_name text, p_amount numeric)
returns jsonb language plpgsql as $$
declare v_expense_id uuid;
begin
  if p_name is null or trim(p_name) = '' then
    raise exception 'expense name required' using errcode = '22000';
  end if;
  if not exists (select 1 from production_batches where id = p_batch_id) then
    raise exception 'batch not found' using errcode = 'P0002';
  end if;

  insert into batch_expenses (batch_id, name, amount)
  values (p_batch_id, trim(p_name), coalesce(p_amount, 0))
  returning id into v_expense_id;

  perform fn_recompute_batch_bulk_cost(p_batch_id);

  return jsonb_build_object('expenseId', v_expense_id, 'batchId', p_batch_id, 'name', trim(p_name), 'amount', coalesce(p_amount, 0));
end $$;

-- ===================== NEW: fn_allocate_monthly_overhead =====================
-- p_month: any date within the target month (normalized to first-of-month).
-- p_method: 'equal' | 'proportional_kg'. If null, uses app_settings.overhead_allocation_method.
-- Batches are matched to the month by production_batches.created_at (batch creation date).
-- Re-running this for the same month REPLACES the previous frozen snapshot for that month
-- (old shares are subtracted back out of bulk_cost_per_kg before new shares are applied).
create or replace function fn_allocate_monthly_overhead(p_month date, p_method text default null)
returns jsonb language plpgsql as $$
declare
  v_month_start date := date_trunc('month', p_month)::date;
  v_month_end date := (date_trunc('month', p_month) + interval '1 month')::date;
  v_method text;
  v_total_expense numeric;
  v_batch record;
  v_batch_count integer;
  v_total_output_kg numeric;
  v_share numeric;
  v_results jsonb := '[]'::jsonb;
begin
  if p_method is not null and p_method not in ('equal', 'proportional_kg') then
    raise exception 'method must be equal or proportional_kg' using errcode = '22000';
  end if;

  v_method := coalesce(p_method, (select overhead_allocation_method from app_settings where id = 1));

  select coalesce(sum(amount), 0) into v_total_expense
    from monthly_expenses where month = v_month_start;

  -- Undo any PREVIOUS allocation for this month before recomputing (idempotent re-run).
  for v_batch in
    select batch_id, batch_share from batch_monthly_overhead_allocations where month = v_month_start
  loop
    update production_batches
      set bulk_cost_per_kg = greatest(0, bulk_cost_per_kg - case when output_yield_kg > 0 then v_batch.batch_share / output_yield_kg else 0 end)
      where id = v_batch.batch_id;
  end loop;
  delete from batch_monthly_overhead_allocations where month = v_month_start;

  select count(*), coalesce(sum(output_yield_kg), 0) into v_batch_count, v_total_output_kg
    from production_batches
    where created_at >= v_month_start and created_at < v_month_end;

  if v_batch_count = 0 then
    return jsonb_build_object('month', v_month_start, 'method', v_method, 'totalExpense', v_total_expense,
      'batchCount', 0, 'warning', 'No batches found in this month - nothing allocated.');
  end if;

  for v_batch in
    select id, output_yield_kg from production_batches
      where created_at >= v_month_start and created_at < v_month_end
  loop
    if v_method = 'proportional_kg' then
      v_share := case when v_total_output_kg > 0
        then (v_batch.output_yield_kg / v_total_output_kg) * v_total_expense
        else 0 end;
    else
      v_share := v_total_expense / v_batch_count;
    end if;

    insert into batch_monthly_overhead_allocations (batch_id, month, allocation_method, total_month_expense, batch_share)
    values (v_batch.id, v_month_start, v_method, v_total_expense, v_share);

    perform fn_recompute_batch_bulk_cost(v_batch.id);

    v_results := v_results || jsonb_build_object('batchId', v_batch.id, 'outputYieldKg', v_batch.output_yield_kg, 'share', v_share);
  end loop;

  return jsonb_build_object('month', v_month_start, 'method', v_method, 'totalExpense', v_total_expense,
    'batchCount', v_batch_count, 'totalOutputKg', v_total_output_kg, 'allocations', v_results);
end $$;

grant execute on function fn_recompute_batch_bulk_cost(uuid) to authenticated;
grant execute on function fn_add_batch_expense(uuid, text, numeric) to authenticated;
grant execute on function fn_allocate_monthly_overhead(date, text) to authenticated;
'@

    Set-Content -LiteralPath $migrationPath -Value $migrationSql -NoNewline
    Write-Host "Created migration -> 0007_batch_and_monthly_expenses.sql" -ForegroundColor Green
}

# ===================================================================
# 2. UPDATE: batches/index.ts (pass otherExpenses through)
# ===================================================================
$batchesFnPath = Join-Path $root "apps\backend\supabase\functions\batches\index.ts"
if (-not (Test-Path -LiteralPath $batchesFnPath)) {
    Write-Host "ERROR: Could not find $batchesFnPath" -ForegroundColor Red
    exit 1
}
$batchesContent = Get-Content -Raw -LiteralPath $batchesFnPath
if ($batchesContent -match "p_other_expenses") {
    Write-Host "batches/index.ts already updated - skipping." -ForegroundColor Yellow
}
else {
    Backup-File $batchesFnPath
    $newBatchesContent = @'
// Create a production batch (FR-20/21) with optional leftover carry-forward
// and optional named other-expenses (labour, packaging, misc, etc.)
// POST /functions/v1/batches
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    const rpcParams = {
    p_consumptions: body.consumptions,
    p_output_yield_kg: body.outputYieldKg,
    p_wastage_kg: body.wastageKg ?? 0,
    p_leftover_batch_id: body.leftoverBatchId ?? null,
    p_leftover_kg_used: body.leftoverKgUsed ?? null,
    p_other_expenses: body.otherExpenses ?? [],
    };

    const { data, error } = await supabase.rpc("fn_create_production_batch", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
    Set-Content -LiteralPath $batchesFnPath -Value $newBatchesContent -NoNewline
    Write-Host "Updated -> batches/index.ts (now accepts otherExpenses)" -ForegroundColor Green
}

# ===================================================================
# 3. NEW: batch-expenses/index.ts
# ===================================================================
$batchExpDir = Join-Path $root "apps\backend\supabase\functions\batch-expenses"
Ensure-Dir $batchExpDir
$batchExpPath = Join-Path $batchExpDir "index.ts"
if (Test-Path -LiteralPath $batchExpPath) {
    Write-Host "batch-expenses/index.ts already exists - skipping." -ForegroundColor Yellow
}
else {
$batchExpTs = @'
// Add a single named expense (labour, packaging, misc, etc.) to an
// EXISTING batch. For expenses added at batch-creation time, pass them
// via `otherExpenses` on POST /functions/v1/batches instead.
// POST /functions/v1/batch-expenses
// body: { batchId: string, name: string, amount: number }
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    const { data, error } = await supabase.rpc("fn_add_batch_expense", {
      p_batch_id: body.batchId,
      p_name: body.name,
      p_amount: body.amount ?? 0,
    });

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
    Set-Content -LiteralPath $batchExpPath -Value $batchExpTs -NoNewline
    Write-Host "Created -> batch-expenses/index.ts" -ForegroundColor Green
}

# ===================================================================
# 4. NEW: monthly-expenses/index.ts (CRUD)
# ===================================================================
$monthlyExpDir = Join-Path $root "apps\backend\supabase\functions\monthly-expenses"
Ensure-Dir $monthlyExpDir
$monthlyExpPath = Join-Path $monthlyExpDir "index.ts"
if (Test-Path -LiteralPath $monthlyExpPath) {
    Write-Host "monthly-expenses/index.ts already exists - skipping." -ForegroundColor Yellow
}
else {
$monthlyExpTs = @'
// CRUD for accumulative monthly expenses (e.g. "August Electricity: 45000").
// GET    /functions/v1/monthly-expenses?month=2026-08-01   -> list for that month
// POST   /functions/v1/monthly-expenses   body: { month, name, amount } -> create
// DELETE /functions/v1/monthly-expenses   body: { id } -> delete
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

function firstOfMonth(dateStr: string) {
  const d = new Date(dateStr);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const supabase = getClient(req);

  try {
    if (req.method === "GET") {
      const url = new URL(req.url);
      const month = url.searchParams.get("month");
      if (!month) {
        return jsonResponse(envelopeError("month query param required (YYYY-MM-DD)", "BAD_REQUEST"), 400, corsHeaders);
      }
      const { data, error } = await supabase
        .from("monthly_expenses")
        .select("*")
        .eq("month", firstOfMonth(month))
        .order("created_at", { ascending: true });

      if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 400, corsHeaders);
      return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
    }

    if (req.method === "POST") {
      const body = await req.json();
      if (!body.month || !body.name || body.amount == null) {
        return jsonResponse(envelopeError("month, name and amount are required", "BAD_REQUEST"), 400, corsHeaders);
      }
      const { data, error } = await supabase
        .from("monthly_expenses")
        .insert({ month: firstOfMonth(body.month), name: body.name, amount: body.amount })
        .select()
        .single();

      if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 400, corsHeaders);
      return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
    }

    if (req.method === "DELETE") {
      const body = await req.json();
      if (!body.id) {
        return jsonResponse(envelopeError("id required", "BAD_REQUEST"), 400, corsHeaders);
      }
      const { error } = await supabase.from("monthly_expenses").delete().eq("id", body.id);
      if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 400, corsHeaders);
      return jsonResponse(envelopeSuccess({ deleted: true }), 200, corsHeaders);
    }

    return jsonResponse(envelopeError("Method not allowed", "METHOD_NOT_ALLOWED"), 405, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
    Set-Content -LiteralPath $monthlyExpPath -Value $monthlyExpTs -NoNewline
    Write-Host "Created -> monthly-expenses/index.ts" -ForegroundColor Green
}

# ===================================================================
# 5. NEW: monthly-overhead-allocate/index.ts
# ===================================================================
$allocateDir = Join-Path $root "apps\backend\supabase\functions\monthly-overhead-allocate"
Ensure-Dir $allocateDir
$allocatePath = Join-Path $allocateDir "index.ts"
if (Test-Path -LiteralPath $allocatePath) {
    Write-Host "monthly-overhead-allocate/index.ts already exists - skipping." -ForegroundColor Yellow
}
else {
$allocateTs = @'
// Allocates a month's accumulative expenses across that month's batches.
// POST /functions/v1/monthly-overhead-allocate
// body: { month: "2026-08-01", method?: "equal" | "proportional_kg" }
// If method is omitted, uses app_settings.overhead_allocation_method.
// Safe to re-run for the same month - replaces the previous allocation.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.month) {
      return jsonResponse(envelopeError("month is required (YYYY-MM-DD)", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase.rpc("fn_allocate_monthly_overhead", {
      p_month: body.month,
      p_method: body.method ?? null,
    });

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
    Set-Content -LiteralPath $allocatePath -Value $allocateTs -NoNewline
    Write-Host "Created -> monthly-overhead-allocate/index.ts" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Ab yeh manual steps karein:" -ForegroundColor Green
Write-Host "  1. supabase db push   (ya migration ko apply karne ka jo bhi tareeqa aap use karte hain)" -ForegroundColor Cyan
Write-Host "  2. supabase functions deploy batches" -ForegroundColor Cyan
Write-Host "  3. supabase functions deploy batch-expenses" -ForegroundColor Cyan
Write-Host "  4. supabase functions deploy monthly-expenses" -ForegroundColor Cyan
Write-Host "  5. supabase functions deploy monthly-overhead-allocate" -ForegroundColor Cyan
Write-Host ""
Write-Host "Frontend (Settings toggle, New Batch 'Other Expenses' section, Monthly Expenses page)" -ForegroundColor DarkGray
Write-Host "ka script agla step hai - backend deploy/test hone ke baad batayein." -ForegroundColor DarkGray