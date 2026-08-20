// Add a single named expense (labour, packaging, misc, etc.) to an
// EXISTING batch. For expenses added at batch-creation time, pass them
// via `otherExpenses` on POST /functions/v1/batches instead.
// POST /functions/v1/batch-expenses
// body: { batchId: string, name: string, amount: number }
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    const { data, error } = await supabase.rpc("fn_add_batch_expense", {
      p_batch_id: body.batchId,
      p_name: body.name,
      p_amount: body.amount ?? 0,
    });

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});