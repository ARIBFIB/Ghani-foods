-- ISSUE 9: the physical carton itself must be a consumable raw-material
-- item in Carton Configuration, deducted from stock on every packing run.

alter table carton_configurations
  add column if not exists carton_material_id uuid references raw_materials(id),
  add column if not exists carton_qty_per_carton numeric not null default 0;

-- Deliberately kept SEPARATE from fn_create_packing_run (whose current
-- body is not available to patch directly - see script header comment).
-- Skips quietly (no-op) for configurations created before this migration
-- that have no carton_material_id set yet, so old packing runs are not
-- blocked.
create or replace function fn_deduct_carton_material(p_config_id uuid, p_cartons_produced numeric)
returns void
language plpgsql
as $$
declare
  v_config carton_configurations%rowtype;
  v_raw_material raw_materials%rowtype;
  v_qty_needed numeric;
begin
  if p_cartons_produced is null or p_cartons_produced <= 0 then
    raise exception 'Cartons produced must be greater than 0';
  end if;

  select * into v_config from carton_configurations where id = p_config_id for update;
  if not found then
    raise exception 'Carton configuration % not found', p_config_id;
  end if;

  if v_config.carton_material_id is null then
    return;
  end if;

  select * into v_raw_material from raw_materials where id = v_config.carton_material_id for update;
  if not found then
    raise exception 'Carton material for configuration % not found', p_config_id;
  end if;

  -- No hardcoded grams / no silent conversion (Issue 8 convention):
  -- carton_qty_per_carton is defined in the raw material's own unit.
  v_qty_needed := coalesce(v_config.carton_qty_per_carton, 0) * p_cartons_produced;

  if v_qty_needed <= 0 then
    return;
  end if;

  if v_raw_material.quantity_in_stock < v_qty_needed then
    raise exception 'Insufficient stock of % - need % % but only % % available',
      v_raw_material.name, v_qty_needed, v_raw_material.unit, v_raw_material.quantity_in_stock, v_raw_material.unit;
  end if;

  update raw_materials
     set quantity_in_stock = quantity_in_stock - v_qty_needed
   where id = v_raw_material.id;
end;
$$;
