-- Fix: raw materials (and packaging - wrappers/boxes) could be created
-- with the same name in different capitalization ("Atta" vs "atta"),
-- silently splitting stock and cost tracking for the same item.
--
-- Part A: one-time merge of existing case-insensitive duplicates.
-- Part B: case-insensitive UNIQUE indexes so it can't happen again at
--         the database level (defense in depth alongside the app check).

-- =============================================================================
-- PART A1: Merge duplicate raw_materials
-- =============================================================================
do $$
declare
  dup_key      text;
  keep_id      uuid;
  total_qty    numeric;
  weighted_avg numeric;
  dup_count    int;
begin
  for dup_key in
    select lower(trim(name))
    from public.raw_materials
    group by lower(trim(name))
    having count(*) > 1
  loop
    select count(*) into dup_count
    from public.raw_materials where lower(trim(name)) = dup_key;

    -- Different rows sharing a name but different units are probably NOT
    -- the same item - skip and flag for manual review instead of merging.
    if (select count(distinct unit) from public.raw_materials where lower(trim(name)) = dup_key) > 1 then
      raise notice 'SKIPPED raw_materials merge for "%": rows disagree on unit - review manually.', dup_key;
      continue;
    end if;

    select id into keep_id
    from public.raw_materials
    where lower(trim(name)) = dup_key
    order by created_at asc nulls last, id asc
    limit 1;

    select coalesce(sum(quantity_in_stock), 0) into total_qty
    from public.raw_materials where lower(trim(name)) = dup_key;

    select case when total_qty > 0
      then coalesce(sum(quantity_in_stock * avg_unit_cost), 0) / total_qty
      else 0
    end into weighted_avg
    from public.raw_materials where lower(trim(name)) = dup_key;

    begin
      if to_regclass('public.purchase_receipt_lines') is not null then
        update public.purchase_receipt_lines set raw_material_id = keep_id
        where raw_material_id in (
          select id from public.raw_materials where lower(trim(name)) = dup_key and id <> keep_id
        );
      end if;

      if to_regclass('public.purchase_order_lines') is not null then
        update public.purchase_order_lines set raw_material_id = keep_id
        where raw_material_id in (
          select id from public.raw_materials where lower(trim(name)) = dup_key and id <> keep_id
        );
      end if;

      if to_regclass('public.batch_consumptions') is not null then
        update public.batch_consumptions set raw_material_id = keep_id
        where raw_material_id in (
          select id from public.raw_materials where lower(trim(name)) = dup_key and id <> keep_id
        );
      end if;

      if to_regclass('public.wrappers') is not null then
        update public.wrappers set raw_material_id = keep_id
        where raw_material_id in (
          select id from public.raw_materials where lower(trim(name)) = dup_key and id <> keep_id
        );
      end if;

      if to_regclass('public.boxes') is not null then
        update public.boxes set raw_material_id = keep_id
        where raw_material_id in (
          select id from public.raw_materials where lower(trim(name)) = dup_key and id <> keep_id
        );
      end if;

      update public.raw_materials
      set name = trim(name), quantity_in_stock = total_qty, avg_unit_cost = weighted_avg
      where id = keep_id;

      delete from public.raw_materials
      where lower(trim(name)) = dup_key and id <> keep_id;

      raise notice 'Merged % duplicate raw_materials row(s) for "%" into id %', dup_count - 1, dup_key, keep_id;
    exception when foreign_key_violation then
      raise notice 'SKIPPED raw_materials merge for "%": a table references the duplicate row(s) that this script does not know about. Review manually.', dup_key;
    end;
  end loop;
end $$;

-- =============================================================================
-- PART A2: Merge duplicate wrappers
-- =============================================================================
do $$
declare
  dup_key   text;
  keep_id   uuid;
  total_qty numeric;
  dup_count int;
