// Create a production batch (FR-20/21) with optional leftover carry-forward
// POST /functions/v1/batches
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    const rpcParams = {
    p_consumptions: body.consumptions,
    p_output_yield_kg: body.outputYieldKg,
    p_wastage_kg: body.wastageKg ?? 0,
    p_leftover_batch_id: body.leftoverBatchId ?? null,
    p_leftover_kg_used: body.leftoverKgUsed ?? null,
    };

    const { data, error } = await supabase.rpc("fn_create_production_batch", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
