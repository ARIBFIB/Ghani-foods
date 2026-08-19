// GET /functions/v1/customers-item-prices?customerId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const customerId = url.searchParams.get("customerId");
    if (!customerId) return jsonResponse(envelopeError("customerId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("customer_item_prices")
      .select("item_id, last_sold_price, last_sold_date, finished_cartons(name)")
      .eq("customer_id", customerId);

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
