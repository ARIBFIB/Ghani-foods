// Record a supplier payment (paying down what we owe a supplier).
// Reduces supplier.current_balance and moves money OUT of the chosen
// treasury account (Bank or Cash). Wraps fn_record_supplier_payment.
// POST /functions/v1/supplier-payments
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.supplierId) {
      return jsonResponse(envelopeError("supplierId is required", "BAD_REQUEST"), 400, corsHeaders);
    }
    if (!body.method || (body.method !== "bank" && body.method !== "cash")) {
      return jsonResponse(envelopeError("method is required and must be 'bank' or 'cash'", "BAD_REQUEST"), 400, corsHeaders);
    }

    const rpcParams = {
      p_supplier_id: body.supplierId,
      p_amount: body.amount,
      p_method: body.method,
      p_note: body.note ?? null,
    };

    const { data, error } = await supabase.rpc("fn_record_supplier_payment", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
