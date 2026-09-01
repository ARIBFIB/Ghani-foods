-- Fix: rebuild fn_supplier_balance against the REAL live table
-- (public.supplier_ledger_entries), not "supplier_ledger" (which does
-- not exist). Confirmed real schema:
--   public.supplier_ledger_entries(
--     id, supplier_id, type, amount, running_balance,
--     note, reference_id, entry_date, created_at
--   )
--
-- running_balance ALREADY EXISTS on this table and may already be
-- maintained by a trigger or by application/edge-function code on
-- insert. This migration does NOT recompute or rewrite it - it only
-- reads the latest stored value, so it cannot conflict with whatever
-- already sets it today.

-- Diagnostic: print every trigger on supplier_ledger_entries into the
-- `supabase db push` output, so you can see right now whether the DB
-- itself is maintaining running_balance.
do $$
declare
  trg record;
  trg_count int := 0;
begin
  for trg in
    select tgname
    from pg_trigger
    where tgrelid = 'public.supplier_ledger_entries'::regclass
      and not tgisinternal
  loop
    trg_count := trg_count + 1;
    raise notice 'supplier_ledger_entries has existing trigger: %', trg.tgname;
  end loop;

  if trg_count = 0 then
    raise notice 'supplier_ledger_entries has NO triggers - running_balance is most likely written by application/edge-function code, not the DB. Check purchase-receipts / supplier-payments / fn_record_supplier_payment before assuming it is safe to change how it is set.';
  end if;
end;
$$;

-- Orphan-entry diagnostic, using the REAL column (reference_id) - the
-- old migration checked purchase_receipt_id/payment_id, which do not
-- exist on this table.
create or replace view v_supplier_ledger_orphans as
select *
from public.supplier_ledger_entries
where reference_id is null
  and type in ('purchase', 'payment');
  -- NOTE: entries of type 'adjustment' or 'debit_note' may legitimately
  -- have no reference_id - adjust this filter if that's wrong for you.

-- fn_supplier_balance: reads the latest running_balance already on the
-- table for this supplier. Does not recompute a second balance.
create or replace function fn_supplier_balance(p_supplier_id uuid)
returns numeric
language sql
stable
as $$
  select coalesce(
    (
      select running_balance
      from public.supplier_ledger_entries
      where supplier_id = p_supplier_id
      order by entry_date desc, created_at desc, id desc
      limit 1
    ),
    0
  );
$$;
