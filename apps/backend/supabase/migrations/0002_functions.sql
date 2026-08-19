-- ============ 1. PURCHASE RECEIPT (weighted-avg cost) ============
create or replace function fn_create_purchase_receipt(
  p_supplier_id uuid, p_purchase_date date, p_items jsonb
) returns jsonb language plpgsql as $$
declare
  v_receipt_id uuid; v_item jsonb; v_rm raw_materials%rowtype;
  v_new_qty numeric; v_new_avg numeric; v_lines jsonb := '[]'::jsonb;
begin
  if p_items is null or jsonb_array_length(p_items) < 1 then
    raise exception 'items required' using errcode = '22000';
  end if;

  insert into purchase_receipts (supplier_id, purchase_date)
  values (p_supplier_id, p_purchase_date) returning id into v_receipt_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_rm from raw_materials where id = (v_item->>'rawMaterialId')::uuid for update;
    if not found then raise exception 'raw material not found' using errcode = 'P0002'; end if;

    v_new_qty := v_rm.quantity_in_stock + (v_item->>'qty')::numeric;
    v_new_avg := ((v_rm.quantity_in_stock * v_rm.avg_unit_cost) + ((v_item->>'qty')::numeric * (v_item->>'cost')::numeric)) / v_new_qty;

    update raw_materials set quantity_in_stock = v_new_qty, avg_unit_cost = v_new_avg where id = v_rm.id;

    insert into purchase_receipt_lines (receipt_id, raw_material_id, qty, cost, avg_cost_after)
    values (v_receipt_id, v_rm.id, (v_item->>'qty')::numeric, (v_item->>'cost')::numeric, v_new_avg);

    v_lines := v_lines || jsonb_build_object(
      'rawMaterialId', v_rm.id, 'qty', v_item->>'qty', 'cost', v_item->>'cost',
      'newAvgUnitCost', v_new_avg, 'newQuantityInStock', v_new_qty
    );
  end loop;

  return jsonb_build_object('receiptId', v_receipt_id, 'supplierId', p_supplier_id,
    'purchaseDate', p_purchase_date, 'lines', v_lines);
end $$;

-- ============ 2. WRAPPER PRODUCTION ============
create or replace function fn_produce_wrapper(p_wrapper_id uuid, p_qty integer)
returns jsonb language plpgsql as $$
declare v_w wrappers%rowtype; v_rm raw_materials%rowtype; v_grams numeric; v_run_id uuid;
begin
  select * into v_w from wrappers where id = p_wrapper_id for update;
  if not found then raise exception 'wrapper not found' using errcode = 'P0002'; end if;
  select * into v_rm from raw_materials where id = v_w.raw_material_id for update;

  v_grams := v_w.grams_per_unit * p_qty;
  if (v_grams / 1000.0) > v_rm.quantity_in_stock then
    raise exception 'insufficient raw material stock' using errcode = '23514';
  end if;

  update raw_materials set quantity_in_stock = quantity_in_stock - (v_grams / 1000.0) where id = v_rm.id;
  update wrappers set stock_qty = stock_qty + p_qty where id = v_w.id;

  insert into wrapper_production_runs (wrapper_id, quantity_produced, grams_consumed)
  values (p_wrapper_id, p_qty, v_grams) returning id into v_run_id;

  return jsonb_build_object('runId', v_run_id, 'wrapperId', p_wrapper_id, 'quantityProduced', p_qty,
    'gramsConsumed', v_grams, 'remainingRawMaterialStock', v_rm.quantity_in_stock - (v_grams/1000.0),
    'newWrapperStockQty', v_w.stock_qty + p_qty);
end $$;

-- ============ 3. BOX PRODUCTION ============
create or replace function fn_produce_box(p_box_id uuid, p_qty integer)
returns jsonb language plpgsql as $$
declare v_b boxes%rowtype; v_rm raw_materials%rowtype; v_grams numeric; v_run_id uuid;
begin
  select * into v_b from boxes where id = p_box_id for update;
  if not found then raise exception 'box not found' using errcode = 'P0002'; end if;
  select * into v_rm from raw_materials where id = v_b.raw_material_id for update;

  v_grams := v_b.grams_per_unit * p_qty;
  if (v_grams / 1000.0) > v_rm.quantity_in_stock then
    raise exception 'insufficient raw material stock' using errcode = '23514';
  end if;

  update raw_materials set quantity_in_stock = quantity_in_stock - (v_grams / 1000.0) where id = v_rm.id;
  update boxes set stock_qty = stock_qty + p_qty where id = v_b.id;

  insert into box_production_runs (box_id, quantity_produced, grams_consumed)
  values (p_box_id, p_qty, v_grams) returning id into v_run_id;

  return jsonb_build_object('runId', v_run_id, 'boxId', p_box_id, 'quantityProduced', p_qty,
    'gramsConsumed', v_grams, 'remainingRawMaterialStock', v_rm.quantity_in_stock - (v_grams/1000.0),
    'newBoxStockQty', v_b.stock_qty + p_qty);
