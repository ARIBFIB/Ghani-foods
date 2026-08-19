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
