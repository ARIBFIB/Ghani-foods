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

    const byBatch = (batchRows ?? []).map((b: Record<string, unknown>) => {
      const cartonsForBatch = (cartons ?? []).filter((c: Record<string, unknown>) => c.source_batch_id === b.id);
      const items = (invoiceItems ?? []).filter((i: Record<string, unknown>) => cartonsForBatch.some((c: Record<string, unknown>) => c.id === i.finished_carton_id));
      const totalQty = items.reduce((s: number, i: Record<string, unknown>) => s + Number(i.qty), 0);
      const avgSellPricePerKgEquivalent = totalQty > 0
        ? items.reduce((s: number, i: Record<string, unknown>) => s + Number(i.qty) * Number(i.unit_price), 0) / totalQty
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

    const byCarton = (cartons ?? []).map((c: Record<string, unknown>) => {
      const items = (invoiceItems ?? []).filter((i: Record<string, unknown>) => i.finished_carton_id === c.id);
      const totalQty = items.reduce((s: number, i: Record<string, unknown>) => s + Number(i.qty), 0);
      const avgSellingPricePerCarton = totalQty > 0
        ? items.reduce((s: number, i: Record<string, unknown>) => s + Number(i.qty) * Number(i.unit_price), 0) / totalQty
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
