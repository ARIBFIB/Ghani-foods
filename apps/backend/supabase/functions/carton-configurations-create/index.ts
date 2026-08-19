// POST /functions/v1/carton-configurations-create
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.name || !body.wrapperId || !body.boxId || !body.packetsPerBox || !body.boxesPerCarton) {
      return jsonResponse(envelopeError(
        "name, wrapperId, boxId, packetsPerBox and boxesPerCarton are required", "BAD_REQUEST"
      ), 400, corsHeaders);
    }

    const { data, error } = await supabase
      .from("carton_configurations")
      .insert({
        name: body.name,
        wrapper_id: body.wrapperId,
        packets_per_box: body.packetsPerBox,
        box_id: body.boxId,
        boxes_per_carton: body.boxesPerCarton,
      })
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
