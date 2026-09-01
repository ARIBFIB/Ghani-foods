-- Safety net for the Supplier Payments feature. If fn_record_supplier_payment
-- is missing or broken, the supplier-payments edge function fails even when
-- deployed correctly. This (re)creates it:
--   * decreases suppliers.current_balance by the payment amount
--   * moves the amount OUT of the chosen treasury account (Bank/Cash)
--   * writes a supplier_ledger_entries row with the resulting running balance

create or replace function public.fn_record_supplier_payment(
  p_supplier_id uuid,
  p_amount numeric,
  p_method text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_supplier        record;
  v_new_balance     numeric;
  v_ledger_id       uuid;
  v_treasury_id     uuid;
  v_treasury_name   text;
begin
  if p_supplier_id is null then
    raise exception 'p_supplier_id is required' using errcode = '22004';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'p_amount must be greater than 0' using errcode = '22004';
  end if;

  if p_method is null or p_method not in ('bank', 'cash') then
    raise exception 'p_method must be ''bank'' or ''cash''' using errcode = '22004';
  end if;

  select * into v_supplier
  from public.suppliers
  where id = p_supplier_id
  for update;

  if not found then
    raise exception 'supplier not found' using errcode = 'P0002';
  end if;

  v_treasury_name := case when p_method = 'bank' then 'Bank' else 'Cash' end;

  select id into v_treasury_id
  from public.treasury_accounts
  where name = v_treasury_name
  for update;

  if not found then
    raise exception 'treasury account % not found', v_treasury_name using errcode = 'P0002';
  end if;

  v_new_balance := coalesce(v_supplier.current_balance, 0) - p_amount;

  update public.suppliers
  set current_balance = v_new_balance
  where id = p_supplier_id;

  update public.treasury_accounts
  set balance = balance - p_amount
  where id = v_treasury_id;

  insert into public.supplier_ledger_entries
    (supplier_id, type, direction, amount, running_balance, entry_date, note)
  values
    (p_supplier_id, 'payment', 'given', p_amount, v_new_balance, now(), p_note)
  returning id into v_ledger_id;

  return jsonb_build_object(
    'id', v_ledger_id,
    'supplierId', p_supplier_id,
    'newBalance', v_new_balance
  );
end;
$fn$;

grant execute on function public.fn_record_supplier_payment(uuid, numeric, text, text) to authenticated;
