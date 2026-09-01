// POST /functions/v1/raw-materials-create
// Validated creation of a raw material master row (name/unit required, no duplicate name).
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.name || !body.unit) {
      return jsonResponse(envelopeError("name and unit are required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const trimmedName = String(body.name).trim();

    const { data: existing } = await supabase
      .from("raw_materials")
      .select("id, name")
      .ilike("name", trimmedName)
      .maybeSingle();
    if (existing) {
      return jsonResponse(
        envelopeError(`Is naam ka raw material pehle se maujood hai: ${existing.name}`, "CONFLICT"),
        409,
        corsHeaders
      );
    }

    const { data, error } = await supabase
      .from("raw_materials")
      .insert({
        name: trimmedName,
        unit: body.unit,
        quantity_in_stock: body.quantityInStock ?? 0,
        avg_unit_cost: body.avgUnitCost ?? 0,
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
