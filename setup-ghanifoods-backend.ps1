# ============================================================================
# GhaniFoods Backend - ALL-IN-ONE Setup Script
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>
#   PS D:\...\GhaniFoods> .\setup-ghanifoods-backend.ps1
# Creates apps\backend\ with full schema + RPC functions, links + pushes to
# Supabase project hbvcdxhdkbksknasdqst. Safe to re-run (idempotent SQL).
# ============================================================================

$ErrorActionPreference = "Stop"
$Root       = Get-Location
$Backend    = Join-Path $Root "apps\backend"
$Migrations = Join-Path $Backend "supabase\migrations"

Write-Host "==> Creating folder structure..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $Migrations | Out-Null

# ----------------------------------------------------------------------------
# Credentials (public URL/key are fine to hardcode; secrets are prompted)
# ----------------------------------------------------------------------------
$ProjectRef = "hbvcdxhdkbksknasdqst"
$SupaUrl    = "https://$ProjectRef.supabase.co"
$AnonKey    = "sb_publishable_wb9g0T-w9vWCalNB0Dbivw_Ipzjyfgd"

if (-not (Test-Path (Join-Path $Backend ".env"))) {
    Write-Host "==> Need your Supabase DB password (Dashboard -> Settings -> Database)" -ForegroundColor Yellow
    $DbPasswordSecure = Read-Host "Enter SUPABASE_DB_PASSWORD" -AsSecureString
    $DbPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($DbPasswordSecure))

    Write-Host "==> Optional: service_role SECRET key (for admin user creation only, blank to skip)" -ForegroundColor Yellow
    $SecretKeySecure = Read-Host "Enter SUPABASE_SECRET_KEY (or press Enter to skip)" -AsSecureString
    $SecretKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecretKeySecure))

    $EnvContent = @"
SUPABASE_PROJECT_REF=$ProjectRef
SUPABASE_URL=$SupaUrl
SUPABASE_PUBLISHABLE_KEY=$AnonKey
SUPABASE_SECRET_KEY=$SecretKey
SUPABASE_DB_PASSWORD=$DbPassword
"@
    Set-Content -Path (Join-Path $Backend ".env") -Value $EnvContent -Encoding UTF8
    Write-Host "==> .env written to apps\backend\.env" -ForegroundColor Green
} else {
    Write-Host "==> apps\backend\.env already exists, reusing it" -ForegroundColor Yellow
    Get-Content (Join-Path $Backend ".env") | ForEach-Object {
        if ($_ -match '^SUPABASE_DB_PASSWORD=(.*)$')   { $DbPassword = $Matches[1] }
        if ($_ -match '^SUPABASE_SECRET_KEY=(.*)$')     { $SecretKey  = $Matches[1] }
    }
}

$GitIgnore = @"
.env
node_modules/
dist/
.supabase/
"@
Set-Content -Path (Join-Path $Backend ".gitignore") -Value $GitIgnore -Encoding UTF8

# ============================================================================
# 0001_init_schema.sql  -  full schema (tables + indexes + RLS)
# ============================================================================
$Schema = @'
-- ===================== EXTENSIONS =====================
create extension if not exists pgcrypto;

-- ===================== MASTER DATA =====================
create table if not exists suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  address text,
  created_at timestamptz not null default now()
);

create table if not exists raw_materials (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit text not null,
  quantity_in_stock numeric(14,3) not null default 0,
  avg_unit_cost numeric(14,2) not null default 0,
  low_stock_threshold numeric(14,3) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists app_settings (
  id integer primary key default 1 check (id = 1),
  business_name text not null default 'GhaniFoods',
  address text not null default '',
  invoice_footer_text text,
  default_profit_margin_percent numeric(5,2) not null default 20,
  low_stock_threshold_default numeric(14,3) not null default 50,
  updated_at timestamptz not null default now()
);
insert into app_settings (id) values (1) on conflict (id) do nothing;

-- ===================== PURCHASING =====================
create table if not exists purchase_receipts (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id),
  purchase_date date not null,
  created_at timestamptz not null default now()
);

