// Confirm a packing run - deducts wrappers/boxes/bulk stock, creates finished_cartons
// POST /functions/v1/packing-runs
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    const rpcParams = {
    p_batch_id: body.batchId,
    p_config_id: body.configId,
    p_cartons_produced: body.cartonsProduced,
    };

    const { data, error } = await supabase.rpc("fn_create_packing_run", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    // ISSUE 9: also deduct the physical carton material's own stock, same
    // as Wrapper/Box already are. Kept as a separate RPC (instead of
    // editing the existing fn_create_packing_run, whose current body this
    // codebase export does not include) so the already-working bulk/
    // wrapper/box consumption and finished_cartons creation logic in
    // fn_create_packing_run is never touched or risked.
    const { error: cartonMaterialError } = await supabase.rpc("fn_deduct_carton_material", {
      p_config_id: body.configId,
      p_cartons_produced: body.cartonsProduced,
    });
    if (cartonMaterialError) {
      const status = statusForPgError(cartonMaterialError.message);
      return jsonResponse(envelopeError(
        `Packing run was recorded, but carton material stock could not be deducted: ${cartonMaterialError.message}`,
        cartonMaterialError.code ?? "DB_ERROR"
      ), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
