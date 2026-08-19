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