create table if not exists purchase_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid not null references purchase_receipts(id),
  raw_material_id uuid not null references raw_materials(id),
  qty numeric(14,3) not null check (qty > 0),
  cost numeric(14,2) not null check (cost > 0),
  avg_cost_after numeric(14,2),
  created_at timestamptz not null default now()
);
create index if not exists idx_prl_receipt on purchase_receipt_lines(receipt_id);
create index if not exists idx_prl_material on purchase_receipt_lines(raw_material_id);

-- ===================== PACKAGING =====================
create table if not exists wrappers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  raw_material_id uuid not null references raw_materials(id),
  grams_per_unit numeric(14,3) not null check (grams_per_unit > 0),
  stock_qty integer not null default 0,
  low_stock_threshold integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists boxes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  raw_material_id uuid not null references raw_materials(id),
  grams_per_unit numeric(14,3) not null check (grams_per_unit > 0),
  stock_qty integer not null default 0,
  low_stock_threshold integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists wrapper_production_runs (
  id uuid primary key default gen_random_uuid(),
  wrapper_id uuid not null references wrappers(id),
  quantity_produced integer not null check (quantity_produced > 0),
  grams_consumed numeric(14,2) not null,
  run_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists box_production_runs (
  id uuid primary key default gen_random_uuid(),
  box_id uuid not null references boxes(id),
  quantity_produced integer not null check (quantity_produced > 0),
  grams_consumed numeric(14,2) not null,
  run_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists carton_configurations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  wrapper_id uuid not null references wrappers(id),
  packets_per_box integer not null check (packets_per_box > 0),
  box_id uuid not null references boxes(id),
  boxes_per_carton integer not null check (boxes_per_carton > 0),
  used_in_packing_run boolean not null default false,
  created_at timestamptz not null default now()
);

-- ===================== PRODUCTION =====================
create table if not exists production_batches (
  id uuid primary key default gen_random_uuid(),
  batch_date date not null default current_date,
  output_yield_kg numeric(14,3) not null check (output_yield_kg > 0),
  wastage_kg numeric(14,3) not null default 0 check (wastage_kg >= 0),
  leftover_qty_kg numeric(14,3) not null default 0,
  raw_material_cost numeric(14,2) not null default 0,
  overhead_total numeric(14,2) not null default 0,
  bulk_cost_per_kg numeric(14,2) not null default 0,
  leftover_source_batch_id uuid references production_batches(id),
  leftover_kg_consumed numeric(14,3),
  status text not null default 'in_progress' check (status in ('in_progress','completed')),
  created_at timestamptz not null default now()
);

create table if not exists batch_consumptions (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references production_batches(id),
  raw_material_id uuid not null references raw_materials(id),
  qty numeric(14,3) not null check (qty > 0),
  unit_cost_at_time numeric(14,2) not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_bc_batch on batch_consumptions(batch_id);

create table if not exists finished_cartons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source_batch_id uuid not null references production_batches(id),
  config_id uuid not null references carton_configurations(id),
  cartons_produced integer not null,
  packets_per_carton integer not null,
  cost_per_packet numeric(14,2) not null,
  cost_per_box numeric(14,2) not null default 0,
  cost_per_carton numeric(14,2) not null default 0,
  stock_qty integer not null default 0,
  created_at timestamptz not null default now()
);

-- ===================== CUSTOMERS / SALES =====================
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  current_balance numeric(14,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists customer_item_prices (
  customer_id uuid not null references customers(id),
  item_id uuid not null references finished_cartons(id),
  last_sold_price numeric(14,2) not null,
  last_sold_date date not null,
  primary key (customer_id, item_id)
);

create table if not exists invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number text unique not null,
  customer_id uuid not null references customers(id),
  invoice_date date not null default current_date,
  total_amount numeric(14,2) not null,
  pdf_url text,
  created_at timestamptz not null default now()
);

create table if not exists invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id),
  finished_carton_id uuid not null references finished_cartons(id),
  item_name text not null,
  qty integer not null check (qty > 0),
  unit_price numeric(14,2) not null,
  subtotal numeric(14,2) not null,
  price_source_note text not null
);
create index if not exists idx_ii_invoice on invoice_items(invoice_id);

