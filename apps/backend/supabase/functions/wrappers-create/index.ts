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
