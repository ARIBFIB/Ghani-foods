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