create table if not exists customer_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  type text not null check (type in ('invoice','payment','adjustment')),
  direction text check (direction in ('received','given')),
  amount numeric(14,2) not null check (amount > 0),
  running_balance numeric(14,2) not null,
  note text,
  reference_id uuid,
  entry_date date not null default current_date,
  created_at timestamptz not null default now()
);
create index if not exists idx_cle_customer on customer_ledger_entries(customer_id);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id),
  amount numeric(14,2) not null check (amount > 0),
  direction text not null check (direction in ('received','given')),
  note text,
  paid_at date not null default current_date,
  ledger_entry_id uuid references customer_ledger_entries(id),
  created_at timestamptz not null default now()
);

-- ===================== RLS =====================
do $$
declare t text;
begin
  for t in select unnest(array[
    'suppliers','raw_materials','app_settings','purchase_receipts','purchase_receipt_lines',
    'wrappers','boxes','wrapper_production_runs','box_production_runs','carton_configurations',
    'production_batches','batch_consumptions','finished_cartons','customers','customer_item_prices',
    'invoices','invoice_items','customer_ledger_entries','payments'
  ])
  loop
    execute format('alter table %I enable row level security;', t);
    execute format('drop policy if exists auth_all_%1$s on %1$I;', t);
    execute format(
      'create policy auth_all_%1$s on %1$I for all to authenticated using (true) with check (true);', t
    );
  end loop;
end $$;
'@
Set-Content -Path (Join-Path $Migrations "0001_init_schema.sql") -Value $Schema -Encoding UTF8

# ============================================================================
# 0002_functions.sql  -  10 business-logic RPC functions
# ============================================================================
$Functions = @'
-- ============ 1. PURCHASE RECEIPT (weighted-avg cost) ============
create or replace function fn_create_purchase_receipt(
  p_supplier_id uuid, p_purchase_date date, p_items jsonb
) returns jsonb language plpgsql as $$
declare
  v_receipt_id uuid; v_item jsonb; v_rm raw_materials%rowtype;
  v_new_qty numeric; v_new_avg numeric; v_lines jsonb := '[]'::jsonb;
begin
  if p_items is null or jsonb_array_length(p_items) < 1 then
    raise exception 'items required' using errcode = '22000';
  end if;

  insert into purchase_receipts (supplier_id, purchase_date)
  values (p_supplier_id, p_purchase_date) returning id into v_receipt_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_rm from raw_materials where id = (v_item->>'rawMaterialId')::uuid for update;
    if not found then raise exception 'raw material not found' using errcode = 'P0002'; end if;

    v_new_qty := v_rm.quantity_in_stock + (v_item->>'qty')::numeric;
    v_new_avg := ((v_rm.quantity_in_stock * v_rm.avg_unit_cost) + ((v_item->>'qty')::numeric * (v_item->>'cost')::numeric)) / v_new_qty;

    update raw_materials set quantity_in_stock = v_new_qty, avg_unit_cost = v_new_avg where id = v_rm.id;

    insert into purchase_receipt_lines (receipt_id, raw_material_id, qty, cost, avg_cost_after)
    values (v_receipt_id, v_rm.id, (v_item->>'qty')::numeric, (v_item->>'cost')::numeric, v_new_avg);

    v_lines := v_lines || jsonb_build_object(
      'rawMaterialId', v_rm.id, 'qty', v_item->>'qty', 'cost', v_item->>'cost',
      'newAvgUnitCost', v_new_avg, 'newQuantityInStock', v_new_qty
    );
  end loop;

  return jsonb_build_object('receiptId', v_receipt_id, 'supplierId', p_supplier_id,
    'purchaseDate', p_purchase_date, 'lines', v_lines);
end $$;

