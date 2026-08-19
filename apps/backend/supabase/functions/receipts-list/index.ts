// GET /functions/v1/receipts-list?supplierId=&from=&to=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const supplierId = url.searchParams.get("supplierId");
    const from = url.searchParams.get("from");
    const to = url.searchParams.get("to");

    let query = supabase
      .from("purchase_receipts")
      .select("id, supplier_id, purchase_date, created_at, suppliers(name), purchase_receipt_lines(id, raw_material_id, qty, cost)")
      .order("purchase_date", { ascending: false });

    if (supplierId) query = query.eq("supplier_id", supplierId);
    if (from) query = query.gte("purchase_date", from);
    if (to) query = query.lte("purchase_date", to);

    const { data, error } = await query;
    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