begin
  for dup_key in
    select lower(trim(name))
    from public.wrappers
    group by lower(trim(name))
    having count(*) > 1
  loop
    select count(*) into dup_count from public.wrappers where lower(trim(name)) = dup_key;

    if (select count(distinct raw_material_id) from public.wrappers where lower(trim(name)) = dup_key) > 1
       or (select count(distinct grams_per_unit) from public.wrappers where lower(trim(name)) = dup_key) > 1 then
      raise notice 'SKIPPED wrappers merge for "%": rows disagree on raw material or grams_per_unit - review manually.', dup_key;
      continue;
    end if;

    select id into keep_id
    from public.wrappers where lower(trim(name)) = dup_key
    order by id asc limit 1;

    select coalesce(sum(stock_qty), 0) into total_qty
    from public.wrappers where lower(trim(name)) = dup_key;

    begin
      if to_regclass('public.carton_configurations') is not null then
        update public.carton_configurations set wrapper_id = keep_id
        where wrapper_id in (select id from public.wrappers where lower(trim(name)) = dup_key and id <> keep_id);
      end if;

      if to_regclass('public.wrapper_production_runs') is not null then
        update public.wrapper_production_runs set wrapper_id = keep_id
        where wrapper_id in (select id from public.wrappers where lower(trim(name)) = dup_key and id <> keep_id);
      end if;

      update public.wrappers
      set name = trim(name), stock_qty = total_qty
      where id = keep_id;

      delete from public.wrappers
      where lower(trim(name)) = dup_key and id <> keep_id;

      raise notice 'Merged % duplicate wrappers row(s) for "%" into id %', dup_count - 1, dup_key, keep_id;
    exception when foreign_key_violation then
      raise notice 'SKIPPED wrappers merge for "%": a table references the duplicate row(s) that this script does not know about. Review manually.', dup_key;
    end;
  end loop;
end $$;

-- =============================================================================
-- PART A3: Merge duplicate boxes
-- =============================================================================
do $$
declare
  dup_key   text;
  keep_id   uuid;
  total_qty numeric;
  dup_count int;
begin
  for dup_key in
    select lower(trim(name))
    from public.boxes
    group by lower(trim(name))
    having count(*) > 1
  loop
    select count(*) into dup_count from public.boxes where lower(trim(name)) = dup_key;

    if (select count(distinct raw_material_id) from public.boxes where lower(trim(name)) = dup_key) > 1
       or (select count(distinct grams_per_unit) from public.boxes where lower(trim(name)) = dup_key) > 1 then
      raise notice 'SKIPPED boxes merge for "%": rows disagree on raw material or grams_per_unit - review manually.', dup_key;
      continue;
    end if;

    select id into keep_id
    from public.boxes where lower(trim(name)) = dup_key
    order by id asc limit 1;

    select coalesce(sum(stock_qty), 0) into total_qty
    from public.boxes where lower(trim(name)) = dup_key;

    begin
      if to_regclass('public.carton_configurations') is not null then
        update public.carton_configurations set box_id = keep_id
        where box_id in (select id from public.boxes where lower(trim(name)) = dup_key and id <> keep_id);
      end if;

      if to_regclass('public.box_production_runs') is not null then
        update public.box_production_runs set box_id = keep_id
        where box_id in (select id from public.boxes where lower(trim(name)) = dup_key and id <> keep_id);
      end if;

      update public.boxes
      set name = trim(name), stock_qty = total_qty
      where id = keep_id;

      delete from public.boxes
      where lower(trim(name)) = dup_key and id <> keep_id;

      raise notice 'Merged % duplicate boxes row(s) for "%" into id %', dup_count - 1, dup_key, keep_id;
    exception when foreign_key_violation then
      raise notice 'SKIPPED boxes merge for "%": a table references the duplicate row(s) that this script does not know about. Review manually.', dup_key;
    end;
  end loop;
end $$;

-- =============================================================================
-- PART B: case-insensitive UNIQUE indexes (defense in depth)
-- =============================================================================
do $$
begin
  create unique index if not exists ux_raw_materials_name_ci on public.raw_materials (lower(trim(name)));
exception when unique_violation then
  raise notice 'Could not create unique index on raw_materials(name) - duplicates still remain after merge. Review the NOTICEs above and clean up manually, then re-run this migration.';
end $$;

do $$
begin
  create unique index if not exists ux_wrappers_name_ci on public.wrappers (lower(trim(name)));
exception when unique_violation then
  raise notice 'Could not create unique index on wrappers(name) - duplicates still remain after merge. Review the NOTICEs above and clean up manually, then re-run this migration.';
end $$;

do $$
begin
  create unique index if not exists ux_boxes_name_ci on public.boxes (lower(trim(name)));
exception when unique_violation then
  raise notice 'Could not create unique index on boxes(name) - duplicates still remain after merge. Review the NOTICEs above and clean up manually, then re-run this migration.';
end $$;