-- ============ 2. WRAPPER PRODUCTION ============
create or replace function fn_produce_wrapper(p_wrapper_id uuid, p_qty integer)
returns jsonb language plpgsql as $$
declare v_w wrappers%rowtype; v_rm raw_materials%rowtype; v_grams numeric; v_run_id uuid;
begin
  select * into v_w from wrappers where id = p_wrapper_id for update;
  if not found then raise exception 'wrapper not found' using errcode = 'P0002'; end if;
  select * into v_rm from raw_materials where id = v_w.raw_material_id for update;

  v_grams := v_w.grams_per_unit * p_qty;
  if (v_grams / 1000.0) > v_rm.quantity_in_stock then
    raise exception 'insufficient raw material stock' using errcode = '23514';
  end if;

  update raw_materials set quantity_in_stock = quantity_in_stock - (v_grams / 1000.0) where id = v_rm.id;
  update wrappers set stock_qty = stock_qty + p_qty where id = v_w.id;

  insert into wrapper_production_runs (wrapper_id, quantity_produced, grams_consumed)
  values (p_wrapper_id, p_qty, v_grams) returning id into v_run_id;

  return jsonb_build_object('runId', v_run_id, 'wrapperId', p_wrapper_id, 'quantityProduced', p_qty,
    'gramsConsumed', v_grams, 'remainingRawMaterialStock', v_rm.quantity_in_stock - (v_grams/1000.0),
    'newWrapperStockQty', v_w.stock_qty + p_qty);
end $$;

-- ============ 3. BOX PRODUCTION ============
create or replace function fn_produce_box(p_box_id uuid, p_qty integer)
returns jsonb language plpgsql as $$
declare v_b boxes%rowtype; v_rm raw_materials%rowtype; v_grams numeric; v_run_id uuid;
begin
  select * into v_b from boxes where id = p_box_id for update;
  if not found then raise exception 'box not found' using errcode = 'P0002'; end if;
  select * into v_rm from raw_materials where id = v_b.raw_material_id for update;

  v_grams := v_b.grams_per_unit * p_qty;
  if (v_grams / 1000.0) > v_rm.quantity_in_stock then
    raise exception 'insufficient raw material stock' using errcode = '23514';
  end if;

  update raw_materials set quantity_in_stock = quantity_in_stock - (v_grams / 1000.0) where id = v_rm.id;
  update boxes set stock_qty = stock_qty + p_qty where id = v_b.id;

  insert into box_production_runs (box_id, quantity_produced, grams_consumed)
  values (p_box_id, p_qty, v_grams) returning id into v_run_id;

  return jsonb_build_object('runId', v_run_id, 'boxId', p_box_id, 'quantityProduced', p_qty,
    'gramsConsumed', v_grams, 'remainingRawMaterialStock', v_rm.quantity_in_stock - (v_grams/1000.0),
    'newBoxStockQty', v_b.stock_qty + p_qty);
end $$;

-- ============ 4. PRODUCTION BATCH ============
create or replace function fn_create_production_batch(
  p_consumptions jsonb, p_output_yield_kg numeric, p_wastage_kg numeric,
  p_leftover_batch_id uuid default null, p_leftover_kg_used numeric default null
) returns jsonb language plpgsql as $$
declare
  v_item jsonb; v_rm raw_materials%rowtype; v_raw_cost numeric := 0;
  v_source production_batches%rowtype; v_leftover_used numeric := 0; v_leftover_cost numeric := 0;
  v_total_cost numeric; v_total_kg numeric; v_bulk_cost_per_kg numeric; v_batch_id uuid;
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

  v_total_cost := v_raw_cost + v_leftover_cost;
  v_total_kg := p_output_yield_kg + v_leftover_used;
  v_bulk_cost_per_kg := case when v_total_kg > 0 then v_total_cost / v_total_kg else 0 end;

  update production_batches set
    leftover_qty_kg = v_total_kg,
    bulk_cost_per_kg = v_bulk_cost_per_kg,
    leftover_source_batch_id = p_leftover_batch_id,
    leftover_kg_consumed = v_leftover_used
  where id = v_batch_id;

  return jsonb_build_object('id', v_batch_id, 'outputYieldKg', p_output_yield_kg, 'wastageKg', p_wastage_kg,
    'leftoverQtyKg', v_total_kg, 'bulkCostPerKg', v_bulk_cost_per_kg, 'status', 'in_progress');
