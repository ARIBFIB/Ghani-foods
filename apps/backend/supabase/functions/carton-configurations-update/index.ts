// PATCH /functions/v1/carton-configurations-update
// Blocked (422) once used_in_packing_run = true, per open question in spec.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const supabase = getClient(req);
    if (!body.id) return jsonResponse(envelopeError("id is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data: existing, error: fetchErr } = await supabase
      .from("carton_configurations")
      .select("id, used_in_packing_run")
      .eq("id", body.id)
      .maybeSingle();

    if (fetchErr) return jsonResponse(envelopeError(fetchErr.message, "DB_ERROR"), 500, corsHeaders);
    if (!existing) return jsonResponse(envelopeError("carton configuration not found", "NOT_FOUND"), 404, corsHeaders);

    if (existing.used_in_packing_run) {
      return jsonResponse(envelopeError(
        "This configuration has already been used in a packing run and can no longer be edited",
        "CONFIG_LOCKED"
      ), 422, corsHeaders);
    }

    const updatePayload: Record<string, unknown> = {};
    if (body.name !== undefined) updatePayload.name = body.name;
    if (body.wrapperId !== undefined) updatePayload.wrapper_id = body.wrapperId;
    if (body.boxId !== undefined) updatePayload.box_id = body.boxId;
    if (body.packetsPerBox !== undefined) updatePayload.packets_per_box = body.packetsPerBox;
    if (body.boxesPerCarton !== undefined) updatePayload.boxes_per_carton = body.boxesPerCarton;

    const { data, error } = await supabase
      .from("carton_configurations")
      .update(updatePayload)
      .eq("id", body.id)
      .select()
      .single();

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
