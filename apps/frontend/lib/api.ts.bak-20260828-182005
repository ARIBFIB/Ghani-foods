import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

// ---------- simple table reads ----------
export const getSuppliers = () => supabase.from("suppliers").select("*").order("created_at", { ascending: false });
export const getRawMaterials = () => supabase.from("raw_materials").select("*").order("name");
export const getWrappers = () => supabase.from("wrappers").select("*").order("name");
export const getBoxes = () => supabase.from("boxes").select("*").order("name");
export const getCartonConfigurations = () => supabase.from("carton_configurations").select("*").order("created_at", { ascending: false });
export const getProductionBatches = () => supabase.from("production_batches").select("*").order("batch_date", { ascending: false });
export const getFinishedCartons = () => supabase.from("finished_cartons").select("*").order("created_at", { ascending: false });
export const getCustomers = () => supabase.from("customers").select("*").order("name");
export const getInvoices = () => supabase.from("invoices").select("*").order("invoice_date", { ascending: false });
export const getPayments = () => supabase.from("payments").select("*").order("paid_at", { ascending: false });
export const getAppSettings = () => supabase.from("app_settings").select("*").eq("id", 1).single();

// ---------- RPC (business-logic) calls ----------
export const createPurchaseReceipt = (supplierId: string, purchaseDate: string, items: unknown) =>
  supabase.rpc("fn_create_purchase_receipt", { p_supplier_id: supplierId, p_purchase_date: purchaseDate, p_items: items });

export const produceWrapper = (wrapperId: string, qty: number) =>
  supabase.rpc("fn_produce_wrapper", { p_wrapper_id: wrapperId, p_qty: qty });

export const produceBox = (boxId: string, qty: number) =>
  supabase.rpc("fn_produce_box", { p_box_id: boxId, p_qty: qty });

export const createProductionBatch = (
  consumptions: unknown,
  outputYieldKg: number,
  wastageKg: number,
  leftoverBatchId?: string,
  leftoverKgUsed?: number
) =>
  supabase.rpc("fn_create_production_batch", {
    p_consumptions: consumptions,
    p_output_yield_kg: outputYieldKg,
    p_wastage_kg: wastageKg,
    p_leftover_batch_id: leftoverBatchId ?? null,
    p_leftover_kg_used: leftoverKgUsed ?? null,
  });

export const allocateOverhead = (batchId: string, electricity: number, gas: number, rent: number) =>
  supabase.rpc("fn_allocate_overhead", { p_batch_id: batchId, p_electricity: electricity, p_gas: gas, p_rent: rent });

export const packingRunPreview = (batchId: string, configId: string, cartonsProduced: number) =>
  supabase.rpc("fn_packing_run_preview", { p_batch_id: batchId, p_config_id: configId, p_cartons_produced: cartonsProduced });

export const createPackingRun = (batchId: string, configId: string, cartonsProduced: number) =>
  supabase.rpc("fn_create_packing_run", { p_batch_id: batchId, p_config_id: configId, p_cartons_produced: cartonsProduced });

export const priceLookup = (customerId: string, itemId: string) =>
  supabase.rpc("fn_price_lookup", { p_customer_id: customerId, p_item_id: itemId });

export const createInvoice = (customerId: string, lines: unknown) =>
  supabase.rpc("fn_create_invoice", { p_customer_id: customerId, p_lines: lines });

export const recordPayment = (customerId: string, amount: number, direction: "received" | "given", note?: string) =>
  supabase.rpc("fn_record_payment", { p_customer_id: customerId, p_amount: amount, p_direction: direction, p_note: note ?? null });

// ---------- auth ----------
export const signOut = () => supabase.auth.signOut();
export const getCurrentUser = () => supabase.auth.getUser();