end $$;

-- ============ 5. OVERHEAD ALLOCATION ============
create or replace function fn_allocate_overhead(p_batch_id uuid, p_electricity numeric, p_gas numeric, p_rent numeric)
returns jsonb language plpgsql as $$
declare v_b production_batches%rowtype; v_total numeric; v_per_kg numeric;
begin
  select * into v_b from production_batches where id = p_batch_id for update;
  if not found then raise exception 'batch not found' using errcode = 'P0002'; end if;

  v_total := coalesce(p_electricity,0) + coalesce(p_gas,0) + coalesce(p_rent,0);
  v_per_kg := case when v_b.output_yield_kg > 0 then v_total / v_b.output_yield_kg else 0 end;

  update production_batches set overhead_total = v_total, bulk_cost_per_kg = bulk_cost_per_kg + v_per_kg
  where id = p_batch_id;

  return jsonb_build_object('batchId', p_batch_id, 'overheadTotal', v_total,
    'newBulkCostPerKg', v_b.bulk_cost_per_kg + v_per_kg);
end $$;

-- ============ 6. PACKING RUN PREVIEW (read-only) ============
create or replace function fn_packing_run_preview(p_batch_id uuid, p_config_id uuid, p_cartons_produced integer)
returns jsonb language plpgsql as $$
declare
  v_batch production_batches%rowtype; v_cfg carton_configurations%rowtype;
  v_wrapper wrappers%rowtype; v_box boxes%rowtype;
  v_boxes_produced integer; v_packets_produced integer; v_needed_kg numeric;
  v_bulk_used numeric; v_wrapper_rm raw_materials%rowtype; v_box_rm raw_materials%rowtype;
  v_wrapper_unit_cost numeric; v_box_unit_cost numeric; v_bulk_cost_share numeric;
  v_cost_per_packet numeric; v_cost_per_box numeric; v_cost_per_carton numeric;
  v_nominal_kg_per_packet constant numeric := 0.05;
begin
  select * into v_batch from production_batches where id = p_batch_id;
  select * into v_cfg from carton_configurations where id = p_config_id;
  if not found or v_batch.id is null then raise exception 'batch or config not found' using errcode = 'P0002'; end if;
  select * into v_wrapper from wrappers where id = v_cfg.wrapper_id;
  select * into v_box from boxes where id = v_cfg.box_id;
  select * into v_wrapper_rm from raw_materials where id = v_wrapper.raw_material_id;
  select * into v_box_rm from raw_materials where id = v_box.raw_material_id;

  v_boxes_produced := p_cartons_produced * v_cfg.boxes_per_carton;
  v_packets_produced := v_boxes_produced * v_cfg.packets_per_box;
  v_needed_kg := v_packets_produced * v_nominal_kg_per_packet;
  v_bulk_used := least(v_needed_kg, v_batch.leftover_qty_kg);

  v_bulk_cost_share := v_batch.bulk_cost_per_kg * v_bulk_used;
  v_wrapper_unit_cost := v_wrapper.grams_per_unit * (v_wrapper_rm.avg_unit_cost / 1000.0);
  v_box_unit_cost := v_box.grams_per_unit * (v_box_rm.avg_unit_cost / 1000.0);
  v_cost_per_packet := case when v_packets_produced > 0 then (v_bulk_cost_share / v_packets_produced) + v_wrapper_unit_cost else 0 end;
  v_cost_per_box := (v_cfg.packets_per_box * v_cost_per_packet) + v_box_unit_cost;
  v_cost_per_carton := v_cfg.boxes_per_carton * v_cost_per_box;

  return jsonb_build_object(
    'boxesProduced', v_boxes_produced, 'packetsProduced', v_packets_produced,
    'bulkMaterial', jsonb_build_object('neededKg', v_needed_kg, 'availableKg', v_batch.leftover_qty_kg,
      'remainingAfterKg', v_batch.leftover_qty_kg - v_bulk_used, 'sufficient', v_needed_kg <= v_batch.leftover_qty_kg),
    'boxes', jsonb_build_object('needed', v_boxes_produced, 'available', v_box.stock_qty, 'sufficient', v_boxes_produced <= v_box.stock_qty),
    'wrappers', jsonb_build_object('needed', v_packets_produced, 'available', v_wrapper.stock_qty, 'sufficient', v_packets_produced <= v_wrapper.stock_qty),
    'estimatedCostPerPacket', v_cost_per_packet, 'estimatedCostPerBox', v_cost_per_box, 'estimatedCostPerCarton', v_cost_per_carton,
    'canConfirm', (v_needed_kg <= v_batch.leftover_qty_kg) and (v_boxes_produced <= v_box.stock_qty) and (v_packets_produced <= v_wrapper.stock_qty)
  );
