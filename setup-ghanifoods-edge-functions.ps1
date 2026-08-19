<#
  setup-ghanifoods-edge-functions.ps1
  Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
  Creates apps\backend\supabase\functions\<name>\index.ts for every Edge Function
  that wraps the fn_* RPCs (0002_functions.sql) or does read-only aggregation
  (dashboard-kpis, reports/*). Simple CRUD (suppliers, raw-materials list, etc.)
  is NOT generated here - per spec, that goes straight through PostgREST
  auto-REST from the frontend.
#>

$ErrorActionPreference = "Stop"

$Root = Get-Location
$FunctionsDir = Join-Path $Root "apps\backend\supabase\functions"

if (-not (Test-Path $FunctionsDir)) {
    New-Item -ItemType Directory -Path $FunctionsDir -Force | Out-Null
    Write-Host "Created $FunctionsDir" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Shared CORS + Supabase client helper (_shared/cors.ts, _shared/client.ts)
# ---------------------------------------------------------------------------
$sharedDir = Join-Path $FunctionsDir "_shared"
New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null

$corsTs = @'
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
};
'@
Set-Content -Path (Join-Path $sharedDir "cors.ts") -Value $corsTs -Encoding UTF8

$clientTs = @'
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Creates a Supabase client that forwards the caller's JWT, so RLS
// (authenticated-only policies) applies exactly as if the frontend
// called PostgREST directly. Never use the service role key here.
export function getClient(req: Request) {
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } }
  );
}

// Maps Postgres errcodes raised by fn_* functions to HTTP status codes
// per the response envelope convention in the backend spec.
export function statusForPgError(message: string): number {
  if (message.includes("insufficient")) return 409; // stock/balance conflicts
  if (message.includes("not found")) return 404;
  if (message.includes("required") || message.includes("must be")) return 400;
  return 500;
}

export function jsonResponse(body: unknown, status = 200, extraHeaders: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...extraHeaders },
  });
}

export function envelopeError(message: string, code = "ERROR", details: unknown = null) {
  return { data: null, error: { code, message, details } };
}

export function envelopeSuccess(data: unknown) {
  return { data, error: null };
}
'@
Set-Content -Path (Join-Path $sharedDir "client.ts") -Value $clientTs -Encoding UTF8
Write-Host "Wrote _shared/cors.ts and _shared/client.ts" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Helper to write one Edge Function that calls a single RPC 1:1
#   $Name       -> folder name under functions/ (also the URL path segment)
#   $RpcName    -> the fn_* Postgres function to call
#   $ParamsMap  -> hashtable of jsBodyKey -> rpcParamName (ordered)
#   $Description-> comment header
# ---------------------------------------------------------------------------
function Write-RpcFunction {
    param(
        [string]$Name,
        [string]$RpcName,
        [string[]]$ParamLines,   # raw lines building the `rpcParams` object, e.g. 'p_supplier_id: body.supplierId,'
        [string]$Description
    )
    $dir = Join-Path $FunctionsDir $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    $paramsBlock = ($ParamLines -join "`n    ")

    $content = @"
// $Description
// POST /functions/v1/$Name
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    const rpcParams = {
    $paramsBlock
    };

    const { data, error } = await supabase.rpc("$RpcName", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
"@
    Set-Content -Path (Join-Path $dir "index.ts") -Value $content -Encoding UTF8
    Write-Host "Wrote functions/$Name/index.ts" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 1. purchase-receipts  -> fn_create_purchase_receipt
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "purchase-receipts" -RpcName "fn_create_purchase_receipt" -Description "Record a purchase receipt (FR-11/12) - weighted-avg cost update" -ParamLines @(
    'p_supplier_id: body.supplierId,',
    'p_purchase_date: body.purchaseDate ?? new Date().toISOString().slice(0, 10),',
    'p_items: body.items,'
)

# ---------------------------------------------------------------------------
# 2. wrappers-production -> fn_produce_wrapper
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "wrappers-production" -RpcName "fn_produce_wrapper" -Description "Produce wrapper units from raw material stock" -ParamLines @(
    'p_wrapper_id: body.wrapperId,',
    'p_qty: body.qty,'
)

# ---------------------------------------------------------------------------
# 3. boxes-production -> fn_produce_box
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "boxes-production" -RpcName "fn_produce_box" -Description "Produce box units from raw material stock" -ParamLines @(
    'p_box_id: body.boxId,',
    'p_qty: body.qty,'
)

# ---------------------------------------------------------------------------
# 4. batches -> fn_create_production_batch
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "batches" -RpcName "fn_create_production_batch" -Description "Create a production batch (FR-20/21) with optional leftover carry-forward" -ParamLines @(
    'p_consumptions: body.consumptions,',
    'p_output_yield_kg: body.outputYieldKg,',
    'p_wastage_kg: body.wastageKg ?? 0,',
    'p_leftover_batch_id: body.leftoverBatchId ?? null,',
    'p_leftover_kg_used: body.leftoverKgUsed ?? null,'
)

# ---------------------------------------------------------------------------
# 5. batches-overhead -> fn_allocate_overhead
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "batches-overhead" -RpcName "fn_allocate_overhead" -Description "Allocate overhead (electricity/gas/rent) onto a batch's cost/kg" -ParamLines @(
    'p_batch_id: body.batchId,',
    'p_electricity: body.electricity ?? 0,',
    'p_gas: body.gas ?? 0,',
    'p_rent: body.rent ?? 0,'
)

# ---------------------------------------------------------------------------
# 6. packing-runs-preview -> fn_packing_run_preview (read-only, GET-style via POST body)
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "packing-runs-preview" -RpcName "fn_packing_run_preview" -Description "Preview packing-run feasibility/cost (read-only, safe to call on every keystroke)" -ParamLines @(
    'p_batch_id: body.batchId,',
    'p_config_id: body.configId,',
    'p_cartons_produced: body.cartonsProduced,'
)

# ---------------------------------------------------------------------------
# 7. packing-runs -> fn_create_packing_run
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "packing-runs" -RpcName "fn_create_packing_run" -Description "Confirm a packing run - deducts wrappers/boxes/bulk stock, creates finished_cartons" -ParamLines @(
    'p_batch_id: body.batchId,',
    'p_config_id: body.configId,',
    'p_cartons_produced: body.cartonsProduced,'
)

# ---------------------------------------------------------------------------
# 8. invoices-price-lookup -> fn_price_lookup (read-only)
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "invoices-price-lookup" -RpcName "fn_price_lookup" -Description "Look up unit price + priceSourceNote for a customer/item pair (read-only)" -ParamLines @(
    'p_customer_id: body.customerId,',
    'p_item_id: body.itemId,'
)

# ---------------------------------------------------------------------------
# 9. invoices -> fn_create_invoice
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "invoices" -RpcName "fn_create_invoice" -Description "Create an invoice - deducts finished carton stock, updates customer ledger/balance" -ParamLines @(
    'p_customer_id: body.customerId,',
    'p_lines: body.lines,'
)

# ---------------------------------------------------------------------------
# 10. payments -> fn_record_payment
# ---------------------------------------------------------------------------
Write-RpcFunction -Name "payments" -RpcName "fn_record_payment" -Description "Record a payment/adjustment (FR-42/43) - direction is mandatory" -ParamLines @(
    'p_customer_id: body.customerId,',
    'p_amount: body.amount,',
    'p_direction: body.direction,',
    'p_note: body.note ?? null,'
)

# ---------------------------------------------------------------------------
# 11. dashboard-kpis (GET, read-only aggregation - not a single RPC)
# ---------------------------------------------------------------------------
$dashDir = Join-Path $FunctionsDir "dashboard-kpis"
New-Item -ItemType Directory -Path $dashDir -Force | Out-Null
$dashboardTs = @'
// GET /functions/v1/dashboard-kpis
// Aggregates KPIs + low-stock alerts (FR-8) per backend spec section 2_dashboard.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = getClient(req);

    const [rawMaterials, wrappers, boxes, batches, finishedCartons, customers] = await Promise.all([
      supabase.from("raw_materials").select("id,name,quantity_in_stock,avg_unit_cost,low_stock_threshold"),
      supabase.from("wrappers").select("id,name,stock_qty,low_stock_threshold"),
      supabase.from("boxes").select("id,name,stock_qty,low_stock_threshold"),
      supabase.from("production_batches").select("id,batch_date"),
      supabase.from("finished_cartons").select("stock_qty"),
      supabase.from("customers").select("current_balance"),
    ]);

    for (const r of [rawMaterials, wrappers, boxes, batches, finishedCartons, customers]) {
      if (r.error) return jsonResponse(envelopeError(r.error.message, "DB_ERROR"), 500, corsHeaders);
    }

    const totalRawMaterialValue = (rawMaterials.data ?? []).reduce(
      (sum: number, m: any) => sum + Number(m.quantity_in_stock) * Number(m.avg_unit_cost), 0
    );

    const now = new Date();
    const batchesThisMonth = (batches.data ?? []).filter((b: any) => {
      const d = new Date(b.batch_date);
      return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
    }).length;

    const finishedCartonsReady = (finishedCartons.data ?? []).reduce((s: number, c: any) => s + Number(c.stock_qty), 0);

    const totalReceivables = (customers.data ?? [])
      .filter((c: any) => Number(c.current_balance) > 0)
      .reduce((s: number, c: any) => s + Number(c.current_balance), 0);

    const lowStockAlerts = [
      ...(rawMaterials.data ?? [])
        .filter((m: any) => Number(m.quantity_in_stock) < Number(m.low_stock_threshold))
        .map((m: any) => ({ type: "rawMaterial", id: m.id, name: m.name, quantityInStock: Number(m.quantity_in_stock), threshold: Number(m.low_stock_threshold) })),
      ...(wrappers.data ?? [])
        .filter((w: any) => Number(w.stock_qty) < Number(w.low_stock_threshold))
        .map((w: any) => ({ type: "wrapper", id: w.id, name: w.name, quantityInStock: Number(w.stock_qty), threshold: Number(w.low_stock_threshold) })),
      ...(boxes.data ?? [])
        .filter((b: any) => Number(b.stock_qty) < Number(b.low_stock_threshold))
        .map((b: any) => ({ type: "box", id: b.id, name: b.name, quantityInStock: Number(b.stock_qty), threshold: Number(b.low_stock_threshold) })),
    ];

    return jsonResponse(envelopeSuccess({
      totalRawMaterialValue: Math.round(totalRawMaterialValue * 100) / 100,
      batchesThisMonth,
      finishedCartonsReady,
      totalReceivables: Math.round(totalReceivables * 100) / 100,
      lowStockAlerts,
    }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
Set-Content -Path (Join-Path $dashDir "index.ts") -Value $dashboardTs -Encoding UTF8
Write-Host "Wrote functions/dashboard-kpis/index.ts" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 12. reports-pnl (FR-47) - GET, read-only
# ---------------------------------------------------------------------------
$pnlDir = Join-Path $FunctionsDir "reports-pnl"
New-Item -ItemType Directory -Path $pnlDir -Force | Out-Null
$pnlTs = @'
// GET /functions/v1/reports-pnl?from=&to=
// Real-time P&L: unit cost vs realized selling price at batch/carton level (FR-47).
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const from = url.searchParams.get("from");
    const to = url.searchParams.get("to");

    let batchQuery = supabase.from("production_batches").select("id,batch_date,bulk_cost_per_kg,output_yield_kg");
    if (from) batchQuery = batchQuery.gte("batch_date", from);
    if (to) batchQuery = batchQuery.lte("batch_date", to);
    const { data: batchRows, error: batchErr } = await batchQuery;
    if (batchErr) return jsonResponse(envelopeError(batchErr.message, "DB_ERROR"), 500, corsHeaders);

    const { data: cartons, error: cartonErr } = await supabase
      .from("finished_cartons")
      .select("id,name,cost_per_carton,source_batch_id");
    if (cartonErr) return jsonResponse(envelopeError(cartonErr.message, "DB_ERROR"), 500, corsHeaders);

    const { data: invoiceItems, error: itemErr } = await supabase
      .from("invoice_items")
      .select("finished_carton_id,qty,unit_price");
    if (itemErr) return jsonResponse(envelopeError(itemErr.message, "DB_ERROR"), 500, corsHeaders);

    const byBatch = (batchRows ?? []).map((b: any) => {
      const cartonsForBatch = (cartons ?? []).filter((c: any) => c.source_batch_id === b.id);
      const items = (invoiceItems ?? []).filter((i: any) => cartonsForBatch.some((c: any) => c.id === i.finished_carton_id));
      const totalQty = items.reduce((s: number, i: any) => s + Number(i.qty), 0);
      const avgSellPricePerKgEquivalent = totalQty > 0
        ? items.reduce((s: number, i: any) => s + Number(i.qty) * Number(i.unit_price), 0) / totalQty
        : 0;
      const marginPercent = b.bulk_cost_per_kg > 0
        ? Math.round(((avgSellPricePerKgEquivalent - b.bulk_cost_per_kg) / b.bulk_cost_per_kg) * 10000) / 100
        : 0;
      return {
        batchId: b.id,
        bulkCostPerKg: Number(b.bulk_cost_per_kg),
        avgSellPricePerKgEquivalent: Math.round(avgSellPricePerKgEquivalent * 100) / 100,
        marginPercent,
      };
    });

    const byCarton = (cartons ?? []).map((c: any) => {
      const items = (invoiceItems ?? []).filter((i: any) => i.finished_carton_id === c.id);
      const totalQty = items.reduce((s: number, i: any) => s + Number(i.qty), 0);
      const avgSellingPricePerCarton = totalQty > 0
        ? items.reduce((s: number, i: any) => s + Number(i.qty) * Number(i.unit_price), 0) / totalQty
        : 0;
      const marginPercent = c.cost_per_carton > 0
        ? Math.round(((avgSellingPricePerCarton - c.cost_per_carton) / c.cost_per_carton) * 10000) / 100
        : 0;
      return {
        finishedCartonId: c.id,
        name: c.name,
        costPerCarton: Number(c.cost_per_carton),
        avgSellingPricePerCarton: Math.round(avgSellingPricePerCarton * 100) / 100,
        marginPercent,
      };
    });

    return jsonResponse(envelopeSuccess({ byBatch, byCarton }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
Set-Content -Path (Join-Path $pnlDir "index.ts") -Value $pnlTs -Encoding UTF8
Write-Host "Wrote functions/reports-pnl/index.ts" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 13. reports-production (FR-46) - GET, read-only
# ---------------------------------------------------------------------------
$prodRepDir = Join-Path $FunctionsDir "reports-production"
New-Item -ItemType Directory -Path $prodRepDir -Force | Out-Null
$prodRepTs = @'
// GET /functions/v1/reports-production?from=&to=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const from = url.searchParams.get("from");
    const to = url.searchParams.get("to");

    let query = supabase
      .from("production_batches")
      .select("id,batch_date,output_yield_kg,wastage_kg,bulk_cost_per_kg")
      .order("batch_date", { ascending: false });
    if (from) query = query.gte("batch_date", from);
    if (to) query = query.lte("batch_date", to);

    const { data, error } = await query;
    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);

    const result = (data ?? []).map((b: any) => ({
      batchId: b.id,
      batchDate: b.batch_date,
      outputYieldKg: Number(b.output_yield_kg),
      wastageKg: Number(b.wastage_kg),
      bulkCostPerKg: Number(b.bulk_cost_per_kg),
    }));

    return jsonResponse(envelopeSuccess(result), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
Set-Content -Path (Join-Path $prodRepDir "index.ts") -Value $prodRepTs -Encoding UTF8
Write-Host "Wrote functions/reports-production/index.ts" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 14. reports-finished-carton-availability (FR-46) - GET, read-only
# ---------------------------------------------------------------------------
$fcRepDir = Join-Path $FunctionsDir "reports-finished-carton-availability"
New-Item -ItemType Directory -Path $fcRepDir -Force | Out-Null
$fcRepTs = @'
// GET /functions/v1/reports-finished-carton-availability
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = getClient(req);
    const { data, error } = await supabase
      .from("finished_cartons")
      .select("id,name,stock_qty,cost_per_carton")
      .order("name", { ascending: true });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);

    const result = (data ?? []).map((c: any) => ({
      id: c.id,
      name: c.name,
      stockQty: c.stock_qty,
      costPerCarton: Number(c.cost_per_carton),
    }));

    return jsonResponse(envelopeSuccess(result), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
Set-Content -Path (Join-Path $fcRepDir "index.ts") -Value $fcRepTs -Encoding UTF8
Write-Host "Wrote functions/reports-finished-carton-availability/index.ts" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 15. reports-inventory (FR-46) - GET, read-only
# ---------------------------------------------------------------------------
$invRepDir = Join-Path $FunctionsDir "reports-inventory"
New-Item -ItemType Directory -Path $invRepDir -Force | Out-Null
$invRepTs = @'
// GET /functions/v1/reports-inventory?period=&from=&to=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const from = url.searchParams.get("from");
    const to = url.searchParams.get("to");

    let receiptLineQuery = supabase
      .from("purchase_receipt_lines")
      .select("raw_material_id, qty, created_at, purchase_receipts!inner(supplier_id, purchase_date)");
    if (from) receiptLineQuery = receiptLineQuery.gte("purchase_receipts.purchase_date", from);
    if (to) receiptLineQuery = receiptLineQuery.lte("purchase_receipts.purchase_date", to);
    const { data: receiptLines, error: rlErr } = await receiptLineQuery;
    if (rlErr) return jsonResponse(envelopeError(rlErr.message, "DB_ERROR"), 500, corsHeaders);

    const { data: consumptions, error: cErr } = await supabase
      .from("batch_consumptions")
      .select("raw_material_id, qty");
    if (cErr) return jsonResponse(envelopeError(cErr.message, "DB_ERROR"), 500, corsHeaders);

    const { data: rawMaterials, error: rmErr } = await supabase
      .from("raw_materials")
      .select("id, name, quantity_in_stock");
    if (rmErr) return jsonResponse(envelopeError(rmErr.message, "DB_ERROR"), 500, corsHeaders);

    const { data: wrapperRuns, error: wrErr } = await supabase
      .from("wrapper_production_runs")
      .select("wrapper_id, quantity_produced, run_date");
    if (wrErr) return jsonResponse(envelopeError(wrErr.message, "DB_ERROR"), 500, corsHeaders);

    const { data: boxRuns, error: brErr } = await supabase
      .from("box_production_runs")
      .select("box_id, quantity_produced, run_date");
    if (brErr) return jsonResponse(envelopeError(brErr.message, "DB_ERROR"), 500, corsHeaders);

    const rawMaterialMovement = (rawMaterials ?? []).map((m: any) => {
      const purchasedQty = (receiptLines ?? [])
        .filter((l: any) => l.raw_material_id === m.id)
        .reduce((s: number, l: any) => s + Number(l.qty), 0);
      const consumedQty = (consumptions ?? [])
        .filter((c: any) => c.raw_material_id === m.id)
        .reduce((s: number, c: any) => s + Number(c.qty), 0);
      return {
        rawMaterialId: m.id,
        name: m.name,
        purchasedQty,
        consumedQty,
        endingStock: Number(m.quantity_in_stock),
        bySupplier: [],
      };
    });

    return jsonResponse(envelopeSuccess({
      rawMaterialMovement,
      wrapperProduction: wrapperRuns ?? [],
      boxProduction: boxRuns ?? [],
    }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@
Set-Content -Path (Join-Path $invRepDir "index.ts") -Value $invRepTs -Encoding UTF8
Write-Host "Wrote functions/reports-inventory/index.ts" -ForegroundColor Green

Write-Host ""
Write-Host "==> DONE. Edge Functions created in apps\backend\supabase\functions\" -ForegroundColor Green
Write-Host "==> Functions created:" -ForegroundColor Yellow
Write-Host "    purchase-receipts, wrappers-production, boxes-production, batches, batches-overhead,"
Write-Host "    packing-runs-preview, packing-runs, invoices-price-lookup, invoices, payments,"
Write-Host "    dashboard-kpis, reports-pnl, reports-production, reports-finished-carton-availability, reports-inventory"
Write-Host ""
Write-Host "==> Deploy with:" -ForegroundColor Yellow
Write-Host "    cd apps\backend"
Write-Host "    supabase functions deploy purchase-receipts"
Write-Host "    supabase functions deploy wrappers-production"
Write-Host "    supabase functions deploy boxes-production"
Write-Host "    supabase functions deploy batches"
Write-Host "    supabase functions deploy batches-overhead"
Write-Host "    supabase functions deploy packing-runs-preview"
Write-Host "    supabase functions deploy packing-runs"
Write-Host "    supabase functions deploy invoices-price-lookup"
Write-Host "    supabase functions deploy invoices"
Write-Host "    supabase functions deploy payments"
Write-Host "    supabase functions deploy dashboard-kpis"
Write-Host "    supabase functions deploy reports-pnl"
Write-Host "    supabase functions deploy reports-production"
Write-Host "    supabase functions deploy reports-finished-carton-availability"
Write-Host "    supabase functions deploy reports-inventory"
Write-Host "==> (Or deploy all at once: supabase functions deploy)"
Write-Host "==> Still pending: suppliers/raw-materials/customers/settings simple CRUD - per spec these"
Write-Host "    go straight through PostgREST auto-REST from the frontend (no Edge Function needed),"
Write-Host "    frontend just needs supabase.from('suppliers').select()/insert()/update() etc."