end $$;

-- ============ 4. PRODUCTION BATCH ============
create or replace function fn_create_production_batch(
  p_consumptions jsonb, p_output_yield_kg numeric, p_wastage_kg numeric,
  p_leftover_batch_id uuid default null, p_leftover_kg_used numeric default null
) returns jsonb language plpgsql as $$
declare
  v_item jsonb; v_rm raw_materials%rowtype; v_raw_cost numeric := 0;
  v_source production_batches%rowtype; v_leftover_used numeric := 0; v_leftover_cost numeric := 0;
  v_total_cost numeric; v_total_kg numeric; v_bulk_cost_per_kg numeric; v_batch_id uuid;
begin
  for v_item in select * from jsonb_array_elements(p_consumptions) loop
    select * into v_rm from raw_materials where id = (v_item->>'rawMaterialId')::uuid for update;
    if not found then raise exception 'raw material not found' using errcode = 'P0002'; end if;
    if (v_item->>'qty')::numeric > v_rm.quantity_in_stock then
      raise exception 'insufficient raw material stock' using errcode = '23514';
    end if;
    v_raw_cost := v_raw_cost + ((v_item->>'qty')::numeric * v_rm.avg_unit_cost);
    update raw_materials set quantity_in_stock = quantity_in_stock - (v_item->>'qty')::numeric where id = v_rm.id;
  end loop;

  insert into production_batches (output_yield_kg, wastage_kg, raw_material_cost, status)
  values (p_output_yield_kg, p_wastage_kg, v_raw_cost, 'in_progress') returning id into v_batch_id;

  for v_item in select * from jsonb_array_elements(p_consumptions) loop
    insert into batch_consumptions (batch_id, raw_material_id, qty, unit_cost_at_time)
    select v_batch_id, (v_item->>'rawMaterialId')::uuid, (v_item->>'qty')::numeric, avg_unit_cost
    from raw_materials where id = (v_item->>'rawMaterialId')::uuid;
  end loop;

  if p_leftover_batch_id is not null and p_leftover_kg_used is not null then
    select * into v_source from production_batches where id = p_leftover_batch_id for update;
    if found then
      v_leftover_used := least(p_leftover_kg_used, v_source.leftover_qty_kg);
      v_leftover_cost := v_leftover_used * v_source.bulk_cost_per_kg;
      update production_batches set leftover_qty_kg = leftover_qty_kg - v_leftover_used where id = v_source.id;
    end if;
  end if;

  v_total_cost := v_raw_cost + v_leftover_cost;
  v_total_kg := p_output_yield_kg + v_leftover_used;
  v_bulk_cost_per_kg := case when v_total_kg > 0 then v_total_cost / v_total_kg else 0 end;

  update production_batches set
    leftover_qty_kg = v_total_kg,
    bulk_cost_per_kg = v_bulk_cost_per_kg,
    leftover_source_batch_id = p_leftover_batch_id,
    leftover_kg_consumed = v_leftover_used
  where id = v_batch_id;

  return jsonb_build_object('id', v_batch_id, 'outputYieldKg', p_output_yield_kg, 'wastageKg', p_wastage_kg,
    'leftoverQtyKg', v_total_kg, 'bulkCostPerKg', v_bulk_cost_per_kg, 'status', 'in_progress');
end $$;

-- ============ 5. OVERHEAD ALLOCATION ============
create or replace function fn_allocate_overhead(p_batch_id uuid, p_electricity numeric, p_gas numeric, p_rent numeric)
returns jsonb language plpgsql as $$
declare v_b production_batches%rowtype; v_total numeric; v_per_kg numeric;
begin
  select * into v_b from production_batches where id = p_batch_id for update;
  if not found then raise exception 'batch not found' using errcode = 'P0002'; end if;

  v_total := coalesce(p_electricity,0) + coalesce(p_gas,0) + coalesce(p_rent,0);
  v_per_kg := case when v_b.output_yield_kg > 0 then v_total / v_b.output_yield_kg else 0 end;

  update production_batches set overhead_total = v_total, bulk_cost_per_kg = bulk_cost_per_kg + v_per_kg
  where id = p_batch_id;

  return jsonb_build_object('batchId', p_batch_id, 'overheadTotal', v_total,
    'newBulkCostPerKg', v_b.bulk_cost_per_kg + v_per_kg);