end $$;

-- ============ 7. CONFIRM PACKING RUN ============
create or replace function fn_create_packing_run(p_batch_id uuid, p_config_id uuid, p_cartons_produced integer)
returns jsonb language plpgsql as $$
declare
  v_batch production_batches%rowtype; v_cfg carton_configurations%rowtype;
  v_wrapper wrappers%rowtype; v_box boxes%rowtype;
  v_wrapper_rm raw_materials%rowtype; v_box_rm raw_materials%rowtype;
  v_boxes_produced integer; v_packets_produced integer; v_needed_kg numeric; v_bulk_used numeric;
  v_wrapper_unit_cost numeric; v_box_unit_cost numeric; v_bulk_cost_share numeric;
  v_cost_per_packet numeric; v_cost_per_box numeric; v_cost_per_carton numeric;
  v_finished_id uuid; v_nominal_kg_per_packet constant numeric := 0.05;
begin
  select * into v_batch from production_batches where id = p_batch_id for update;
  select * into v_cfg from carton_configurations where id = p_config_id for update;
  if not found or v_batch.id is null then raise exception 'batch or config not found' using errcode = 'P0002'; end if;
  select * into v_wrapper from wrappers where id = v_cfg.wrapper_id for update;
  select * into v_box from boxes where id = v_cfg.box_id for update;
  select * into v_wrapper_rm from raw_materials where id = v_wrapper.raw_material_id;
  select * into v_box_rm from raw_materials where id = v_box.raw_material_id;

  v_boxes_produced := p_cartons_produced * v_cfg.boxes_per_carton;
  v_packets_produced := v_boxes_produced * v_cfg.packets_per_box;
  v_needed_kg := v_packets_produced * v_nominal_kg_per_packet;

  if v_needed_kg > v_batch.leftover_qty_kg or v_packets_produced > v_wrapper.stock_qty or v_boxes_produced > v_box.stock_qty then
    raise exception 'insufficient bulk material, boxes, or wrappers' using errcode = '23514';
  end if;

  v_bulk_used := v_needed_kg;
  v_bulk_cost_share := v_batch.bulk_cost_per_kg * v_bulk_used;
  v_wrapper_unit_cost := v_wrapper.grams_per_unit * (v_wrapper_rm.avg_unit_cost / 1000.0);
  v_box_unit_cost := v_box.grams_per_unit * (v_box_rm.avg_unit_cost / 1000.0);
  v_cost_per_packet := (v_bulk_cost_share / v_packets_produced) + v_wrapper_unit_cost;
  v_cost_per_box := (v_cfg.packets_per_box * v_cost_per_packet) + v_box_unit_cost;
  v_cost_per_carton := v_cfg.boxes_per_carton * v_cost_per_box;

  update production_batches set
    leftover_qty_kg = leftover_qty_kg - v_bulk_used,
    status = case when leftover_qty_kg - v_bulk_used <= 0 then 'completed' else status end
  where id = v_batch.id;

  update wrappers set stock_qty = stock_qty - v_packets_produced where id = v_wrapper.id;
  update boxes set stock_qty = stock_qty - v_boxes_produced where id = v_box.id;
  update carton_configurations set used_in_packing_run = true where id = v_cfg.id;

  insert into finished_cartons (name, source_batch_id, config_id, cartons_produced, packets_per_carton,
    cost_per_packet, cost_per_box, cost_per_carton, stock_qty)
  values (v_cfg.name, v_batch.id, v_cfg.id, p_cartons_produced, v_cfg.packets_per_box * v_cfg.boxes_per_carton,
    v_cost_per_packet, v_cost_per_box, v_cost_per_carton, p_cartons_produced)
  returning id into v_finished_id;

  return jsonb_build_object('finishedCartonId', v_finished_id, 'name', v_cfg.name,
    'cartonsProduced', p_cartons_produced, 'packetsPerCarton', v_cfg.packets_per_box * v_cfg.boxes_per_carton,
    'costPerPacket', v_cost_per_packet, 'costPerBox', v_cost_per_box, 'costPerCarton', v_cost_per_carton,
    'stockQty', p_cartons_produced);
