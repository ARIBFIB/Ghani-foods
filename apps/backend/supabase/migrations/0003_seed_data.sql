-- app_settings
update app_settings set business_name = 'GhaniFoods', address = 'Islamabad, Pakistan',
  invoice_footer_text = 'Thank you for your business!', default_profit_margin_percent = 20,
  low_stock_threshold_default = 50 where id = 1;

-- suppliers
insert into suppliers (name, phone, address)
select 'Al-Madina Traders', '0300-1234567', 'Rawalpindi'
where not exists (select 1 from suppliers where name = 'Al-Madina Traders');

insert into suppliers (name, phone, address)
select 'Ghani Oil Suppliers', '0333-7654321', 'Islamabad'
where not exists (select 1 from suppliers where name = 'Ghani Oil Suppliers');

-- raw materials
insert into raw_materials (name, unit, low_stock_threshold)
select 'Besan (Gram Flour)', 'kg', 50
where not exists (select 1 from raw_materials where name = 'Besan (Gram Flour)');

insert into raw_materials (name, unit, low_stock_threshold)
select 'Cooking Oil', 'kg', 30
where not exists (select 1 from raw_materials where name = 'Cooking Oil');

insert into raw_materials (name, unit, low_stock_threshold)
select 'Wrapper Film Roll', 'kg', 10
where not exists (select 1 from raw_materials where name = 'Wrapper Film Roll');

insert into raw_materials (name, unit, low_stock_threshold)
select 'Carton Board', 'kg', 10
where not exists (select 1 from raw_materials where name = 'Carton Board');

-- seed a small purchase so stock/avg cost is non-zero (idempotent via receipt count check)
do $$
declare v_supplier uuid; v_besan uuid; v_oil uuid;
begin
  if (select count(*) from purchase_receipts) = 0 then
    select id into v_supplier from suppliers where name = 'Al-Madina Traders';
    select id into v_besan from raw_materials where name = 'Besan (Gram Flour)';
    select id into v_oil from raw_materials where name = 'Cooking Oil';

    perform fn_create_purchase_receipt(
      v_supplier, current_date,
      jsonb_build_array(
        jsonb_build_object('rawMaterialId', v_besan, 'qty', 100, 'cost', 180),
        jsonb_build_object('rawMaterialId', v_oil,   'qty', 50,  'cost', 550)
      )
    );
  end if;
end $$;

-- wrappers / boxes definitions (linked to packaging raw materials)
do $$
declare v_wrap_rm uuid; v_box_rm uuid;
begin
  select id into v_wrap_rm from raw_materials where name = 'Wrapper Film Roll';
  select id into v_box_rm from raw_materials where name = 'Carton Board';

  insert into wrappers (name, raw_material_id, grams_per_unit, low_stock_threshold)
  select 'Standard Packet Wrapper', v_wrap_rm, 2, 200
  where not exists (select 1 from wrappers where name = 'Standard Packet Wrapper');

  insert into boxes (name, raw_material_id, grams_per_unit, low_stock_threshold)
  select 'Standard Box', v_box_rm, 50, 20
  where not exists (select 1 from boxes where name = 'Standard Box');
end $$;

-- a demo customer
insert into customers (name, phone)
select 'Walk-in Customer', '0300-0000000'
where not exists (select 1 from customers where name = 'Walk-in Customer');
