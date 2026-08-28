<#
  apply-step1-contra-returns.ps1
  GhaniFoods - Step 1: Contra Voucher + Credit Note (Sales Return) +
  Debit Note (Purchase Return) + Supplier Ledger/Payments

  WHY THIS SCRIPT:
  The client's reference system needs Sales Return, Purchase Return, and
  Bank<->Cash transfers as first-class vouchers, and every supplier needs
  a running balance/ledger (like customers already have). None of this
  existed yet:
    - suppliers had NO current_balance / ledger at all
    - there was NO way to pay a supplier (only customer payments existed)
    - there was NO Sales Return / Purchase Return mechanism
    - there was NO Bank<->Cash transfer (Contra) mechanism

  This script creates ONE new migration file:
    apps/backend/supabase/migrations/0009_contra_returns_supplier_ledger.sql

  It does NOT touch any existing file. It is idempotent - safe to re-run
  (the .sql file itself is also idempotent: uses `create table if not
  exists`, `add column if not exists`, `create or replace function`).

  After this script runs, you still need to push the migration to Supabase
  yourself (instructions are printed at the end) - this script only writes
  the file to disk, it does not deploy.

  Run this from the repo root:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\apply-step1-contra-returns.ps1
    .\apply-step1-contra-returns.ps1 -WhatIf
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

$ErrorActionPreference = "Stop"

$migrationDir = "apps\backend\supabase\migrations"
$migrationPath = Join-Path $migrationDir "0009_contra_returns_supplier_ledger.sql"

if (-not (Test-Path -LiteralPath $migrationDir)) {
    Write-Fail "Cannot find $migrationDir - are you running this from the repo root?"
    exit 1
}

$sql = @'
-- 0009_contra_returns_supplier_ledger.sql
-- Step 1: Supplier ledger/payments, Credit Note (Sales Return),
-- Debit Note (Purchase Return), Contra Voucher (Bank <-> Cash transfer)
-- ------------------------------------------------------------------

-- ===================== SUPPLIER BALANCE + LEDGER =====================
alter table suppliers
  add column if not exists current_balance numeric(14,2) not null default 0;

create table if not exists supplier_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id),
  type text not null check (type in ('purchase','purchase_return','payment','adjustment')),
  amount numeric(14,2) not null check (amount > 0),
  running_balance numeric(14,2) not null,
  note text,
  reference_id uuid,
  entry_date date not null default current_date,
  created_at timestamptz not null default now()
);
create index if not exists idx_sle_supplier on supplier_ledger_entries(supplier_id);

create table if not exists supplier_payments (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references suppliers(id),
  amount numeric(14,2) not null check (amount > 0),
  method text not null check (method in ('bank','cash')),
  note text,
  paid_at date not null default current_date,
  ledger_entry_id uuid references supplier_ledger_entries(id),
  created_at timestamptz not null default now()
);

alter table supplier_ledger_entries enable row level security;
alter table supplier_payments enable row level security;

drop policy if exists auth_all_supplier_ledger_entries on supplier_ledger_entries;
create policy auth_all_supplier_ledger_entries on supplier_ledger_entries for all to authenticated using (true) with check (true);

drop policy if exists auth_all_supplier_payments on supplier_payments;
create policy auth_all_supplier_payments on supplier_payments for all to authenticated using (true) with check (true);

-- Every existing purchase receipt (via PO) should also raise the
-- supplier's balance (goods received on credit = we owe them more).
-- Backfill supplier balances from already-received receipts so reports
-- are correct from day one.
do $$
declare v_row record; v_running numeric;
begin
  if (select count(*) from supplier_ledger_entries) = 0 then
    for v_row in
      select pr.supplier_id, pr.id as receipt_id, pr.created_at,
             sum(prl.qty * prl.cost) as total
      from purchase_receipts pr
      join purchase_receipt_lines prl on prl.receipt_id = pr.id
      group by pr.supplier_id, pr.id, pr.created_at
      order by pr.created_at
    loop
      update suppliers set current_balance = current_balance + v_row.total
        where id = v_row.supplier_id
        returning current_balance into v_running;

      insert into supplier_ledger_entries (supplier_id, type, amount, running_balance, reference_id, entry_date)
      values (v_row.supplier_id, 'purchase', v_row.total, v_running, v_row.receipt_id, v_row.created_at::date);
    end loop;
  end if;
end $$;