end $$;

-- ============ 8. INVOICE PRICE LOOKUP (read-only) ============
create or replace function fn_price_lookup(p_customer_id uuid, p_item_id uuid)
returns jsonb language plpgsql as $$
declare v_cip customer_item_prices%rowtype; v_fc finished_cartons%rowtype; v_margin numeric;
begin
  select * into v_cip from customer_item_prices where customer_id = p_customer_id and item_id = p_item_id;
  if found then
    return jsonb_build_object('unitPrice', v_cip.last_sold_price,
      'priceSourceNote', format('Previously sold to this customer on %s at Rs. %s - that price applied.', v_cip.last_sold_date, v_cip.last_sold_price));
  end if;

  select * into v_fc from finished_cartons where id = p_item_id;
  select default_profit_margin_percent into v_margin from app_settings where id = 1;
  return jsonb_build_object('unitPrice', round(v_fc.cost_per_carton * (1 + v_margin/100.0), 2),
    'priceSourceNote', 'First sale to this customer - standard cost-plus-margin price applied.');
end $$;

-- ============ 9. CREATE INVOICE ============
create or replace function fn_create_invoice(p_customer_id uuid, p_lines jsonb)
returns jsonb language plpgsql as $$
declare
  v_line jsonb; v_fc finished_cartons%rowtype; v_subtotal numeric; v_total numeric := 0;
  v_invoice_id uuid; v_invoice_number text; v_next_num integer; v_new_balance numeric;
  v_items jsonb := '[]'::jsonb; v_note text; v_cip customer_item_prices%rowtype;
begin
  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_fc from finished_cartons where id = (v_line->>'finishedCartonId')::uuid for update;
    if not found then raise exception 'finished carton not found' using errcode = 'P0002'; end if;
    if (v_line->>'qty')::integer > v_fc.stock_qty then
      raise exception 'insufficient finished carton stock' using errcode = '23514';
    end if;
  end loop;

  select coalesce(max(substring(invoice_number from 'inv-(\d+)')::integer), 1000) + 1 into v_next_num from invoices;
  v_invoice_number := 'inv-' || v_next_num;

  insert into invoices (invoice_number, customer_id, total_amount) values (v_invoice_number, p_customer_id, 0)
  returning id into v_invoice_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_fc from finished_cartons where id = (v_line->>'finishedCartonId')::uuid for update;
    v_subtotal := (v_line->>'qty')::integer * (v_line->>'unitPrice')::numeric;
    v_total := v_total + v_subtotal;

    select * into v_cip from customer_item_prices where customer_id = p_customer_id and item_id = v_fc.id;
    if found then
      v_note := format('Previously sold to this customer on %s at Rs. %s - that price applied.', v_cip.last_sold_date, v_cip.last_sold_price);
    else
      v_note := 'First sale to this customer - standard cost-plus-margin price applied.';
    end if;

    update finished_cartons set stock_qty = stock_qty - (v_line->>'qty')::integer where id = v_fc.id;

    insert into invoice_items (invoice_id, finished_carton_id, item_name, qty, unit_price, subtotal, price_source_note)
    values (v_invoice_id, v_fc.id, v_fc.name, (v_line->>'qty')::integer, (v_line->>'unitPrice')::numeric, v_subtotal, v_note);

    insert into customer_item_prices (customer_id, item_id, last_sold_price, last_sold_date)
    values (p_customer_id, v_fc.id, (v_line->>'unitPrice')::numeric, current_date)
    on conflict (customer_id, item_id) do update set last_sold_price = excluded.last_sold_price, last_sold_date = excluded.last_sold_date;

    v_items := v_items || jsonb_build_object('itemId', v_fc.id, 'itemName', v_fc.name, 'qty', v_line->>'qty',
      'unitPrice', v_line->>'unitPrice', 'subtotal', v_subtotal, 'priceSourceNote', v_note);
  end loop;

  update invoices set total_amount = v_total where id = v_invoice_id;

  update customers set current_balance = current_balance + v_total where id = p_customer_id returning current_balance into v_new_balance;

  insert into customer_ledger_entries (customer_id, type, direction, amount, running_balance, reference_id)
  values (p_customer_id, 'invoice', null, v_total, v_new_balance, v_invoice_id);

  return jsonb_build_object('id', v_invoice_id, 'invoiceNumber', v_invoice_number, 'totalAmount', v_total,
    'items', v_items, 'newCustomerBalance', v_new_balance);
