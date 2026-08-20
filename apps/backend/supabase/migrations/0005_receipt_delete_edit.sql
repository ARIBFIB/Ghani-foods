-- 0005_receipt_delete_edit.sql
-- Adds safe delete + edit for purchase receipts.
--
-- Design: rather than trying to algebraically "reverse" the weighted-average
-- cost formula (error prone, hard to audit), both functions fully RECOMPUTE
-- each affected raw material's quantity_in_stock and avg_unit_cost from the
-- remaining purchase_receipt_lines rows after the change. This is always
-- correct and matches exactly what fn_create_purchase_receipt would produce
-- if the receipts had been entered in the remaining order.
--
-- Both functions BLOCK the change (raise an exception, which rolls back the
-- whole transaction) if it would drive any affected raw material's stock
-- negative - i.e. if some of that receipt's stock has already been consumed
-- by a production batch, wrapper/box run, etc.

create or replace function fn_recompute_raw_material_stock(p_raw_material_id uuid)
returns void as $$
declare
  v_qty numeric;
  v_avg_cost numeric;
begin
  select coalesce(sum(qty), 0),
         case when coalesce(sum(qty), 0) = 0 then 0 else sum(qty * cost) / sum(qty) end
    into v_qty, v_avg_cost
    from purchase_receipt_lines
   where raw_material_id = p_raw_material_id;

  update raw_materials
     set quantity_in_stock = v_qty,
         avg_unit_cost = v_avg_cost
   where id = p_raw_material_id;
end;
$$ language plpgsql;

-- ---------------------------------------------------------------------
-- Delete a whole receipt
-- ---------------------------------------------------------------------
create or replace function fn_delete_purchase_receipt(p_receipt_id uuid)
returns json as $$
declare
  v_line record;
  v_material_ids uuid[] := '{}';
  v_material_name text;
begin
  if not exists (select 1 from purchase_receipts where id = p_receipt_id) then
    raise exception 'Receipt not found' using errcode = 'P0002';
  end if;

  for v_line in
    select rl.*, rm.name as material_name, rm.quantity_in_stock as current_stock
      from purchase_receipt_lines rl
      join raw_materials rm on rm.id = rl.raw_material_id
     where rl.receipt_id = p_receipt_id
  loop
    if v_line.current_stock - v_line.qty < -0.0001 then
      raise exception 'Cannot delete: % of "%" from this receipt has already been used elsewhere (only % left in stock)',
        v_line.qty, v_line.material_name, v_line.current_stock
        using errcode = '23514';
    end if;
    v_material_ids := array_append(v_material_ids, v_line.raw_material_id);
  end loop;

  delete from purchase_receipt_lines where receipt_id = p_receipt_id;
  delete from purchase_receipts where id = p_receipt_id;

  perform fn_recompute_raw_material_stock(m) from unnest(v_material_ids) as m;

  return json_build_object('ok', true);
end;
$$ language plpgsql security definer;

-- ---------------------------------------------------------------------
-- Edit an existing receipt's line quantities/costs (supplier + date too)
-- p_items replaces ALL lines on the receipt (same shape as create).
-- ---------------------------------------------------------------------
create or replace function fn_update_purchase_receipt(
  p_receipt_id uuid,
  p_supplier_id uuid,
  p_purchase_date date,
  p_items jsonb
)
returns json as $$
declare
  v_old_material_ids uuid[] := '{}';
  v_new_material_ids uuid[] := '{}';
  v_all_material_ids uuid[];
  v_item jsonb;
  v_bad record;
begin
  if not exists (select 1 from purchase_receipts where id = p_receipt_id) then
    raise exception 'Receipt not found' using errcode = 'P0002';
  end if;

  select array_agg(raw_material_id) into v_old_material_ids
    from purchase_receipt_lines where receipt_id = p_receipt_id;

  delete from purchase_receipt_lines where receipt_id = p_receipt_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into purchase_receipt_lines (receipt_id, raw_material_id, qty, cost)
    values (
      p_receipt_id,
      (v_item->>'rawMaterialId')::uuid,
      (v_item->>'qty')::numeric,
      (v_item->>'cost')::numeric
    );
    v_new_material_ids := array_append(v_new_material_ids, (v_item->>'rawMaterialId')::uuid);
  end loop;

  update purchase_receipts
     set supplier_id = p_supplier_id,
         purchase_date = p_purchase_date
   where id = p_receipt_id;

  select array_agg(distinct m) into v_all_material_ids
    from unnest(coalesce(v_old_material_ids, '{}') || coalesce(v_new_material_ids, '{}')) as m;

  perform fn_recompute_raw_material_stock(m) from unnest(v_all_material_ids) as m;

  select rm.name, rm.quantity_in_stock into v_bad
    from raw_materials rm
   where rm.id = any(v_all_material_ids) and rm.quantity_in_stock < -0.0001
   limit 1;

  if v_bad.name is not null then
    raise exception 'Cannot save: this edit would leave "%" at % in stock, because some of it has already been used elsewhere',
      v_bad.name, v_bad.quantity_in_stock
      using errcode = '23514';
  end if;

  return json_build_object('ok', true);
end;
$$ language plpgsql security definer;

grant execute on function fn_delete_purchase_receipt(uuid) to authenticated;
grant execute on function fn_update_purchase_receipt(uuid, uuid, date, jsonb) to authenticated;
