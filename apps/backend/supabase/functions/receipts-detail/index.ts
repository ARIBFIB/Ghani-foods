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
