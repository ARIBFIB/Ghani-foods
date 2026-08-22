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

    const totalLeftoverKg = (data ?? []).reduce((s: number, b: Record<string, unknown>) => s + Number(b.leftover_qty_kg), 0);
    const totalLeftoverValue = (data ?? []).reduce(
      (s: number, b: Record<string, unknown>) => s + Number(b.leftover_qty_kg) * Number(b.bulk_cost_per_kg), 0
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
