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
