<#
  add-purchase-orders-and-treasury.ps1
  GhaniFoods - Phase 0 / Batch A: Purchase Order enforcement + Bank/Cash treasury

  Client requirements addressed in this batch:
    - "Without purchase order nothing should get added"
    - "Received ka pata ho kahan ho raha he" / "Bank or cash" / "Sara
      balance mantain ho"

  What this script does:
    Creates a NEW Supabase migration file:
      apps/backend/supabase/migrations/0008_purchase_orders_and_treasury.sql

    That migration adds:
      1. purchase_orders + purchase_order_lines tables (draft/sent/received/
         closed status)
      2. fn_create_purchase_order() - creates a PO with line items
      3. po_id column added to purchase_receipts (nullable, so existing
         historical receipts are not broken)
      4. fn_create_purchase_receipt_from_po() - the ONLY way to record a
         goods-received purchase from now on. It requires a valid,
         not-yet-fully-received PO, validates quantities against what's
         still outstanding on that PO, updates stock/avg cost (same
         weighted-average logic as before), and marks the PO
         'received' or 'partially_received' accordingly.
      5. The OLD fn_create_purchase_receipt(...) is intentionally left in
         place (so nothing already deployed breaks instantly) but is
         marked deprecated in a comment - Batch B (frontend wiring) will
         remove all frontend calls to it, and a later cleanup batch will
         drop it once you confirm nothing still calls it.
      6. treasury_accounts table, seeded with exactly two rows: 'Bank'
         and 'Cash', each with a running balance.
      7. treasury_transactions table - every Bank/Cash movement logged
         here (linked to a payment/receipt).
      8. fn_record_payment(...) updated to REQUIRE a p_method argument
         ('bank' or 'cash') and to update the matching treasury account's
         balance in the same transaction.

  IMPORTANT - this script only WRITES the migration file. It does not run
  it. After running this script, apply the migration the same way you
  apply your existing ones (Supabase CLI: supabase db push, or however
  you currently deploy apps/backend/supabase/migrations/*.sql).

  Run this from the repo root:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\add-purchase-orders-and-treasury.ps1
    .\add-purchase-orders-and-treasury.ps1 -WhatIf
#>

param(
    [switch]$WhatIf
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

function Write-FileUtf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

$migrationsDir = Join-Path $root "apps\backend\supabase\migrations"
if (-not (Test-Path -LiteralPath $migrationsDir)) {
    Write-Fail "Not found: $migrationsDir"
    Write-Fail "Make sure you're running this from the GhaniFoods repo root."
    exit 1
}

$migrationPath = Join-Path $migrationsDir "0008_purchase_orders_and_treasury.sql"

Write-Step "[1/1] Writing migration 0008_purchase_orders_and_treasury.sql..."

if (Test-Path -LiteralPath $migrationPath) {
    Write-Skip "Already exists - $migrationPath"
    Write-Skip "Delete it first if you want this script to regenerate it."
    exit 0
}

$sql = @'
-- 0008_purchase_orders_and_treasury.sql
-- Phase 0 / Batch A: Purchase Order enforcement + Bank/Cash treasury
-- ------------------------------------------------------------------

-- ===================== PURCHASE ORDERS =====================
create table if not exists purchase_orders (
  id uuid primary key default gen_random_uuid(),
  po_number text unique not null,
  supplier_id uuid not null references suppliers(id),
  po_date date not null default current_date,
  status text not null default 'draft'
    check (status in ('draft', 'sent', 'partially_received', 'received', 'closed')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  po_id uuid not null references purchase_orders(id) on delete cascade,
  raw_material_id uuid not null references raw_materials(id),
  qty_ordered numeric(14,3) not null check (qty_ordered > 0),
  qty_received numeric(14,3) not null default 0 check (qty_received >= 0),
  expected_unit_cost numeric(14,2) not null check (expected_unit_cost >= 0),
  created_at timestamptz not null default now()
);
create index if not exists idx_pol_po on purchase_order_lines(po_id);
create index if not exists idx_pol_material on purchase_order_lines(raw_material_id);

alter table purchase_orders enable row level security;
alter table purchase_order_lines enable row level security;

drop policy if exists auth_all_purchase_orders on purchase_orders;
create policy auth_all_purchase_orders on purchase_orders for all to authenticated using (true) with check (true);

drop policy if exists auth_all_purchase_order_lines on purchase_order_lines;
create policy auth_all_purchase_order_lines on purchase_order_lines for all to authenticated using (true) with check (true);

-- ===================== fn_create_purchase_order =====================
create or replace function fn_create_purchase_order(
  p_supplier_id uuid, p_po_date date, p_notes text, p_items jsonb
) returns jsonb language plpgsql as $$
declare
  v_po_id uuid; v_po_number text; v_next_num integer;
  v_item jsonb; v_lines jsonb := '[]'::jsonb;
begin
  if p_items is null or jsonb_array_length(p_items) < 1 then
    raise exception 'at least one line item is required' using errcode = '22000';
  end if;

  select coalesce(max(substring(po_number from 'po-(\d+)')::integer), 1000) + 1
    into v_next_num from purchase_orders;
  v_po_number := 'po-' || v_next_num;

  insert into purchase_orders (po_number, supplier_id, po_date, notes, status)
  values (v_po_number, p_supplier_id, p_po_date, p_notes, 'sent')
  returning id into v_po_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    if not exists (select 1 from raw_materials where id = (v_item->>'rawMaterialId')::uuid) then
      raise exception 'raw material not found' using errcode = 'P0002';
    end if;

    insert into purchase_order_lines (po_id, raw_material_id, qty_ordered, expected_unit_cost)
    values (v_po_id, (v_item->>'rawMaterialId')::uuid, (v_item->>'qty')::numeric, (v_item->>'expectedUnitCost')::numeric);

    v_lines := v_lines || jsonb_build_object(
      'rawMaterialId', v_item->>'rawMaterialId',
      'qtyOrdered', v_item->>'qty',
      'expectedUnitCost', v_item->>'expectedUnitCost'
    );
  end loop;

  return jsonb_build_object('id', v_po_id, 'poNumber', v_po_number, 'supplierId', p_supplier_id,
    'poDate', p_po_date, 'status', 'sent', 'lines', v_lines);
end $$;

-- ===================== purchase_receipts: link to PO =====================
alter table purchase_receipts
  add column if not exists po_id uuid references purchase_orders(id);
create index if not exists idx_pr_po on purchase_receipts(po_id);

-- ===================== fn_create_purchase_receipt_from_po =====================
-- The ONLY supported way to record a goods-received purchase from now on.
-- Requires a valid PO that still has outstanding quantity on at least one
-- of the lines being received. Rejects any line that tries to receive
-- more than what remains outstanding on that PO line, and rejects any
-- raw material not present on the PO at all.
create or replace function fn_create_purchase_receipt_from_po(
  p_po_id uuid, p_purchase_date date, p_items jsonb
) returns jsonb language plpgsql as $$
declare
  v_po purchase_orders%rowtype; v_receipt_id uuid; v_item jsonb;
  v_pol purchase_order_lines%rowtype; v_rm raw_materials%rowtype;
  v_new_qty numeric; v_new_avg numeric; v_lines jsonb := '[]'::jsonb;
  v_remaining_outstanding numeric;
begin
  if p_items is null or jsonb_array_length(p_items) < 1 then
    raise exception 'items required' using errcode = '22000';
  end if;

  select * into v_po from purchase_orders where id = p_po_id for update;
  if not found then
    raise exception 'Purchase Order not found - a receipt cannot be created without a valid PO' using errcode = 'P0002';
  end if;
  if v_po.status = 'closed' then
    raise exception 'This Purchase Order is closed and cannot receive further goods' using errcode = '23514';
  end if;

  insert into purchase_receipts (supplier_id, purchase_date, po_id)
  values (v_po.supplier_id, p_purchase_date, v_po.id) returning id into v_receipt_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_pol from purchase_order_lines
      where po_id = v_po.id and raw_material_id = (v_item->>'rawMaterialId')::uuid
      for update;
    if not found then
      raise exception 'This raw material is not on the Purchase Order - nothing can be received without a matching PO line' using errcode = '23514';
    end if;

    v_remaining_outstanding := v_pol.qty_ordered - v_pol.qty_received;
    if (v_item->>'qty')::numeric > v_remaining_outstanding then
      raise exception 'Cannot receive % - only % remains outstanding on this PO line', (v_item->>'qty'), v_remaining_outstanding
        using errcode = '23514';
    end if;

    select * into v_rm from raw_materials where id = v_pol.raw_material_id for update;

    v_new_qty := v_rm.quantity_in_stock + (v_item->>'qty')::numeric;
    v_new_avg := ((v_rm.quantity_in_stock * v_rm.avg_unit_cost) + ((v_item->>'qty')::numeric * (v_item->>'cost')::numeric)) / v_new_qty;

    update raw_materials set quantity_in_stock = v_new_qty, avg_unit_cost = v_new_avg where id = v_rm.id;
    update purchase_order_lines set qty_received = qty_received + (v_item->>'qty')::numeric where id = v_pol.id;

    insert into purchase_receipt_lines (receipt_id, raw_material_id, qty, cost, avg_cost_after)
    values (v_receipt_id, v_rm.id, (v_item->>'qty')::numeric, (v_item->>'cost')::numeric, v_new_avg);

    v_lines := v_lines || jsonb_build_object(
      'rawMaterialId', v_rm.id, 'qty', v_item->>'qty', 'cost', v_item->>'cost',
      'newAvgUnitCost', v_new_avg, 'newQuantityInStock', v_new_qty
    );
  end loop;

  -- Recompute PO status from all its lines.
  if exists (select 1 from purchase_order_lines where po_id = v_po.id and qty_received < qty_ordered) then
    if exists (select 1 from purchase_order_lines where po_id = v_po.id and qty_received > 0) then
      update purchase_orders set status = 'partially_received' where id = v_po.id;
    end if;
  else
    update purchase_orders set status = 'received' where id = v_po.id;
  end if;

  return jsonb_build_object('receiptId', v_receipt_id, 'poId', v_po.id, 'poNumber', v_po.po_number,
    'purchaseDate', p_purchase_date, 'lines', v_lines);
end $$;

-- NOTE: fn_create_purchase_receipt(...) (the old, PO-less version from
-- 0002_functions.sql) is DEPRECATED as of this migration but intentionally
-- left in the database so nothing already deployed breaks immediately.
-- Batch B will remove every frontend call to it. Once you confirm nothing
-- calls it anymore, a later cleanup migration will DROP it so it's no
-- longer possible to add stock without a PO by any path.

-- ===================== TREASURY: BANK / CASH =====================
create table if not exists treasury_accounts (
  id uuid primary key default gen_random_uuid(),
  name text unique not null check (name in ('Bank', 'Cash')),
  balance numeric(14,2) not null default 0,
  created_at timestamptz not null default now()
);

insert into treasury_accounts (name, balance)
select 'Bank', 0 where not exists (select 1 from treasury_accounts where name = 'Bank');
insert into treasury_accounts (name, balance)
select 'Cash', 0 where not exists (select 1 from treasury_accounts where name = 'Cash');

create table if not exists treasury_transactions (
  id uuid primary key default gen_random_uuid(),
  treasury_account_id uuid not null references treasury_accounts(id),
  direction text not null check (direction in ('in', 'out')),
  amount numeric(14,2) not null check (amount > 0),
  balance_after numeric(14,2) not null,
  reference_type text not null check (reference_type in ('customer_payment', 'supplier_payment', 'adjustment')),
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists idx_tt_account on treasury_transactions(treasury_account_id);

alter table treasury_accounts enable row level security;
alter table treasury_transactions enable row level security;

drop policy if exists auth_all_treasury_accounts on treasury_accounts;
create policy auth_all_treasury_accounts on treasury_accounts for all to authenticated using (true) with check (true);

drop policy if exists auth_all_treasury_transactions on treasury_transactions;
create policy auth_all_treasury_transactions on treasury_transactions for all to authenticated using (true) with check (true);

-- ===================== fn_record_payment: now requires p_method =====================
-- direction 'received' = money coming IN from a customer (treasury goes up)
-- direction 'given'    = money going OUT (e.g. paid to a supplier, or a
--                        refund/adjustment) (treasury goes down)
create or replace function fn_record_payment(
  p_customer_id uuid, p_amount numeric, p_direction text, p_method text, p_note text default null
) returns jsonb language plpgsql as $$
declare
  v_new_balance numeric; v_ledger_id uuid; v_payment_id uuid;
  v_treasury treasury_accounts%rowtype; v_treasury_direction text; v_treasury_new_balance numeric;
begin
  if p_direction not in ('received','given') then
    raise exception 'direction must be received or given' using errcode = '22000';
  end if;
  if p_method not in ('bank','cash') then
    raise exception 'method must be bank or cash' using errcode = '22000';
  end if;

  update customers set current_balance = current_balance - p_amount where id = p_customer_id returning current_balance into v_new_balance;
  if not found then raise exception 'customer not found' using errcode = 'P0002'; end if;

  insert into customer_ledger_entries (customer_id, type, direction, amount, running_balance, note)
  values (p_customer_id, 'payment', p_direction, p_amount, v_new_balance, coalesce(p_note, ''))
  returning id into v_ledger_id;

  insert into payments (customer_id, amount, direction, note, ledger_entry_id)
  values (p_customer_id, p_amount, p_direction, p_note, v_ledger_id) returning id into v_payment_id;

  -- money received from a customer -> treasury goes UP; money given -> DOWN
  v_treasury_direction := case when p_direction = 'received' then 'in' else 'out' end;

  select * into v_treasury from treasury_accounts
    where name = (case when p_method = 'bank' then 'Bank' else 'Cash' end)
    for update;

  v_treasury_new_balance := case when v_treasury_direction = 'in'
    then v_treasury.balance + p_amount
    else v_treasury.balance - p_amount end;

  update treasury_accounts set balance = v_treasury_new_balance where id = v_treasury.id;

  insert into treasury_transactions (treasury_account_id, direction, amount, balance_after, reference_type, reference_id, note)
  values (v_treasury.id, v_treasury_direction, p_amount, v_treasury_new_balance, 'customer_payment', v_payment_id, p_note);

  return jsonb_build_object('paymentId', v_payment_id, 'ledgerEntryId', v_ledger_id,
    'newCustomerBalance', v_new_balance, 'treasuryAccount', v_treasury.name, 'newTreasuryBalance', v_treasury_new_balance);
end $$;

grant execute on function fn_create_purchase_order(uuid, date, text, jsonb) to authenticated;
grant execute on function fn_create_purchase_receipt_from_po(uuid, date, jsonb) to authenticated;
grant execute on function fn_record_payment(uuid, numeric, text, text, text) to authenticated;
'@

if ($WhatIf) {
    Write-Host ""
    Write-Host "WhatIf mode - would create:" -ForegroundColor Magenta
    Write-Host "  $migrationPath" -ForegroundColor Magenta
}
else {
    Write-FileUtf8NoBom -Path $migrationPath -Content $sql
    Write-Ok "Created: $migrationPath"
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Apply this migration the same way you apply your existing ones" -ForegroundColor Cyan
Write-Host "     (Supabase CLI db push, or your usual deploy step)." -ForegroundColor Cyan
Write-Host "  2. Verify in Supabase: purchase_orders, purchase_order_lines," -ForegroundColor Cyan
Write-Host "     treasury_accounts (should show Bank=0, Cash=0), treasury_transactions." -ForegroundColor Cyan
Write-Host "  3. IMPORTANT: fn_record_payment now requires a 5th argument (p_method)." -ForegroundColor Cyan
Write-Host "     The frontend still calls the OLD 4-argument version - this will break" -ForegroundColor Cyan
Write-Host "     the 'Record Payment' dialog until Batch B (frontend wiring) is applied." -ForegroundColor Cyan
Write-Host "     Do not use Record Payment in the live app until Batch B is done." -ForegroundColor Cyan
Write-Host ""
Write-Host "Once this migration is applied and confirmed in Supabase, tell me and" -ForegroundColor Cyan
Write-Host "I will give you Batch B: frontend wiring (PO screens, Bank/Cash selector" -ForegroundColor Cyan
Write-Host "on payments, and updating the Purchase Receipt UI to require a PO)." -ForegroundColor Cyan