// Delete a purchase receipt - reverses its effect on raw material stock.
// Blocked (400) if any of the receipt's stock has already been consumed.
// POST /functions/v1/receipts-delete   body: { receiptId: string }
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.receiptId) {
      return jsonResponse(envelopeError("receiptId is required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase.rpc("fn_delete_purchase_receipt", {
      p_receipt_id: body.receiptId,
    });

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
