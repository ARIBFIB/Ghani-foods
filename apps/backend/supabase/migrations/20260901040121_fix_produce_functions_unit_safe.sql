-- ISSUE 8 (part 2/2): rebuild fn_produce_wrapper / fn_produce_box so stock
-- deduction happens in the raw material's OWN unit, with no hardcoded
-- grams and no silent unit conversion - matching the frontend fix.
-- CREATE OR REPLACE fully overwrites whatever body currently exists.

create or replace function fn_produce_wrapper(p_wrapper_id uuid, p_qty numeric)
returns json
language plpgsql
as $$
declare
  v_wrapper wrappers%rowtype;
  v_raw_material raw_materials%rowtype;
  v_qty_needed numeric;
  v_result json;
begin
  if p_qty is null or p_qty <= 0 then
    raise exception 'Quantity to produce must be greater than 0';
  end if;

  select * into v_wrapper from wrappers where id = p_wrapper_id for update;
  if not found then
    raise exception 'Wrapper % not found', p_wrapper_id;
  end if;

  select * into v_raw_material from raw_materials where id = v_wrapper.raw_material_id for update;
  if not found then
    raise exception 'Underlying raw material for wrapper % not found', p_wrapper_id;
  end if;

  -- No hardcoded grams / no silent conversion: grams_per_unit is defined
  -- in the raw material's own unit, so this is a straight multiplication.
  v_qty_needed := v_wrapper.grams_per_unit * p_qty;

  if v_raw_material.quantity_in_stock < v_qty_needed then
    raise exception 'Insufficient stock of % - need % % but only % % available',
      v_raw_material.name, v_qty_needed, v_raw_material.unit, v_raw_material.quantity_in_stock, v_raw_material.unit;
  end if;

  update raw_materials
     set quantity_in_stock = quantity_in_stock - v_qty_needed
   where id = v_raw_material.id;

  update wrappers
     set stock_qty = stock_qty + p_qty
   where id = v_wrapper.id
  returning * into v_wrapper;

  insert into wrapper_production_runs (wrapper_id, quantity_produced, grams_consumed, run_date)
  values (p_wrapper_id, p_qty, v_qty_needed, now());

  select row_to_json(v_wrapper) into v_result;
  return v_result;
end;
$$;

create or replace function fn_produce_box(p_box_id uuid, p_qty numeric)
returns json
language plpgsql
as $$
declare
  v_box boxes%rowtype;
  v_raw_material raw_materials%rowtype;
  v_qty_needed numeric;
  v_result json;
begin
  if p_qty is null or p_qty <= 0 then
    raise exception 'Quantity to produce must be greater than 0';
  end if;

  select * into v_box from boxes where id = p_box_id for update;
  if not found then
    raise exception 'Box % not found', p_box_id;
  end if;

  select * into v_raw_material from raw_materials where id = v_box.raw_material_id for update;
  if not found then
    raise exception 'Underlying raw material for box % not found', p_box_id;
  end if;

  -- No hardcoded grams / no silent conversion: grams_per_unit is defined
  -- in the raw material's own unit, so this is a straight multiplication.
  v_qty_needed := v_box.grams_per_unit * p_qty;

  if v_raw_material.quantity_in_stock < v_qty_needed then
    raise exception 'Insufficient stock of % - need % % but only % % available',
      v_raw_material.name, v_qty_needed, v_raw_material.unit, v_raw_material.quantity_in_stock, v_raw_material.unit;
  end if;

  update raw_materials
     set quantity_in_stock = quantity_in_stock - v_qty_needed
   where id = v_raw_material.id;

  update boxes
     set stock_qty = stock_qty + p_qty
   where id = v_box.id
  returning * into v_box;

  insert into box_production_runs (box_id, quantity_produced, grams_consumed, run_date)
  values (p_box_id, p_qty, v_qty_needed, now());

  select row_to_json(v_box) into v_result;
  return v_result;
end;
$$;
