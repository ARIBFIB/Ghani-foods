// Allocate overhead (electricity/gas/rent) onto a batch's cost/kg
// POST /functions/v1/batches-overhead
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    const rpcParams = {
    p_batch_id: body.batchId,
    p_electricity: body.electricity ?? 0,
    p_gas: body.gas ?? 0,
    p_rent: body.rent ?? 0,
    };

    const { data, error } = await supabase.rpc("fn_allocate_overhead", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