-- ===================== fn_create_purchase_receipt_from_po: also ledger the supplier =====================
create or replace function fn_create_purchase_receipt_from_po(
  p_po_id uuid, p_purchase_date date, p_items jsonb
) returns jsonb language plpgsql as $$
declare
  v_po purchase_orders%rowtype; v_receipt_id uuid; v_item jsonb;
  v_pol purchase_order_lines%rowtype; v_rm raw_materials%rowtype;
  v_new_qty numeric; v_new_avg numeric; v_lines jsonb := '[]'::jsonb;
  v_remaining_outstanding numeric; v_receipt_total numeric := 0; v_new_supplier_balance numeric;
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

    v_receipt_total := v_receipt_total + ((v_item->>'qty')::numeric * (v_item->>'cost')::numeric);

    v_lines := v_lines || jsonb_build_object(
      'rawMaterialId', v_rm.id, 'qty', v_item->>'qty', 'cost', v_item->>'cost',
      'newAvgUnitCost', v_new_avg, 'newQuantityInStock', v_new_qty
    );
  end loop;

  -- NEW: raise supplier balance (we now owe them for this receipt) and ledger it.
  update suppliers set current_balance = current_balance + v_receipt_total where id = v_po.supplier_id
    returning current_balance into v_new_supplier_balance;
  insert into supplier_ledger_entries (supplier_id, type, amount, running_balance, reference_id)
  values (v_po.supplier_id, 'purchase', v_receipt_total, v_new_supplier_balance, v_receipt_id);

  if exists (select 1 from purchase_order_lines where po_id = v_po.id and qty_received < qty_ordered) then
    if exists (select 1 from purchase_order_lines where po_id = v_po.id and qty_received > 0) then
      update purchase_orders set status = 'partially_received' where id = v_po.id;
    end if;
  else
    update purchase_orders set status = 'received' where id = v_po.id;
  end if;

  return jsonb_build_object('receiptId', v_receipt_id, 'poId', v_po.id, 'poNumber', v_po.po_number,
    'purchaseDate', p_purchase_date, 'lines', v_lines, 'receiptTotal', v_receipt_total,
    'newSupplierBalance', v_new_supplier_balance);
end $$;

-- ===================== fn_record_supplier_payment =====================
-- Paying a supplier reduces the amount we owe them and moves money out of
-- the chosen treasury account (Bank or Cash).
create or replace function fn_record_supplier_payment(
  p_supplier_id uuid, p_amount numeric, p_method text, p_note text default null
) returns jsonb language plpgsql as $$
declare
  v_new_balance numeric; v_ledger_id uuid; v_payment_id uuid;
  v_treasury treasury_accounts%rowtype; v_treasury_new_balance numeric;
begin
  if p_method not in ('bank','cash') then
    raise exception 'method must be bank or cash' using errcode = '22000';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive' using errcode = '22000';
  end if;

  update suppliers set current_balance = current_balance - p_amount where id = p_supplier_id
    returning current_balance into v_new_balance;
  if not found then raise exception 'supplier not found' using errcode = 'P0002'; end if;

  insert into supplier_ledger_entries (supplier_id, type, amount, running_balance, note)
  values (p_supplier_id, 'payment', p_amount, v_new_balance, coalesce(p_note, ''))
  returning id into v_ledger_id;

  insert into supplier_payments (supplier_id, amount, method, note, ledger_entry_id)
  values (p_supplier_id, p_amount, p_method, p_note, v_ledger_id) returning id into v_payment_id;

  select * into v_treasury from treasury_accounts
    where name = (case when p_method = 'bank' then 'Bank' else 'Cash' end)
    for update;

  v_treasury_new_balance := v_treasury.balance - p_amount;
  update treasury_accounts set balance = v_treasury_new_balance where id = v_treasury.id;

  insert into treasury_transactions (treasury_account_id, direction, amount, balance_after, reference_type, reference_id, note)
  values (v_treasury.id, 'out', p_amount, v_treasury_new_balance, 'supplier_payment', v_payment_id, p_note);

  return jsonb_build_object('paymentId', v_payment_id, 'ledgerEntryId', v_ledger_id,
    'newSupplierBalance', v_new_balance, 'treasuryAccount', v_treasury.name, 'newTreasuryBalance', v_treasury_new_balance);
end $$;

