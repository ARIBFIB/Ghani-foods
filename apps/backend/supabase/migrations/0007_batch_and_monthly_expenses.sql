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