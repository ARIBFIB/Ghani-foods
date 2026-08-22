// GET /functions/v1/reports-finished-carton-availability
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = getClient(req);
    const { data, error } = await supabase
      .from("finished_cartons")
      .select("id,name,stock_qty,cost_per_carton")
      .order("name", { ascending: true });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);

    const result = (data ?? []).map((c: Record<string, unknown>) => ({
      id: c.id,
      name: c.name,
      stockQty: c.stock_qty,
      costPerCarton: Number(c.cost_per_carton),
    }));

    return jsonResponse(envelopeSuccess(result), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
