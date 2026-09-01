-- Fix: fn_create_purchase_receipt_from_po was missing from the schema,
-- causing "Could not find the function public.fn_create_purchase_receipt_from_po
-- (p_items, p_po_id, p_purchase_date, p_supplier_id) in the schema cache".
--
-- This (re)creates the function so purchase receipts can be recorded
-- against an open Purchase Order:
--   * validates the PO exists and is still open (draft/sent/partially_received)
--   * validates supplier (if provided) matches the PO's supplier
--   * inserts the purchase_receipts + purchase_receipt_lines rows
--   * updates raw_materials.quantity_in_stock and recalculates a
--     weighted-average avg_unit_cost
--   * updates purchase_order_lines.qty_received
--   * auto-transitions the PO status to partially_received / received

create or replace function public.fn_create_purchase_receipt_from_po(
  p_po_id uuid,
  p_purchase_date date,
  p_items jsonb,
  p_supplier_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_po               record;
  v_receipt_id       uuid;
  v_item             jsonb;
  v_raw_material_id  uuid;
  v_qty              numeric;
  v_cost             numeric;
  v_po_line          record;
  v_current_stock    numeric;
  v_current_avg_cost numeric;
  v_new_stock        numeric;
  v_new_avg_cost     numeric;
  v_all_received     boolean;
  v_any_received     boolean;
begin
  if p_po_id is null then
    raise exception 'p_po_id is required' using errcode = '22004';
  end if;

  if p_purchase_date is null then
    raise exception 'p_purchase_date is required' using errcode = '22004';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'p_items must be a non-empty array' using errcode = '22004';
  end if;

  select * into v_po
  from public.purchase_orders
  where id = p_po_id
  for update;

  if not found then
    raise exception 'purchase order not found' using errcode = 'P0002';
  end if;

  if v_po.status not in ('draft', 'sent', 'partially_received') then
    raise exception 'purchase order is % and cannot accept new receipts', v_po.status
      using errcode = '22023';
  end if;

  if p_supplier_id is not null and p_supplier_id <> v_po.supplier_id then
    raise exception 'supplier does not match the purchase order supplier' using errcode = '22023';
  end if;

  insert into public.purchase_receipts (supplier_id, purchase_date, po_id)
  values (coalesce(p_supplier_id, v_po.supplier_id), p_purchase_date, p_po_id)
  returning id into v_receipt_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_raw_material_id := nullif(v_item->>'rawMaterialId', '')::uuid;
    v_qty  := nullif(v_item->>'qty', '')::numeric;
    v_cost := nullif(v_item->>'cost', '')::numeric;

    if v_raw_material_id is null or v_qty is null or v_cost is null then
      raise exception 'each item requires rawMaterialId, qty and cost' using errcode = '22004';
    end if;

    if v_qty <= 0 then
      raise exception 'qty must be greater than 0' using errcode = '22004';
    end if;

    if v_cost <= 0 then
      raise exception 'cost must be greater than 0' using errcode = '22004';
    end if;

    select * into v_po_line
    from public.purchase_order_lines
    where po_id = p_po_id and raw_material_id = v_raw_material_id
    for update;

    if not found then
      raise exception 'raw material % is not on this purchase order', v_raw_material_id
        using errcode = 'P0002';
    end if;

    if v_po_line.qty_received + v_qty > v_po_line.qty_ordered then
      raise exception 'insufficient remaining qty on purchase order line for raw material %', v_raw_material_id
        using errcode = '22023';
    end if;

    select quantity_in_stock, avg_unit_cost into v_current_stock, v_current_avg_cost
    from public.raw_materials
    where id = v_raw_material_id
    for update;

    if not found then
      raise exception 'raw material % not found', v_raw_material_id using errcode = 'P0002';
    end if;

    v_new_stock := v_current_stock + v_qty;

    if v_new_stock > 0 then
      v_new_avg_cost := ((v_current_stock * v_current_avg_cost) + (v_qty * v_cost)) / v_new_stock;
    else
      v_new_avg_cost := v_cost;
    end if;

    insert into public.purchase_receipt_lines
      (receipt_id, raw_material_id, qty, cost, avg_cost_after)
    values
      (v_receipt_id, v_raw_material_id, v_qty, v_cost, v_new_avg_cost);

    update public.raw_materials
    set quantity_in_stock = v_new_stock,
        avg_unit_cost = v_new_avg_cost
    where id = v_raw_material_id;

    update public.purchase_order_lines
    set qty_received = qty_received + v_qty
    where id = v_po_line.id;
  end loop;

  select
    bool_and(qty_received >= qty_ordered),
    bool_or(qty_received > 0)
  into v_all_received, v_any_received
  from public.purchase_order_lines
  where po_id = p_po_id;

  update public.purchase_orders
  set status = case
      when v_all_received then 'received'
      when v_any_received then 'partially_received'
      else status
    end
  where id = p_po_id;

  return jsonb_build_object('id', v_receipt_id, 'poId', p_po_id);
end;
$fn$;

grant execute on function public.fn_create_purchase_receipt_from_po(uuid, date, jsonb, uuid) to authenticated;