end $$;

-- ============ 10. RECORD PAYMENT / ADJUSTMENT ============
create or replace function fn_record_payment(p_customer_id uuid, p_amount numeric, p_direction text, p_note text default null)
returns jsonb language plpgsql as $$
declare v_new_balance numeric; v_ledger_id uuid; v_payment_id uuid;
begin
  if p_direction not in ('received','given') then
    raise exception 'direction must be received or given' using errcode = '22000';
  end if;

  update customers set current_balance = current_balance - p_amount where id = p_customer_id returning current_balance into v_new_balance;
  if not found then raise exception 'customer not found' using errcode = 'P0002'; end if;

  insert into customer_ledger_entries (customer_id, type, direction, amount, running_balance, note)
  values (p_customer_id, 'payment', p_direction, p_amount, v_new_balance, coalesce(p_note, ''))
  returning id into v_ledger_id;

  insert into payments (customer_id, amount, direction, note, ledger_entry_id)
  values (p_customer_id, p_amount, p_direction, p_note, v_ledger_id) returning id into v_payment_id;

  return jsonb_build_object('paymentId', v_payment_id, 'ledgerEntryId', v_ledger_id, 'newCustomerBalance', v_new_balance);
end $$;

grant execute on all functions in schema public to authenticated;
'@
Set-Content -Path (Join-Path $Migrations "0002_functions.sql") -Value $Functions -Encoding UTF8

Write-Host "==> Migration files written." -ForegroundColor Green

# ----------------------------------------------------------------------------
# Supabase CLI: login, init, link, push
# ----------------------------------------------------------------------------
Set-Location $Backend
Write-Host "==> supabase login (browser tab will open if needed)..." -ForegroundColor Cyan
npx --yes supabase login

if (-not (Test-Path (Join-Path $Backend "supabase\config.toml"))) {
    Write-Host "==> supabase init..." -ForegroundColor Cyan
    npx --yes supabase init
}

Write-Host "==> supabase link --project-ref $ProjectRef ..." -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    npx --yes supabase link --project-ref $ProjectRef
} else {
    npx --yes supabase link --project-ref $ProjectRef --password "$DbPassword"
}

Write-Host "==> supabase db push (applying migrations)..." -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    npx --yes supabase db push
} else {
    npx --yes supabase db push --password "$DbPassword"
}

Set-Location $Root
Write-Host ""
Write-Host "==> DONE. Backend schema + 10 RPC functions deployed to $SupaUrl" -ForegroundColor Green
Write-Host "==> Test any RPC from your frontend via: supabase.rpc('fn_create_purchase_receipt', {...})" -ForegroundColor Green
Write-Host "==> Reminder: rotate any secret key that was ever pasted in chat, via Dashboard -> API Keys." -ForegroundColor Yellow