end $$;

-- ============ 6. PACKING RUN PREVIEW (read-only) ============
create or replace function fn_packing_run_preview(p_batch_id uuid, p_config_id uuid, p_cartons_produced integer)
returns jsonb language plpgsql as $$
declare
  v_batch production_batches%rowtype; v_cfg carton_configurations%rowtype;
  v_wrapper wrappers%rowtype; v_box boxes%rowtype;
  v_boxes_produced integer; v_packets_produced integer; v_needed_kg numeric;
  v_bulk_used numeric; v_wrapper_rm raw_materials%rowtype; v_box_rm raw_materials%rowtype;
  v_wrapper_unit_cost numeric; v_box_unit_cost numeric; v_bulk_cost_share numeric;
  v_cost_per_packet numeric; v_cost_per_box numeric; v_cost_per_carton numeric;
  v_nominal_kg_per_packet constant numeric := 0.05;
begin
  select * into v_batch from production_batches where id = p_batch_id;
  select * into v_cfg from carton_configurations where id = p_config_id;
  if not found or v_batch.id is null then raise exception 'batch or config not found' using errcode = 'P0002'; end if;
  select * into v_wrapper from wrappers where id = v_cfg.wrapper_id;
  select * into v_box from boxes where id = v_cfg.box_id;
  select * into v_wrapper_rm from raw_materials where id = v_wrapper.raw_material_id;
  select * into v_box_rm from raw_materials where id = v_box.raw_material_id;

  v_boxes_produced := p_cartons_produced * v_cfg.boxes_per_carton;
  v_packets_produced := v_boxes_produced * v_cfg.packets_per_box;
  v_needed_kg := v_packets_produced * v_nominal_kg_per_packet;
  v_bulk_used := least(v_needed_kg, v_batch.leftover_qty_kg);

  v_bulk_cost_share := v_batch.bulk_cost_per_kg * v_bulk_used;
  v_wrapper_unit_cost := v_wrapper.grams_per_unit * (v_wrapper_rm.avg_unit_cost / 1000.0);
  v_box_unit_cost := v_box.grams_per_unit * (v_box_rm.avg_unit_cost / 1000.0);
  v_cost_per_packet := case when v_packets_produced > 0 then (v_bulk_cost_share / v_packets_produced) + v_wrapper_unit_cost else 0 end;
  v_cost_per_box := (v_cfg.packets_per_box * v_cost_per_packet) + v_box_unit_cost;
  v_cost_per_carton := v_cfg.boxes_per_carton * v_cost_per_box;

  return jsonb_build_object(
    'boxesProduced', v_boxes_produced, 'packetsProduced', v_packets_produced,
    'bulkMaterial', jsonb_build_object('neededKg', v_needed_kg, 'availableKg', v_batch.leftover_qty_kg,
      'remainingAfterKg', v_batch.leftover_qty_kg - v_bulk_used, 'sufficient', v_needed_kg <= v_batch.leftover_qty_kg),
    'boxes', jsonb_build_object('needed', v_boxes_produced, 'available', v_box.stock_qty, 'sufficient', v_boxes_produced <= v_box.stock_qty),
    'wrappers', jsonb_build_object('needed', v_packets_produced, 'available', v_wrapper.stock_qty, 'sufficient', v_packets_produced <= v_wrapper.stock_qty),
    'estimatedCostPerPacket', v_cost_per_packet, 'estimatedCostPerBox', v_cost_per_box, 'estimatedCostPerCarton', v_cost_per_carton,
    'canConfirm', (v_needed_kg <= v_batch.leftover_qty_kg) and (v_boxes_produced <= v_box.stock_qty) and (v_packets_produced <= v_wrapper.stock_qty)
  );
end $$;

-- ============ 7. CONFIRM PACKING RUN ============
create or replace function fn_create_packing_run(p_batch_id uuid, p_config_id uuid, p_cartons_produced integer)
returns jsonb language plpgsql as $$
declare
  v_batch production_batches%rowtype; v_cfg carton_configurations%rowtype;
  v_wrapper wrappers%rowtype; v_box boxes%rowtype;
  v_wrapper_rm raw_materials%rowtype; v_box_rm raw_materials%rowtype;
  v_boxes_produced integer; v_packets_produced integer; v_needed_kg numeric; v_bulk_used numeric;
  v_wrapper_unit_cost numeric; v_box_unit_cost numeric; v_bulk_cost_share numeric;
  v_cost_per_packet numeric; v_cost_per_box numeric; v_cost_per_carton numeric;
  v_finished_id uuid; v_nominal_kg_per_packet constant numeric := 0.05;
