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
