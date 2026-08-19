// POST /functions/v1/customers-create
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.name || !body.phone) {
      return jsonResponse(envelopeError("name and phone are required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase
      .from("customers")
      .insert({ name: body.name, phone: body.phone, current_balance: body.currentBalance ?? 0 })
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