-- ===================== CREDIT NOTE (SALES RETURN) =====================
create table if not exists credit_notes (
  id uuid primary key default gen_random_uuid(),
  credit_note_number text unique not null,
  invoice_id uuid not null references invoices(id),
  customer_id uuid not null references customers(id),
  return_date date not null default current_date,
  total_amount numeric(14,2) not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists credit_note_lines (
  id uuid primary key default gen_random_uuid(),
  credit_note_id uuid not null references credit_notes(id) on delete cascade,
  finished_carton_id uuid not null references finished_cartons(id),
  item_name text not null,
  qty integer not null check (qty > 0),
  unit_price numeric(14,2) not null,
  subtotal numeric(14,2) not null
);

alter table credit_notes enable row level security;
alter table credit_note_lines enable row level security;
drop policy if exists auth_all_credit_notes on credit_notes;
create policy auth_all_credit_notes on credit_notes for all to authenticated using (true) with check (true);
drop policy if exists auth_all_credit_note_lines on credit_note_lines;
create policy auth_all_credit_note_lines on credit_note_lines for all to authenticated using (true) with check (true);

-- p_lines: [{ "invoiceItemId": "...", "qty": 2 }]  (qty being returned)
-- Validates against the ORIGINAL invoice_items so you cannot return more
-- than was sold, and cannot return against a non-existent invoice line.
-- Reverses stock (adds back to finished_cartons) and reverses customer
-- balance (reduces what they owe).
create or replace function fn_create_credit_note(
  p_invoice_id uuid, p_lines jsonb, p_note text default null
) returns jsonb language plpgsql as $$
declare
  v_invoice invoices%rowtype; v_line jsonb; v_ii invoice_items%rowtype;
  v_already_returned integer; v_total numeric := 0; v_cn_id uuid; v_cn_number text; v_next_num integer;
  v_new_balance numeric; v_items jsonb := '[]'::jsonb;
begin
  if p_lines is null or jsonb_array_length(p_lines) < 1 then
    raise exception 'at least one line item is required' using errcode = '22000';
  end if;

  select * into v_invoice from invoices where id = p_invoice_id;
  if not found then raise exception 'invoice not found' using errcode = 'P0002'; end if;

  select coalesce(max(substring(credit_note_number from 'cn-(\d+)')::integer), 1000) + 1
    into v_next_num from credit_notes;
  v_cn_number := 'cn-' || v_next_num;

  insert into credit_notes (credit_note_number, invoice_id, customer_id, total_amount, note)
  values (v_cn_number, p_invoice_id, v_invoice.customer_id, 0, p_note)
  returning id into v_cn_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_ii from invoice_items where id = (v_line->>'invoiceItemId')::uuid and invoice_id = p_invoice_id;
    if not found then
      raise exception 'invoice item not found on this invoice' using errcode = 'P0002';
    end if;

    select coalesce(sum(cnl.qty), 0) into v_already_returned
      from credit_note_lines cnl
      join credit_notes cn on cn.id = cnl.credit_note_id
      where cn.invoice_id = p_invoice_id and cnl.finished_carton_id = v_ii.finished_carton_id;

    if (v_line->>'qty')::integer > (v_ii.qty - v_already_returned) then
      raise exception 'Cannot return % of "%" - only % remains returnable from this invoice',
        (v_line->>'qty'), v_ii.item_name, (v_ii.qty - v_already_returned) using errcode = '23514';
    end if;

    insert into credit_note_lines (credit_note_id, finished_carton_id, item_name, qty, unit_price, subtotal)
    values (v_cn_id, v_ii.finished_carton_id, v_ii.item_name, (v_line->>'qty')::integer, v_ii.unit_price,
      (v_line->>'qty')::integer * v_ii.unit_price);

    update finished_cartons set stock_qty = stock_qty + (v_line->>'qty')::integer where id = v_ii.finished_carton_id;

    v_total := v_total + ((v_line->>'qty')::integer * v_ii.unit_price);
    v_items := v_items || jsonb_build_object('financeCartonId', v_ii.finished_carton_id, 'itemName', v_ii.item_name,
      'qty', v_line->>'qty', 'unitPrice', v_ii.unit_price);
  end loop;

  update credit_notes set total_amount = v_total where id = v_cn_id;

  update customers set current_balance = current_balance - v_total where id = v_invoice.customer_id
    returning current_balance into v_new_balance;

  insert into customer_ledger_entries (customer_id, type, direction, amount, running_balance, reference_id)
  values (v_invoice.customer_id, 'adjustment', 'given', v_total, v_new_balance, v_cn_id);

  return jsonb_build_object('id', v_cn_id, 'creditNoteNumber', v_cn_number, 'invoiceId', p_invoice_id,
    'totalAmount', v_total, 'lines', v_items, 'newCustomerBalance', v_new_balance);
end $$;

-- ===================== DEBIT NOTE (PURCHASE RETURN) =====================
create table if not exists debit_notes (
  id uuid primary key default gen_random_uuid(),
  debit_note_number text unique not null,
  supplier_id uuid not null references suppliers(id),
  return_date date not null default current_date,
  total_amount numeric(14,2) not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists debit_note_lines (
  id uuid primary key default gen_random_uuid(),
  debit_note_id uuid not null references debit_notes(id) on delete cascade,
  raw_material_id uuid not null references raw_materials(id),
  qty numeric(14,3) not null check (qty > 0),
  cost numeric(14,2) not null check (cost > 0),
  subtotal numeric(14,2) not null
);

alter table debit_notes enable row level security;
alter table debit_note_lines enable row level security;
drop policy if exists auth_all_debit_notes on debit_notes;
create policy auth_all_debit_notes on debit_notes for all to authenticated using (true) with check (true);
drop policy if exists auth_all_debit_note_lines on debit_note_lines;
create policy auth_all_debit_note_lines on debit_note_lines for all to authenticated using (true) with check (true);

-- p_lines: [{ "rawMaterialId": "...", "qty": 5, "cost": 180 }]
-- Blocks if returning more than is currently in stock (i.e. some of it
-- has already been consumed in production - same safety rule as receipt
-- delete/edit). Reduces raw material stock and reduces supplier balance.
create or replace function fn_create_debit_note(
  p_supplier_id uuid, p_lines jsonb, p_note text default null
) returns jsonb language plpgsql as $$
declare
  v_line jsonb; v_rm raw_materials%rowtype; v_total numeric := 0;
  v_dn_id uuid; v_dn_number text; v_next_num integer;
  v_new_balance numeric; v_items jsonb := '[]'::jsonb;
begin
  if p_lines is null or jsonb_array_length(p_lines) < 1 then
    raise exception 'at least one line item is required' using errcode = '22000';
  end if;
  if not exists (select 1 from suppliers where id = p_supplier_id) then
    raise exception 'supplier not found' using errcode = 'P0002';
  end if;

  select coalesce(max(substring(debit_note_number from 'dn-(\d+)')::integer), 1000) + 1
    into v_next_num from debit_notes;
  v_dn_number := 'dn-' || v_next_num;

  insert into debit_notes (debit_note_number, supplier_id, total_amount, note)
  values (v_dn_number, p_supplier_id, 0, p_note) returning id into v_dn_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_rm from raw_materials where id = (v_line->>'rawMaterialId')::uuid for update;
    if not found then raise exception 'raw material not found' using errcode = 'P0002'; end if;

    if (v_line->>'qty')::numeric > v_rm.quantity_in_stock then
      raise exception 'Cannot return % of "%" - only % left in stock (some may already be used)',
        (v_line->>'qty'), v_rm.name, v_rm.quantity_in_stock using errcode = '23514';
    end if;

    insert into debit_note_lines (debit_note_id, raw_material_id, qty, cost, subtotal)
    values (v_dn_id, v_rm.id, (v_line->>'qty')::numeric, (v_line->>'cost')::numeric,
      (v_line->>'qty')::numeric * (v_line->>'cost')::numeric);

    update raw_materials set quantity_in_stock = quantity_in_stock - (v_line->>'qty')::numeric where id = v_rm.id;

    v_total := v_total + ((v_line->>'qty')::numeric * (v_line->>'cost')::numeric);
    v_items := v_items || jsonb_build_object('rawMaterialId', v_rm.id, 'name', v_rm.name,
      'qty', v_line->>'qty', 'cost', v_line->>'cost');
  end loop;

  update debit_notes set total_amount = v_total where id = v_dn_id;

  update suppliers set current_balance = current_balance - v_total where id = p_supplier_id
    returning current_balance into v_new_balance;

  insert into supplier_ledger_entries (supplier_id, type, amount, running_balance, reference_id)
  values (p_supplier_id, 'purchase_return', v_total, v_new_balance, v_dn_id);

  return jsonb_build_object('id', v_dn_id, 'debitNoteNumber', v_dn_number, 'supplierId', p_supplier_id,
    'totalAmount', v_total, 'lines', v_items, 'newSupplierBalance', v_new_balance);
end $$;

-- ===================== CONTRA VOUCHER (BANK <-> CASH) =====================
alter table treasury_transactions drop constraint if exists treasury_transactions_reference_type_check;
alter table treasury_transactions add constraint treasury_transactions_reference_type_check
  check (reference_type in ('customer_payment','supplier_payment','adjustment','contra'));

create table if not exists contra_vouchers (
  id uuid primary key default gen_random_uuid(),
  contra_number text unique not null,
  from_method text not null check (from_method in ('bank','cash')),
  to_method text not null check (to_method in ('bank','cash')),
  amount numeric(14,2) not null check (amount > 0),
  note text,
  created_at timestamptz not null default now(),
  check (from_method <> to_method)
);

alter table contra_vouchers enable row level security;
drop policy if exists auth_all_contra_vouchers on contra_vouchers;
create policy auth_all_contra_vouchers on contra_vouchers for all to authenticated using (true) with check (true);

create or replace function fn_create_contra_transfer(
  p_from_method text, p_to_method text, p_amount numeric, p_note text default null
) returns jsonb language plpgsql as $$
declare
  v_from treasury_accounts%rowtype; v_to treasury_accounts%rowtype;
  v_from_new numeric; v_to_new numeric; v_contra_id uuid; v_contra_number text; v_next_num integer;
begin
  if p_from_method not in ('bank','cash') or p_to_method not in ('bank','cash') then
    raise exception 'method must be bank or cash' using errcode = '22000';
  end if;
  if p_from_method = p_to_method then
    raise exception 'from and to accounts must be different' using errcode = '22000';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive' using errcode = '22000';
  end if;

  select * into v_from from treasury_accounts where name = (case when p_from_method = 'bank' then 'Bank' else 'Cash' end) for update;
  select * into v_to from treasury_accounts where name = (case when p_to_method = 'bank' then 'Bank' else 'Cash' end) for update;

  if v_from.balance < p_amount then
    raise exception 'Insufficient % balance: only Rs. % available', v_from.name, v_from.balance using errcode = '23514';
  end if;

  select coalesce(max(substring(contra_number from 'ctr-(\d+)')::integer), 1000) + 1 into v_next_num from contra_vouchers;
  v_contra_number := 'ctr-' || v_next_num;

  insert into contra_vouchers (contra_number, from_method, to_method, amount, note)
  values (v_contra_number, p_from_method, p_to_method, p_amount, p_note) returning id into v_contra_id;

  v_from_new := v_from.balance - p_amount;
  v_to_new := v_to.balance + p_amount;

  update treasury_accounts set balance = v_from_new where id = v_from.id;
  update treasury_accounts set balance = v_to_new where id = v_to.id;

  insert into treasury_transactions (treasury_account_id, direction, amount, balance_after, reference_type, reference_id, note)
  values (v_from.id, 'out', p_amount, v_from_new, 'contra', v_contra_id, p_note);
  insert into treasury_transactions (treasury_account_id, direction, amount, balance_after, reference_type, reference_id, note)
  values (v_to.id, 'in', p_amount, v_to_new, 'contra', v_contra_id, p_note);

  return jsonb_build_object('id', v_contra_id, 'contraNumber', v_contra_number, 'fromMethod', p_from_method,
    'toMethod', p_to_method, 'amount', p_amount, 'newFromBalance', v_from_new, 'newToBalance', v_to_new);
end $$;

grant execute on function fn_record_supplier_payment(uuid, numeric, text, text) to authenticated;
grant execute on function fn_create_credit_note(uuid, jsonb, text) to authenticated;
grant execute on function fn_create_debit_note(uuid, jsonb, text) to authenticated;
grant execute on function fn_create_contra_transfer(text, text, numeric, text) to authenticated;
grant execute on function fn_create_purchase_receipt_from_po(uuid, date, jsonb) to authenticated;
'@

Write-Step "Writing migration file..."

if ($WhatIf) {
    if (Test-Path -LiteralPath $migrationPath) {
        Write-Skip "[WhatIf] Would OVERWRITE $migrationPath"
    } else {
        Write-Ok "[WhatIf] Would CREATE $migrationPath"
    }
} else {
    Write-FileUtf8NoBom -Path $migrationPath -Content $sql
    Write-Ok "Wrote $migrationPath"
}

Write-Step "Done. Next steps:"
Write-Host "  1. Review the new file: $migrationPath" -ForegroundColor Cyan
Write-Host "  2. Push it to Supabase, e.g.:" -ForegroundColor Cyan
Write-Host "       cd apps\backend" -ForegroundColor Cyan
Write-Host "       supabase db push" -ForegroundColor Cyan
Write-Host "     (or your usual deploy command - same one you used for 0008)" -ForegroundColor Cyan
Write-Host "  3. Once deployed, reply here and I'll give you Step 2 (frontend: Sales Return, Purchase Return, and Bank<->Cash Transfer screens)." -ForegroundColor Cyan