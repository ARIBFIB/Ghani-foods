-- Adds a free-text `category` column to raw_materials so items can be
-- organized/filtered (e.g. Flour, Oil/Ghee, Spices, Packaging) and so
-- picker dropdowns can show the category alongside the item name.
-- Also added to wrappers/boxes where those tables exist, since the
-- ticket asks for packaging materials to ideally get this too.
-- Nullable - existing rows are unaffected; category is optional.

alter table if exists public.raw_materials
  add column if not exists category text;

do $$
begin
  if to_regclass('public.wrappers') is not null then
    alter table public.wrappers add column if not exists category text;
  end if;
  if to_regclass('public.boxes') is not null then
    alter table public.boxes add column if not exists category text;
  end if;
  if to_regclass('public.packaging_materials') is not null then
    alter table public.packaging_materials add column if not exists category text;
  end if;
end $$;

