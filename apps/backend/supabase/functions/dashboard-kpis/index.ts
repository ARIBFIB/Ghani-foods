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
