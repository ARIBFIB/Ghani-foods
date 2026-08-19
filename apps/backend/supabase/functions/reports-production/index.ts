// GET /functions/v1/reports-production?from=&to=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const from = url.searchParams.get("from");
    const to = url.searchParams.get("to");

    let query = supabase
      .from("production_batches")
      .select("id,batch_date,output_yield_kg,wastage_kg,bulk_cost_per_kg")
      .order("batch_date", { ascending: false });
    if (from) query = query.gte("batch_date", from);
    if (to) query = query.lte("batch_date", to);

    const { data, error } = await query;
    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);

    const result = (data ?? []).map((b: any) => ({
      batchId: b.id,
      batchDate: b.batch_date,
      outputYieldKg: Number(b.output_yield_kg),
      wastageKg: Number(b.wastage_kg),
      bulkCostPerKg: Number(b.bulk_cost_per_kg),
    }));

    return jsonResponse(envelopeSuccess(result), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