begin
  select * into v_batch from production_batches where id = p_batch_id for update;
  select * into v_cfg from carton_configurations where id = p_config_id for update;
  if not found or v_batch.id is null then raise exception 'batch or config not found' using errcode = 'P0002'; end if;
  select * into v_wrapper from wrappers where id = v_cfg.wrapper_id for update;
  select * into v_box from boxes where id = v_cfg.box_id for update;
  select * into v_wrapper_rm from raw_materials where id = v_wrapper.raw_material_id;
  select * into v_box_rm from raw_materials where id = v_box.raw_material_id;

  v_boxes_produced := p_cartons_produced * v_cfg.boxes_per_carton;
  v_packets_produced := v_boxes_produced * v_cfg.packets_per_box;
  v_needed_kg := v_packets_produced * v_nominal_kg_per_packet;

  if v_needed_kg > v_batch.leftover_qty_kg or v_packets_produced > v_wrapper.stock_qty or v_boxes_produced > v_box.stock_qty then
    raise exception 'insufficient bulk material, boxes, or wrappers' using errcode = '23514';
  end if;

  v_bulk_used := v_needed_kg;
  v_bulk_cost_share := v_batch.bulk_cost_per_kg * v_bulk_used;
  v_wrapper_unit_cost := v_wrapper.grams_per_unit * (v_wrapper_rm.avg_unit_cost / 1000.0);
  v_box_unit_cost := v_box.grams_per_unit * (v_box_rm.avg_unit_cost / 1000.0);
  v_cost_per_packet := (v_bulk_cost_share / v_packets_produced) + v_wrapper_unit_cost;
  v_cost_per_box := (v_cfg.packets_per_box * v_cost_per_packet) + v_box_unit_cost;
  v_cost_per_carton := v_cfg.boxes_per_carton * v_cost_per_box;

  update production_batches set
    leftover_qty_kg = leftover_qty_kg - v_bulk_used,
    status = case when leftover_qty_kg - v_bulk_used <= 0 then 'completed' else status end
  where id = v_batch.id;

  update wrappers set stock_qty = stock_qty - v_packets_produced where id = v_wrapper.id;
  update boxes set stock_qty = stock_qty - v_boxes_produced where id = v_box.id;
  update carton_configurations set used_in_packing_run = true where id = v_cfg.id;

  insert into finished_cartons (name, source_batch_id, config_id, cartons_produced, packets_per_carton,
    cost_per_packet, cost_per_box, cost_per_carton, stock_qty)
  values (v_cfg.name, v_batch.id, v_cfg.id, p_cartons_produced, v_cfg.packets_per_box * v_cfg.boxes_per_carton,
    v_cost_per_packet, v_cost_per_box, v_cost_per_carton, p_cartons_produced)
  returning id into v_finished_id;

  return jsonb_build_object('finishedCartonId', v_finished_id, 'name', v_cfg.name,
    'cartonsProduced', p_cartons_produced, 'packetsPerCarton', v_cfg.packets_per_box * v_cfg.boxes_per_carton,
    'costPerPacket', v_cost_per_packet, 'costPerBox', v_cost_per_box, 'costPerCarton', v_cost_per_carton,
    'stockQty', p_cartons_produced);
end $$;

-- ============ 8. INVOICE PRICE LOOKUP (read-only) ============
create or replace function fn_price_lookup(p_customer_id uuid, p_item_id uuid)
returns jsonb language plpgsql as $$
declare v_cip customer_item_prices%rowtype; v_fc finished_cartons%rowtype; v_margin numeric;
begin
  select * into v_cip from customer_item_prices where customer_id = p_customer_id and item_id = p_item_id;
  if found then
    return jsonb_build_object('unitPrice', v_cip.last_sold_price,
      'priceSourceNote', format('Previously sold to this customer on %s at Rs. %s - that price applied.', v_cip.last_sold_date, v_cip.last_sold_price));
  end if;

  select * into v_fc from finished_cartons where id = p_item_id;
  select default_profit_margin_percent into v_margin from app_settings where id = 1;
  return jsonb_build_object('unitPrice', round(v_fc.cost_per_carton * (1 + v_margin/100.0), 2),
    'priceSourceNote', 'First sale to this customer - standard cost-plus-margin price applied.');
end $$;

