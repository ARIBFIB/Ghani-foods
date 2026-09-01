-- Adds delete support (with dependency safety) for Raw Materials and
-- Carton Configurations. Both fail loudly with a clear message instead
-- of deleting when the row is actually depended on elsewhere, so
-- historical reports/records can never be silently broken.

create or replace function public.fn_delete_raw_material(
  p_raw_material_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_exists   boolean;
  v_in_use   boolean := false;
  v_reason   text := '';
begin
  if p_raw_material_id is null then
    raise exception 'p_raw_material_id is required' using errcode = '22004';
  end if;

  select exists(select 1 from public.raw_materials where id = p_raw_material_id) into v_exists;
  if not v_exists then
    raise exception 'raw material not found' using errcode = 'P0002';
  end if;

  if to_regclass('public.purchase_receipt_lines') is not null
     and exists(select 1 from public.purchase_receipt_lines where raw_material_id = p_raw_material_id) then
    v_in_use := true; v_reason := 'it has purchase receipts recorded against it';
  end if;

  if not v_in_use and to_regclass('public.purchase_order_lines') is not null
     and exists(select 1 from public.purchase_order_lines where raw_material_id = p_raw_material_id) then
    v_in_use := true; v_reason := 'it is used on a purchase order';
  end if;

  if not v_in_use and to_regclass('public.batch_consumptions') is not null
     and exists(select 1 from public.batch_consumptions where raw_material_id = p_raw_material_id) then
    v_in_use := true; v_reason := 'it has been consumed in a production batch';
  end if;

  if not v_in_use and to_regclass('public.wrappers') is not null
     and exists(select 1 from public.wrappers where raw_material_id = p_raw_material_id) then
    v_in_use := true; v_reason := 'it is used to make a wrapper';
  end if;

  if not v_in_use and to_regclass('public.boxes') is not null
     and exists(select 1 from public.boxes where raw_material_id = p_raw_material_id) then
    v_in_use := true; v_reason := 'it is used to make a box';
  end if;

  if v_in_use then
    raise exception 'This raw material cannot be deleted because %. Remove/replace those references first.', v_reason
      using errcode = '23503';
  end if;

  delete from public.raw_materials where id = p_raw_material_id;

  return jsonb_build_object('id', p_raw_material_id, 'deleted', true);
end;
$fn$;

grant execute on function public.fn_delete_raw_material(uuid) to authenticated;


create or replace function public.fn_delete_carton_configuration(
  p_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_config record;
begin
  if p_id is null then
    raise exception 'p_id is required' using errcode = '22004';
  end if;

  select * into v_config from public.carton_configurations where id = p_id;
  if not found then
    raise exception 'carton configuration not found' using errcode = 'P0002';
  end if;

  if v_config.used_in_packing_run then
    raise exception 'This configuration has already been used in a packing run and cannot be deleted (historical records depend on it).'
      using errcode = '23503';
  end if;

  delete from public.carton_configurations where id = p_id;

  return jsonb_build_object('id', p_id, 'deleted', true);
end;
$fn$;

grant execute on function public.fn_delete_carton_configuration(uuid) to authenticated;
