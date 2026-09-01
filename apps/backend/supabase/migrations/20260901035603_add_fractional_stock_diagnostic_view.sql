-- ISSUE 8: read-only diagnostic view. Flags any Wrapper/Box whose
-- underlying raw material's unit implies whole numbers (piece, dozen,
-- box, packet, bag) but whose CURRENT stock quantity is not a whole
-- number - e.g. Box Paper showing "24.98". This is a strong signal of
-- historical stock corruption from the grams-hardcoded bug and needs a
-- manual correction; this view changes no data, it only reports.
create or replace view v_fractional_stock_flags as
select
  'wrapper'::text as item_type,
  w.id as item_id,
  w.name as item_name,
  w.stock_qty as recorded_stock,
  rm.unit as raw_material_unit,
  rm.name as raw_material_name,
  rm.quantity_in_stock as raw_material_stock
from wrappers w
join raw_materials rm on rm.id = w.raw_material_id
where lower(trim(rm.unit)) in ('piece','dozen','box','packet','bag')
  and w.stock_qty <> floor(w.stock_qty)
union all
select
  'box'::text as item_type,
  b.id as item_id,
  b.name as item_name,
  b.stock_qty as recorded_stock,
  rm.unit as raw_material_unit,
  rm.name as raw_material_name,
  rm.quantity_in_stock as raw_material_stock
from boxes b
join raw_materials rm on rm.id = b.raw_material_id
where lower(trim(rm.unit)) in ('piece','dozen','box','packet','bag')
  and b.stock_qty <> floor(b.stock_qty)
union all
select
  'raw_material'::text as item_type,
  rm.id as item_id,
  rm.name as item_name,
  rm.quantity_in_stock as recorded_stock,
  rm.unit as raw_material_unit,
  rm.name as raw_material_name,
  rm.quantity_in_stock as raw_material_stock
from raw_materials rm
where lower(trim(rm.unit)) in ('piece','dozen','box','packet','bag')
  and rm.quantity_in_stock <> floor(rm.quantity_in_stock);

comment on view v_fractional_stock_flags is
  'ISSUE 8 diagnostic: piece/dozen/box/packet/bag-unit items with a fractional stock quantity. Read-only - query after deploying the Issue 8 unit-mismatch fix, then manually correct anything it lists.';
