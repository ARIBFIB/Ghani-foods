<#
  setup-ghanifoods-edge-functions-part2.ps1
  Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
  Creates the remaining 19 Edge Functions under apps\backend\supabase\functions\
  (the other 15 were already created by setup-ghanifoods-edge-functions.ps1).
  Requires _shared/cors.ts and _shared/client.ts to already exist.
#>

$ErrorActionPreference = "Stop"

$Root = Get-Location
$FunctionsDir = Join-Path $Root "apps\backend\supabase\functions"
$sharedDir = Join-Path $FunctionsDir "_shared"

if (-not (Test-Path (Join-Path $sharedDir "client.ts"))) {
    Write-Host "ERROR: _shared/client.ts not found. Run setup-ghanifoods-edge-functions.ps1 first." -ForegroundColor Red
    exit 1
}

function New-FuncDir {
    param([string]$Name)
    $dir = Join-Path $FunctionsDir $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

function Write-Func {
    param([string]$Name, [string]$Content)
    $dir = New-FuncDir $Name
    Set-Content -Path (Join-Path $dir "index.ts") -Value $Content -Encoding UTF8
    Write-Host "Wrote functions/$Name/index.ts" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 1. suppliers-history -> GET /functions/v1/suppliers-history?supplierId=
# ---------------------------------------------------------------------------
Write-Func "suppliers-history" @'
// GET /functions/v1/suppliers-history?supplierId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const supplierId = url.searchParams.get("supplierId");
    if (!supplierId) return jsonResponse(envelopeError("supplierId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("purchase_receipts")
      .select("id, purchase_date, created_at, purchase_receipt_lines(id, raw_material_id, qty, cost, avg_cost_after)")
      .eq("supplier_id", supplierId)
      .order("purchase_date", { ascending: false });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 2. raw-materials-create -> POST /functions/v1/raw-materials-create
# ---------------------------------------------------------------------------
Write-Func "raw-materials-create" @'
// POST /functions/v1/raw-materials-create
// Validated creation of a raw material master row (name/unit required, no duplicate name).
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.name || !body.unit) {
      return jsonResponse(envelopeError("name and unit are required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data: existing } = await supabase.from("raw_materials").select("id").eq("name", body.name).maybeSingle();
    if (existing) {
      return jsonResponse(envelopeError(`raw material "${body.name}" already exists`, "CONFLICT"), 409, corsHeaders);
    }

    const { data, error } = await supabase
      .from("raw_materials")
      .insert({
        name: body.name,
        unit: body.unit,
        quantity_in_stock: body.quantityInStock ?? 0,
        avg_unit_cost: body.avgUnitCost ?? 0,
        low_stock_threshold: body.lowStockThreshold ?? 0,
      })
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 3. raw-materials-history -> GET /functions/v1/raw-materials-history?rawMaterialId=
# ---------------------------------------------------------------------------
Write-Func "raw-materials-history" @'
// GET /functions/v1/raw-materials-history?rawMaterialId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const rawMaterialId = url.searchParams.get("rawMaterialId");
    if (!rawMaterialId) return jsonResponse(envelopeError("rawMaterialId is required", "BAD_REQUEST"), 400, corsHeaders);

    const [receiptLines, consumptions] = await Promise.all([
      supabase.from("purchase_receipt_lines").select("id, qty, cost, avg_cost_after, created_at, receipt_id")
        .eq("raw_material_id", rawMaterialId).order("created_at", { ascending: false }),
      supabase.from("batch_consumptions").select("id, qty, unit_cost_at_time, created_at, batch_id")
        .eq("raw_material_id", rawMaterialId).order("created_at", { ascending: false }),
    ]);

    if (receiptLines.error) return jsonResponse(envelopeError(receiptLines.error.message, "DB_ERROR"), 500, corsHeaders);
    if (consumptions.error) return jsonResponse(envelopeError(consumptions.error.message, "DB_ERROR"), 500, corsHeaders);

    return jsonResponse(envelopeSuccess({
      purchases: receiptLines.data,
      consumptions: consumptions.data,
    }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 4. receipts-list -> GET /functions/v1/receipts-list?supplierId=&from=&to=
# ---------------------------------------------------------------------------
Write-Func "receipts-list" @'
// GET /functions/v1/receipts-list?supplierId=&from=&to=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const supplierId = url.searchParams.get("supplierId");
    const from = url.searchParams.get("from");
    const to = url.searchParams.get("to");

    let query = supabase
      .from("purchase_receipts")
      .select("id, supplier_id, purchase_date, created_at, suppliers(name), purchase_receipt_lines(id, raw_material_id, qty, cost)")
      .order("purchase_date", { ascending: false });

    if (supplierId) query = query.eq("supplier_id", supplierId);
    if (from) query = query.gte("purchase_date", from);
    if (to) query = query.lte("purchase_date", to);

    const { data, error } = await query;
    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 5. receipts-detail -> GET /functions/v1/receipts-detail?id=
# ---------------------------------------------------------------------------
Write-Func "receipts-detail" @'
// GET /functions/v1/receipts-detail?id=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const id = url.searchParams.get("id");
    if (!id) return jsonResponse(envelopeError("id is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("purchase_receipts")
      .select("id, supplier_id, purchase_date, created_at, suppliers(name, phone), purchase_receipt_lines(id, raw_material_id, qty, cost, avg_cost_after, raw_materials(name, unit))")
      .eq("id", id)
      .maybeSingle();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    if (!data) return jsonResponse(envelopeError("receipt not found", "NOT_FOUND"), 404, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 6. wrappers-create -> POST /functions/v1/wrappers-create
# ---------------------------------------------------------------------------
Write-Func "wrappers-create" @'
// POST /functions/v1/wrappers-create
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.name || !body.rawMaterialId || !body.gramsPerUnit) {
      return jsonResponse(envelopeError("name, rawMaterialId and gramsPerUnit are required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase
      .from("wrappers")
      .insert({
        name: body.name,
        raw_material_id: body.rawMaterialId,
        grams_per_unit: body.gramsPerUnit,
        stock_qty: body.stockQty ?? 0,
        low_stock_threshold: body.lowStockThreshold ?? 0,
      })
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 7. wrappers-production-runs -> GET /functions/v1/wrappers-production-runs?wrapperId=
# ---------------------------------------------------------------------------
Write-Func "wrappers-production-runs" @'
// GET /functions/v1/wrappers-production-runs?wrapperId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const wrapperId = url.searchParams.get("wrapperId");
    if (!wrapperId) return jsonResponse(envelopeError("wrapperId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("wrapper_production_runs")
      .select("id, quantity_produced, grams_consumed, run_date, created_at")
      .eq("wrapper_id", wrapperId)
      .order("run_date", { ascending: false });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 8. boxes-create -> POST /functions/v1/boxes-create
# ---------------------------------------------------------------------------
Write-Func "boxes-create" @'
// POST /functions/v1/boxes-create
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.name || !body.rawMaterialId || !body.gramsPerUnit) {
      return jsonResponse(envelopeError("name, rawMaterialId and gramsPerUnit are required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase
      .from("boxes")
      .insert({
        name: body.name,
        raw_material_id: body.rawMaterialId,
        grams_per_unit: body.gramsPerUnit,
        stock_qty: body.stockQty ?? 0,
        low_stock_threshold: body.lowStockThreshold ?? 0,
      })
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 9. boxes-production-runs -> GET /functions/v1/boxes-production-runs?boxId=
# ---------------------------------------------------------------------------
Write-Func "boxes-production-runs" @'
// GET /functions/v1/boxes-production-runs?boxId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const boxId = url.searchParams.get("boxId");
    if (!boxId) return jsonResponse(envelopeError("boxId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("box_production_runs")
      .select("id, quantity_produced, grams_consumed, run_date, created_at")
      .eq("box_id", boxId)
      .order("run_date", { ascending: false });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 10. carton-configurations-create -> POST /functions/v1/carton-configurations-create
# ---------------------------------------------------------------------------
Write-Func "carton-configurations-create" @'
// POST /functions/v1/carton-configurations-create
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.name || !body.wrapperId || !body.boxId || !body.packetsPerBox || !body.boxesPerCarton) {
      return jsonResponse(envelopeError(
        "name, wrapperId, boxId, packetsPerBox and boxesPerCarton are required", "BAD_REQUEST"
      ), 400, corsHeaders);
    }

    const { data, error } = await supabase
      .from("carton_configurations")
      .insert({
        name: body.name,
        wrapper_id: body.wrapperId,
        packets_per_box: body.packetsPerBox,
        box_id: body.boxId,
        boxes_per_carton: body.boxesPerCarton,
      })
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 11. carton-configurations-update -> PATCH /functions/v1/carton-configurations-update
# used_in_packing_run = true hone ke baad name/links read-only (422)
# ---------------------------------------------------------------------------
Write-Func "carton-configurations-update" @'
// PATCH /functions/v1/carton-configurations-update
// Blocked (422) once used_in_packing_run = true, per open question in spec.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);
    if (!body.id) return jsonResponse(envelopeError("id is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data: existing, error: fetchErr } = await supabase
      .from("carton_configurations")
      .select("id, used_in_packing_run")
      .eq("id", body.id)
      .maybeSingle();

    if (fetchErr) return jsonResponse(envelopeError(fetchErr.message, "DB_ERROR"), 500, corsHeaders);
    if (!existing) return jsonResponse(envelopeError("carton configuration not found", "NOT_FOUND"), 404, corsHeaders);

    if (existing.used_in_packing_run) {
      return jsonResponse(envelopeError(
        "This configuration has already been used in a packing run and can no longer be edited",
        "CONFIG_LOCKED"
      ), 422, corsHeaders);
    }

    const updatePayload: Record<string, unknown> = {};
    if (body.name !== undefined) updatePayload.name = body.name;
    if (body.wrapperId !== undefined) updatePayload.wrapper_id = body.wrapperId;
    if (body.boxId !== undefined) updatePayload.box_id = body.boxId;
    if (body.packetsPerBox !== undefined) updatePayload.packets_per_box = body.packetsPerBox;
    if (body.boxesPerCarton !== undefined) updatePayload.boxes_per_carton = body.boxesPerCarton;

    const { data, error } = await supabase
      .from("carton_configurations")
      .update(updatePayload)
      .eq("id", body.id)
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 12. production-batches-leftover-sources -> GET /functions/v1/production-batches-leftover-sources
# ---------------------------------------------------------------------------
Write-Func "production-batches-leftover-sources" @'
// GET /functions/v1/production-batches-leftover-sources
// Batches with unconsumed leftover_qty_kg > 0, selectable when starting a new batch.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const { data, error } = await supabase
      .from("production_batches")
      .select("id, batch_date, leftover_qty_kg, bulk_cost_per_kg, status")
      .gt("leftover_qty_kg", 0)
      .order("batch_date", { ascending: false });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 13. inventory-leftover-summary -> GET /functions/v1/inventory-leftover-summary
# ---------------------------------------------------------------------------
Write-Func "inventory-leftover-summary" @'
// GET /functions/v1/inventory-leftover-summary
// Total unconsumed bulk product (leftover_qty_kg) across all batches, plus per-batch breakdown.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const { data, error } = await supabase
      .from("production_batches")
      .select("id, batch_date, leftover_qty_kg, bulk_cost_per_kg")
      .gt("leftover_qty_kg", 0)
      .order("batch_date", { ascending: false });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);

    const totalLeftoverKg = (data ?? []).reduce((s: number, b: any) => s + Number(b.leftover_qty_kg), 0);
    const totalLeftoverValue = (data ?? []).reduce(
      (s: number, b: any) => s + Number(b.leftover_qty_kg) * Number(b.bulk_cost_per_kg), 0
    );

    return jsonResponse(envelopeSuccess({
      totalLeftoverKg: Math.round(totalLeftoverKg * 1000) / 1000,
      totalLeftoverValue: Math.round(totalLeftoverValue * 100) / 100,
      byBatch: data,
    }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 14. customers-create -> POST /functions/v1/customers-create
# ---------------------------------------------------------------------------
Write-Func "customers-create" @'
// POST /functions/v1/customers-create
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.name || !body.phone) {
      return jsonResponse(envelopeError("name and phone are required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase
      .from("customers")
      .insert({ name: body.name, phone: body.phone, current_balance: body.currentBalance ?? 0 })
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 15. customers-invoices -> GET /functions/v1/customers-invoices?customerId=
# ---------------------------------------------------------------------------
Write-Func "customers-invoices" @'
// GET /functions/v1/customers-invoices?customerId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const customerId = url.searchParams.get("customerId");
    if (!customerId) return jsonResponse(envelopeError("customerId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("invoices")
      .select("id, invoice_number, invoice_date, total_amount, pdf_url")
      .eq("customer_id", customerId)
      .order("invoice_date", { ascending: false });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 16. customers-item-prices -> GET /functions/v1/customers-item-prices?customerId=
# ---------------------------------------------------------------------------
Write-Func "customers-item-prices" @'
// GET /functions/v1/customers-item-prices?customerId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const customerId = url.searchParams.get("customerId");
    if (!customerId) return jsonResponse(envelopeError("customerId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("customer_item_prices")
      .select("item_id, last_sold_price, last_sold_date, finished_cartons(name)")
      .eq("customer_id", customerId);

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 17. invoices-pdf -> GET /functions/v1/invoices-pdf?id=
# Returns structured data for the frontend to render/print; actual PDF byte
# generation + Storage upload is left as a documented TODO (needs a PDF lib
# such as jsPDF or a headless renderer inside the Edge Function runtime).
# ---------------------------------------------------------------------------
Write-Func "invoices-pdf" @'
// GET /functions/v1/invoices-pdf?id=
// Returns invoice + line items + business settings needed to render a PDF.
// TODO: generate actual PDF bytes and upload to the `invoices` Storage bucket,
// then persist the signed URL onto invoices.pdf_url. For now this returns the
// structured payload the frontend can render (or pass to a PDF library) and,
// if pdf_url is already set from a previous generation, includes it directly.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const id = url.searchParams.get("id");
    if (!id) return jsonResponse(envelopeError("id is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data: invoice, error: invErr } = await supabase
      .from("invoices")
      .select("id, invoice_number, invoice_date, total_amount, pdf_url, customers(name, phone), invoice_items(item_name, qty, unit_price, subtotal, price_source_note)")
      .eq("id", id)
      .maybeSingle();

    if (invErr) return jsonResponse(envelopeError(invErr.message, "DB_ERROR"), 500, corsHeaders);
    if (!invoice) return jsonResponse(envelopeError("invoice not found", "NOT_FOUND"), 404, corsHeaders);

    const { data: settings } = await supabase
      .from("app_settings")
      .select("business_name, address, invoice_footer_text")
      .eq("id", 1)
      .maybeSingle();

    return jsonResponse(envelopeSuccess({ invoice, settings, pdfReady: Boolean(invoice.pdf_url) }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 18. invoices-back-context -> GET /functions/v1/invoices-back-context?id=
# ---------------------------------------------------------------------------
Write-Func "invoices-back-context" @'
// GET /functions/v1/invoices-back-context?id=
// Extra context for the invoice print-back (e.g. running customer balance at
// time of this invoice, footer text) so the frontend does not need extra calls.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const id = url.searchParams.get("id");
    if (!id) return jsonResponse(envelopeError("id is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data: invoice, error: invErr } = await supabase
      .from("invoices")
      .select("id, invoice_number, customer_id, invoice_date, total_amount")
      .eq("id", id)
      .maybeSingle();

    if (invErr) return jsonResponse(envelopeError(invErr.message, "DB_ERROR"), 500, corsHeaders);
    if (!invoice) return jsonResponse(envelopeError("invoice not found", "NOT_FOUND"), 404, corsHeaders);

    const { data: ledgerEntry } = await supabase
      .from("customer_ledger_entries")
      .select("running_balance, entry_date")
      .eq("reference_id", invoice.id)
      .eq("type", "invoice")
      .maybeSingle();

    const { data: settings } = await supabase
      .from("app_settings")
      .select("invoice_footer_text, business_name, address")
      .eq("id", 1)
      .maybeSingle();

    return jsonResponse(envelopeSuccess({
      invoiceId: invoice.id,
      invoiceNumber: invoice.invoice_number,
      balanceAfterThisInvoice: ledgerEntry?.running_balance ?? null,
      footerText: settings?.invoice_footer_text ?? null,
      businessName: settings?.business_name ?? null,
      address: settings?.address ?? null,
    }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

# ---------------------------------------------------------------------------
# 19. customers-ledger -> GET /functions/v1/customers-ledger?customerId=
# ---------------------------------------------------------------------------
Write-Func "customers-ledger" @'
// GET /functions/v1/customers-ledger?customerId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const customerId = url.searchParams.get("customerId");
    if (!customerId) return jsonResponse(envelopeError("customerId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("customer_ledger_entries")
      .select("id, type, direction, amount, running_balance, note, reference_id, entry_date, created_at")
      .eq("customer_id", customerId)
      .order("entry_date", { ascending: false })
      .order("created_at", { ascending: false });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

Write-Host ""
Write-Host "==> DONE. All 19 remaining Edge Functions created." -ForegroundColor Green
Write-Host "==> That brings the custom Edge Function count to 15 + 19 = 34 / 34 (100% per spec)." -ForegroundColor Green
Write-Host "==> Deploy all at once:" -ForegroundColor Yellow
Write-Host "    cd apps\backend"
Write-Host "    supabase functions deploy"
Write-Host "==> Known gap flagged in code: invoices-pdf returns structured data only -"
Write-Host "    actual PDF byte generation + Storage upload to the 'invoices' bucket is a TODO"
Write-Host "    marked in that file's comments (needs a PDF-generation library)."