-- ============ 9. CREATE INVOICE ============
create or replace function fn_create_invoice(p_customer_id uuid, p_lines jsonb)
returns jsonb language plpgsql as $$
declare
  v_line jsonb; v_fc finished_cartons%rowtype; v_subtotal numeric; v_total numeric := 0;
  v_invoice_id uuid; v_invoice_number text; v_next_num integer; v_new_balance numeric;
  v_items jsonb := '[]'::jsonb; v_note text; v_cip customer_item_prices%rowtype;
begin
  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_fc from finished_cartons where id = (v_line->>'finishedCartonId')::uuid for update;
    if not found then raise exception 'finished carton not found' using errcode = 'P0002'; end if;
    if (v_line->>'qty')::integer > v_fc.stock_qty then
      raise exception 'insufficient finished carton stock' using errcode = '23514';
    end if;
  end loop;

  select coalesce(max(substring(invoice_number from 'inv-(\d+)')::integer), 1000) + 1 into v_next_num from invoices;
  v_invoice_number := 'inv-' || v_next_num;

  insert into invoices (invoice_number, customer_id, total_amount) values (v_invoice_number, p_customer_id, 0)
  returning id into v_invoice_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_fc from finished_cartons where id = (v_line->>'finishedCartonId')::uuid for update;
    v_subtotal := (v_line->>'qty')::integer * (v_line->>'unitPrice')::numeric;
    v_total := v_total + v_subtotal;

    select * into v_cip from customer_item_prices where customer_id = p_customer_id and item_id = v_fc.id;
    if found then
      v_note := format('Previously sold to this customer on %s at Rs. %s - that price applied.', v_cip.last_sold_date, v_cip.last_sold_price);
    else
      v_note := 'First sale to this customer - standard cost-plus-margin price applied.';
    end if;

    update finished_cartons set stock_qty = stock_qty - (v_line->>'qty')::integer where id = v_fc.id;

    insert into invoice_items (invoice_id, finished_carton_id, item_name, qty, unit_price, subtotal, price_source_note)
    values (v_invoice_id, v_fc.id, v_fc.name, (v_line->>'qty')::integer, (v_line->>'unitPrice')::numeric, v_subtotal, v_note);

    insert into customer_item_prices (customer_id, item_id, last_sold_price, last_sold_date)
    values (p_customer_id, v_fc.id, (v_line->>'unitPrice')::numeric, current_date)
    on conflict (customer_id, item_id) do update set last_sold_price = excluded.last_sold_price, last_sold_date = excluded.last_sold_date;

    v_items := v_items || jsonb_build_object('itemId', v_fc.id, 'itemName', v_fc.name, 'qty', v_line->>'qty',
      'unitPrice', v_line->>'unitPrice', 'subtotal', v_subtotal, 'priceSourceNote', v_note);
  end loop;

  update invoices set total_amount = v_total where id = v_invoice_id;

  update customers set current_balance = current_balance + v_total where id = p_customer_id returning current_balance into v_new_balance;

  insert into customer_ledger_entries (customer_id, type, direction, amount, running_balance, reference_id)
  values (p_customer_id, 'invoice', null, v_total, v_new_balance, v_invoice_id);

  return jsonb_build_object('id', v_invoice_id, 'invoiceNumber', v_invoice_number, 'totalAmount', v_total,
    'items', v_items, 'newCustomerBalance', v_new_balance);
end $$;

-- ============ 10. RECORD PAYMENT / ADJUSTMENT ============
create or replace function fn_record_payment(p_customer_id uuid, p_amount numeric, p_direction text, p_note text default null)
returns jsonb language plpgsql as $$
declare v_new_balance numeric; v_ledger_id uuid; v_payment_id uuid;
begin
  if p_direction not in ('received','given') then
    raise exception 'direction must be received or given' using errcode = '22000';
  end if;

  update customers set current_balance = current_balance - p_amount where id = p_customer_id returning current_balance into v_new_balance;
  if not found then raise exception 'customer not found' using errcode = 'P0002'; end if;

  insert into customer_ledger_entries (customer_id, type, direction, amount, running_balance, note)
  values (p_customer_id, 'payment', p_direction, p_amount, v_new_balance, coalesce(p_note, ''))
  returning id into v_ledger_id;

  insert into payments (customer_id, amount, direction, note, ledger_entry_id)
  values (p_customer_id, p_amount, p_direction, p_note, v_ledger_id) returning id into v_payment_id;

  return jsonb_build_object('paymentId', v_payment_id, 'ledgerEntryId', v_ledger_id, 'newCustomerBalance', v_new_balance);
end $$;

grant execute on all functions in schema public to authenticated;
